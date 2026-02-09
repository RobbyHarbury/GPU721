module rjh_GPU721_block_scheduler_sv (
input             Resetn_pin   			 , // Reset
input             Clock_pin     			 , // Clock
input					thread_block_request_i ,
input		  [11:0] thread_block_address_i ,
input		  [15:0] PM_out_i	[7:0] ,
input      	  [15:0] PM_pc_i	[7:0] ,
input      	  [3:0] PM_branch_depth_i	[7:0] ,
input					PM_ready_i [7:0] ,
input					thread_status_i [7:0] ,
input					thread_block_status_i [7:0] ,
input					PM_block_free_i [7:0], // 0->free, 1->busy
input					block_freeze_i [7:0],

output reg [11:0] thread_block_address_o [7:0] ,
output reg			PM_access_req_o [7:0] ,
output reg [15:0]	thread_block_iw_o	[7:0] ,
output reg [8:0]  thread_block_idx_o    [7:0] , // id buses for up to 8 thread blocks
output reg [2:0]  thread_block_width_o	 [7:0] , // thread width buses for up to 8 thread blocks
output reg	  		thread_block_status_o [7:0] , // thread operation status bus for up to 8 thread blocks
output reg [15:0]	thread_pc_o				 [7:0] , // PC for each thread block
output reg [3:0]		branch_depth_o		[7:0],		
output reg			PM_freeze_o				 [7:0] ,
output reg 			block_waiting_o		 [7:0] ,
output reg			GPU_busy_o					
		 						
);

//----------------------------------------------------------------------------
//-- Declare state machine parameters
//----------------------------------------------------------------------------
localparam [2:0] WAITING = 3'b000;
localparam [2:0] PROCESSING_0 = 3'b001;
localparam [2:0] PROCESSING_1 = 3'b010;
localparam [2:0] RUNNING_0 = 3'b011;
localparam [2:0] RUNNING_1 = 3'b100;

//----------------------------------------------------------------------------
//-- Declare internal signals
//----------------------------------------------------------------------------

reg  [2:0] state_reg [7:0];
reg  [3:0] threads_free;
reg 		  block_request;
reg [11:0] block_address;
reg  [2:0] PM_index;
reg  [2:0] block_width;
reg  [2:0] PM_block [7:0]; // the PM block assigned to each thread block

integer i, j;



//-----------------------------------------------------------------------------------------------
// - Behavioral section of the code.  Assignments are evaluated in order, i.e. sequentially.
//-----------------------------------------------------------------------------------------------

always@(posedge Clock_pin) begin : block_scheduler
//----------------------------------------------------------------------------
// RESET 
//----------------------------------------------------------------------------
if (Resetn_pin == 0) begin    
	state_reg[7:0] = '{3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0};
	threads_free = 4'd8; // reset to all threads free
	block_request = 1'd0;
	block_address = 12'd0;
	PM_index = 3'd0;
	block_width = 3'd0;
	PM_block[7:0] = '{3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0};
	
	thread_block_address_o = '{12'd0, 12'd0, 12'd0, 12'd0, 12'd0, 12'd0, 12'd0, 12'd0};
	PM_access_req_o = '{1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0};
	thread_block_iw_o = '{16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0};
	thread_block_idx_o = '{9'd0, 9'd0, 9'd0, 9'd0, 9'd0, 9'd0, 9'd0, 9'd0};
	thread_block_width_o = '{3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0};
	thread_block_status_o = '{1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0};
	thread_pc_o = '{16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0};
	PM_freeze_o = '{1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0};
	branch_depth_o = '{4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0};
	block_waiting_o = '{1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0};
	GPU_busy_o = 1'b0;
	
	
end
else begin //normal execution
	block_request = thread_block_request_i; // flag that a thread block execution has been requested

	for (i=0; i<8; i=i+1) begin // loop through for each thread block
		case (state_reg[i])
		
			WAITING: begin
				if (block_request == 1'b1) begin
					block_address = thread_block_address_i;
					for (j=0; j<8; j=j+1) begin //find the first free PM block
						if (PM_block_free_i[j] == 1'b0) begin
							thread_block_address_o[j] = block_address;
							PM_access_req_o[j] = 1'b1;
							PM_block[i] = j[2:0]; // assign the PM block to the thread block
							state_reg[i] = PROCESSING_0;
							block_request = 1'b0;
							break;
						end
					end
				end
				else begin
					state_reg[i] = WAITING;
				end
			end //WAITING
			
			PROCESSING_0: begin
				PM_index = PM_block[i];
				if (PM_ready_i[PM_index] == 1'b1) begin
					block_width = PM_out_i[PM_index][2:0];
					if (block_width < threads_free) begin
						threads_free = threads_free - (block_width + 1'b1);
						GPU_busy_o = 1'b0;
						block_waiting_o[i] = 1'b0;
						state_reg[i] = PROCESSING_1;
					end
					else begin
						GPU_busy_o = 1'b1;
						block_waiting_o[i] = 1'b1;
						
					end
				end
				else begin
					state_reg[i] = PROCESSING_0;
				end
			end //PROCESSING_0
			
			PROCESSING_1: begin
				PM_index = PM_block[i];
				thread_block_iw_o[i] = PM_out_i[PM_index];
				thread_block_idx_o[i] = PM_out_i[PM_index][11:3];
				thread_block_width_o[i] = PM_out_i[PM_index][2:0];
				thread_pc_o[i] = PM_pc_i[PM_index];
				branch_depth_o[i] = PM_branch_depth_i[PM_index];
				thread_block_status_o[i] = 1'b1;
				state_reg[i] = RUNNING_0;
			end //PROCESSING_1
			
			RUNNING_0: begin
				PM_index = PM_block[i];
				if (block_freeze_i[i] == 1'b0) begin // if not done and not frozen
					if (PM_ready_i[PM_index] == 1'b1) begin // if PM module is ready to read
						PM_freeze_o[i] = 1'b0;
						thread_block_iw_o[i] = PM_out_i[PM_index];
						thread_pc_o[i] = PM_pc_i[PM_index];
						branch_depth_o[i] = PM_branch_depth_i[PM_index];
						thread_block_status_o[i] = 1'b1;
						
					end
					else begin
						PM_freeze_o[i] = 1'b1;
					end
				end
				state_reg[i] = RUNNING_1;
			end //RUNNING_0
			
			RUNNING_1: begin
				PM_index = PM_block[i];
				if (block_freeze_i[i] == 1'b0) begin
					if (thread_block_status_i[i] == 1'b1) begin // if not done and not frozen
						if (PM_ready_i[PM_index] == 1'b1) begin // if PM module is ready to read
							PM_freeze_o[i] = 1'b0;
							thread_block_iw_o[i] = PM_out_i[PM_index];
							thread_pc_o[i] = PM_pc_i[PM_index];
							branch_depth_o[i] = PM_branch_depth_i[PM_index];
							state_reg[i] = RUNNING_1;
						end
						else begin
							PM_freeze_o[i] = 1'b1;
						end
					end
					else begin // thread block is done. free up lanes and thread block
						thread_block_status_o[i] = 1'b0;
						PM_access_req_o[PM_index] = 1'b0; // free PM block
						threads_free = threads_free + (thread_block_width_o[i] + 1'b1);
						state_reg[i] = WAITING;
					end
				end
			end //RUNNING_1
		
		endcase
	end
end //normal execution
end//block_scheduler















endmodule 