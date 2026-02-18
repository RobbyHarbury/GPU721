module rjh_GPU721_block_scheduler_sv 
#(
parameter core_count = 2  
)
(
input             Resetn_pin   			 , // Reset
input             Clock_pin     			 , // Clock
input					thread_block_request_i ,
input		  [11:0] thread_block_address_i ,
input		  [15:0] PM_out_i	[core_count-1:0][7:0] ,
input      	  [15:0] PM_pc_i	[core_count-1:0][7:0] ,
input      	  [3:0] PM_branch_depth_i	[core_count-1:0][7:0] ,
input					PM_ready_i [core_count-1:0][7:0] ,
input					thread_status_i [core_count-1:0][7:0] ,
input					thread_block_status_i [core_count-1:0][7:0] ,
input					PM_block_free_i [core_count-1:0][7:0], // 0->free, 1->busy
input					block_freeze_i [core_count-1:0][7:0],
input					predicate_i [core_count-1:0][7:0],

output reg [11:0] thread_block_address_o [core_count-1:0][7:0] ,
output reg			PM_access_req_o [core_count-1:0][7:0] ,
output reg [15:0]	thread_block_iw_o	[core_count-1:0][7:0] ,
output reg [8:0]  thread_block_idx_o    [core_count-1:0][7:0] , // id buses for up to 8 thread blocks
output reg [2:0]  thread_block_width_o	 [core_count-1:0][7:0] , // thread width buses for up to 8 thread blocks
output reg	  		thread_block_status_o [core_count-1:0][7:0] , // thread operation status bus for up to 8 thread blocks
output reg [15:0]	thread_pc_o				 [core_count-1:0][7:0] , // PC for each thread block
output reg [3:0]		branch_depth_o		[core_count-1:0][7:0],		
output reg			PM_freeze_o				 [core_count-1:0][7:0] ,
output reg		   block_freeze_PM_o [core_count-1:0][7:0],
output reg		   predicate_o [core_count-1:0][7:0],
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

reg  [2:0] state_reg [core_count-1:0][7:0];
reg  [3:0] threads_free[core_count-1:0];
reg	 [3:0] core_index [core_count-1:0][7:0];
reg	 [2:0] block_index [core_count-1:0][7:0];
reg 	   block_waiting	 [core_count-1:0][7:0];
reg 		  block_request;
reg [11:0] block_address;
reg  [2:0] block_width;
reg  [3:0] core;
reg  [2:0] block;

integer i, j, k;

genvar gen_i, gen_j;

//------------------------------------------------------------------------------------
// Structural section of the code.  The order of the assignments doesn't matter.
//------------------------------------------------------------------------------------

generate
	for (gen_j=0; gen_j<core_count; gen_j=gen_j+1) begin : remapping_to_PM_core
		for(gen_i=0; gen_i<8; gen_i=gen_i+1) begin : remapping_to_PM_block
			assign block_freeze_PM_o[gen_j][gen_i] = block_freeze_i[core_index[gen_j][gen_i]][block_index[gen_j][gen_i]] | block_waiting[gen_j][gen_i];
			assign predicate_o[gen_j][gen_i] = predicate_i[core_index[gen_j][gen_i]][block_index[gen_j][gen_i]];
		end

	end
endgenerate

//-----------------------------------------------------------------------------------------------
// - Behavioral section of the code.  Assignments are evaluated in order, i.e. sequentially.
//-----------------------------------------------------------------------------------------------

always@(posedge Clock_pin) begin : block_scheduler
//----------------------------------------------------------------------------
// RESET 
//----------------------------------------------------------------------------
if (Resetn_pin == 0) begin    
	
	
	block_request = 1'd0;
	block_address = 12'd0;
	block_width = 3'd0;
	core = 4'd0;
	block = 3'd0;
	
	

	for (j=0; j<(core_count); j=j+1) begin
		state_reg[j][7:0] = '{3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0};
		threads_free[j] = 4'd8; // reset to all threads free
		core_index[j] = '{4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0};
		block_index[j] = '{3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0};
	end

	for (j=0; j<(core_count); j=j+1) begin
		thread_block_address_o[j] = '{12'd0, 12'd0, 12'd0, 12'd0, 12'd0, 12'd0, 12'd0, 12'd0};
		PM_access_req_o[j] = '{1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0};
		thread_block_iw_o[j] = '{16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0};
		thread_block_idx_o[j] = '{9'd0, 9'd0, 9'd0, 9'd0, 9'd0, 9'd0, 9'd0, 9'd0};
		thread_block_width_o[j] = '{3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0};
		thread_block_status_o[j] = '{1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0};
		thread_pc_o[j] = '{16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0};
		PM_freeze_o[j] = '{1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0};
		branch_depth_o[j] = '{4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0};
		block_waiting[j] = '{1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0};
	end
	GPU_busy_o = 1'b0;
	
end
else begin //normal execution
	block_request = thread_block_request_i; // flag that a thread block execution has been requested
	for (j=0; j<(core_count); j=j+1) begin
		for (i=0; i<8; i=i+1) begin // loop through for each thread block
			case (state_reg[j][i])
			
				WAITING: begin
					if (block_request == 1'b1) begin
						block_address = thread_block_address_i;
						thread_block_address_o[j][i] = block_address;
						PM_access_req_o[j][i] = 1'b1;
						state_reg[j][i] = PROCESSING_0;
						block_request = 1'b0;
					end
					else begin
						state_reg[j][i] = WAITING;
					end
				end //WAITING
				
				PROCESSING_0: begin
					if (PM_ready_i[j][i] == 1'b1) begin
						block_width = PM_out_i[j][i][2:0];
						for (k=0; k<core_count; k=k+1) begin
							if (block_width < threads_free[k]) begin
								threads_free[k] = threads_free[k] - (block_width + 1'b1);
								core_index[j][i] = k;
								if (thread_block_status_o[k][0] == 1'b0) block_index[j][i] = 3'd0;
								else if (thread_block_status_o[k][1] == 1'b0) block_index[j][i] = 3'd1;
								else if (thread_block_status_o[k][2] == 1'b0) block_index[j][i] = 3'd2;
								else if (thread_block_status_o[k][3] == 1'b0) block_index[j][i] = 3'd3;
								else if (thread_block_status_o[k][4] == 1'b0) block_index[j][i] = 3'd4;
								else if (thread_block_status_o[k][5] == 1'b0) block_index[j][i] = 3'd5;
								else if (thread_block_status_o[k][6] == 1'b0) block_index[j][i] = 3'd6;
								else if (thread_block_status_o[k][7] == 1'b0) block_index[j][i] = 3'd7;
								GPU_busy_o = 1'b0;
								block_waiting[j][i] = 1'b0;
								state_reg[j][i] = PROCESSING_1;
								break;
							end
							else begin
								GPU_busy_o = 1'b1;
								block_waiting[j][i] = 1'b1;
							end
						end
						
						
					end
					else begin
						state_reg[j][i] = PROCESSING_0;
					end
				end //PROCESSING_0
				
				PROCESSING_1: begin
					core = core_index[j][i];
					block = block_index[j][i];
					thread_block_iw_o[core][block] = PM_out_i[j][i];
					thread_block_idx_o[core][block] = PM_out_i[j][i][11:3];
					thread_block_width_o[core][block] = PM_out_i[j][i][2:0];
					thread_pc_o[core][block] = PM_pc_i[j][i];
					branch_depth_o[core][block] = PM_branch_depth_i[j][i];
					thread_block_status_o[core][block] = 1'b1;
					state_reg[j][i] = RUNNING_0;
				end //PROCESSING_1
				
				RUNNING_0: begin
					core = core_index[j][i];
					block = block_index[j][i];
					if (block_freeze_i[core][block] == 1'b0) begin // if not done and not frozen
						if (PM_ready_i[j][i] == 1'b1) begin // if PM module is ready to read
							PM_freeze_o[core][block] = 1'b0;
							thread_block_iw_o[core][block] = PM_out_i[j][i];
							thread_pc_o[core][block] = PM_pc_i[j][i];
							branch_depth_o[core][block] = PM_branch_depth_i[j][i];
							thread_block_status_o[core][block] = 1'b1;
							
						end
						else begin
							PM_freeze_o[core][block] = 1'b1;
						end
					end
					state_reg[j][i] = RUNNING_1;
				end //RUNNING_0
				
				RUNNING_1: begin
					core = core_index[j][i];
					block = block_index[j][i];
					if (block_freeze_i[core][block] == 1'b0) begin
						if (thread_block_status_i[core][block] == 1'b1) begin // if not done and not frozen
							if (PM_ready_i[j][i] == 1'b1) begin // if PM module is ready to read
								PM_freeze_o[core][block] = 1'b0;
								thread_block_iw_o[core][block] = PM_out_i[j][i];
								thread_pc_o[core][block] = PM_pc_i[j][i];
								branch_depth_o[core][block] = PM_branch_depth_i[j][i];
								state_reg[j][i] = RUNNING_1;
							end
							else begin
								PM_freeze_o[core][block] = 1'b1;
							end
						end
						else begin // thread block is done. free up lanes and thread block
							thread_block_status_o[core][block] = 1'b0;
							PM_access_req_o[j][i] = 1'b0; // free PM block
							threads_free[core] = threads_free[core] + (thread_block_width_o[core][block] + 1'b1);
							state_reg[j][i] = WAITING;
						end
					end
				end //RUNNING_1
			
			endcase
		end
	end
end //normal execution
end//block_scheduler















endmodule 