module rjh_GPU721_thread_scheduler_sv (
input             Resetn_pin    , // Reset
input             Clock_pin     , // Clock
input 	  [15:0] thread_block_iw_i     [7:0] , // IW buses for up to 8 thread blocks
input 	  [15:0] thread_pc_i     [7:0] , // pc for up to 8 thread blocks
input 	  [8:0]  thread_block_idx_i    [7:0] , // id buses for up to 8 thread blocks
input 	  [2:0]  thread_block_width_i  [7:0] , // thread width buses for up to 8 thread blocks
input 	  		   thread_block_status_i [7:0] , // thread operation status bus for up to 8 thread blocks
input 				lane_done_i 			 [7:0] , // flag for when SIMD thread lane has reached exit instruction
input			 	 	lane_freeze_i 			 [7:0] , // frozen status of each SIMD lane
input					PM_freeze_i				 [7:0] , // thread block frozen due to PM
input	  [3:0]	branch_depth_i		[7:0] , // branch depth for each thread block
output reg			thread_status_o       [7:0] , // flag bus for all 8 thread availabilities: 0->free, 1->unavailable
output reg			thread_block_status_o [7:0] , // flag bus for all 8 thread block statuses: 0->free, 1->unavailable
output reg [15:0] lane_IW_o 				 [7:0] , // IW for each SIMD lane
output reg [15:0] lane_pc_o 				 [7:0] , // IW for each SIMD lane
output reg	[8:0] lane_block_idx_o 	 	 [7:0] , // thread block idx for each SIMD lane
output reg	[2:0] lane_thread_idx_o 	 [7:0] ,  // thread idx for each SIMD lane
output reg [3:0] lane_branch_depth_o  [7:0]   // branch depth for each thread

);

//----------------------------------------------------------------------------
//-- Declare state machine parameters
//----------------------------------------------------------------------------
localparam [2:0] WAITING = 3'b000;
localparam [2:0] RUNNING_0 = 3'b001;
localparam [2:0] RUNNING_1 = 3'b010;
localparam [2:0] RUNNING_2 = 3'b011;
localparam [2:0] UNALLOCATING = 3'b100;

//----------------------------------------------------------------------------
//-- Declare internal signals
//----------------------------------------------------------------------------
reg			 lane_status [7:0] ; // processing status for each SIMD lane: 0->free, 1->running
reg  [2:0]   state_reg [7:0];
reg  [1:0]   start_up_cnt [7:0];

integer i, k ;
reg [2:0] width;


//------------------------------------------------------------------------------------------------------------------------------------------
// - Behavioral section of the code.  Assignments are evaluated in order, i.e. sequentially.
//------------------------------------------------------------------------------------------------------------------------------------------

always@(posedge Clock_pin) begin : thread_scheduler
//----------------------------------------------------------------------------
// RESET 
//----------------------------------------------------------------------------
if (Resetn_pin == 0) begin    
   // - The reset is active low and clock synchronous.
   // - Initialize registers.
	lane_IW_o[7:0] = '{16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0};
	lane_pc_o[7:0] = '{16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0};
	lane_status[7:0] = '{1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0};
	state_reg[7:0] = '{3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0};
	start_up_cnt[7:0] = '{2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0};
	thread_status_o[7:0] = '{1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0};
	thread_block_status_o[7:0] = '{1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0};
	lane_block_idx_o[7:0] = '{9'd0, 9'd0, 9'd0, 9'd0, 9'd0, 9'd0, 9'd0, 9'd0};
	lane_thread_idx_o[7:0] = '{3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0};
	lane_branch_depth_o = '{4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0};
	
	 
end
else begin// normal operation

	for (i = 0; i < 8; i = i+1) begin
		
		case (state_reg[i])
			WAITING: begin
				if ((thread_block_status_i[i] == 1) && (thread_block_iw_i[i][15:12] == 4'b0000)) begin 
					width = 0;
					for (k = 0; k < 8; k = k+1) begin
						if ((width <= thread_block_width_i[i]) && (lane_status[k] == 0)) begin // allocate free lanes to new thread block
							lane_block_idx_o[k] = thread_block_idx_i[i];
							lane_thread_idx_o[k] = width;
							lane_status[k] = 1;
							thread_status_o[k] = 1;
							width = width + 1'b1;
						end
					end
					thread_block_status_o[i] = 1;
					start_up_cnt[i] = 2'd2;
					state_reg[i] = RUNNING_0;
				end
				
			end // WAITING
			
			RUNNING_0: begin
				if (PM_freeze_i[i] == 1'b0) begin 
					width = thread_block_width_i[i];
					for (k = 0; k < 8; k = k+1) begin
						if ((lane_block_idx_o[k] == thread_block_idx_i[i]) && (lane_freeze_i[k] == 0)) begin // identify if thread is assigned to thread block
							lane_IW_o[k] = thread_block_iw_i[i];
							lane_pc_o[k] = thread_pc_i[i];
							lane_branch_depth_o[k] = branch_depth_i[i];

						end
					end
					if (start_up_cnt[i] == 2'd0) begin
					state_reg[i] = RUNNING_1;
					end
					else begin
						start_up_cnt[i] -= 2'd1;
						state_reg[i] = RUNNING_0;
					end
				end
			end // RUNNING_0

			
			RUNNING_1: begin
				if (PM_freeze_i[i] == 1'b0) begin 
					width = thread_block_width_i[i];
					for (k = 0; k < 8; k = k+1) begin
						if ((lane_block_idx_o[k] == thread_block_idx_i[i]) && (lane_freeze_i[k] == 0)) begin // identify if thread is assigned to thread block
							if ((lane_status[k] == 1) && (lane_done_i[k] == 1)) begin // if lane is done
								thread_status_o[k] = 0;
								if (width == 0) begin // all lanes are done
									thread_block_status_o[i] = 0;
									state_reg[i] = UNALLOCATING;
									
								end
								else begin
									width = width - 1'b1; // decrement and move on to next lane
								end
								lane_status[k] = 0;
							end
							else begin // lane is not done, give next instruction to lane
								lane_IW_o[k] = thread_block_iw_i[i];
								lane_pc_o[k] = thread_pc_i[i];
								lane_branch_depth_o[k] = branch_depth_i[i];
							end
						end
					end
				end
			end // RUNNING_1
			
			UNALLOCATING: begin// give block scheduler time to read outputs
				state_reg[i] = WAITING;
			end // RUNNING_2
		endcase
	end
end // normal execution
end// thread_scheduler



endmodule 