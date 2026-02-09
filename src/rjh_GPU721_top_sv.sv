module rjh_GPU721_top_sv (
input             Resetn_pin   			 , // Reset
input             Clock_pin     			 , // Clock
input 	  [11:0] thread_block_address_i, //address for thread block to be executed from CPU
input					thread_block_request_i , // thread block execution request from CPU

output reg			GPU_busy_o					  // flag for if GPU threads are too busy for block request

);

//----------------------------------------------------------------------------
//-- Declare internal signals
//----------------------------------------------------------------------------

wire [15:0] thread_block_iw 		[7:0];
wire [3:0] branch_depth		[7:0];
wire [8:0]  thread_block_idx 		[7:0];
wire [2:0]  thread_block_width	[7:0];
wire	  		thread_block_status_top 	[7:0];
wire [15:0]	thread_pc				[7:0];
wire			PM_freeze				[7:0];
wire [15:0]	cache_out				[7:0];
wire 			cache_done					  ;
wire 			thread_status    	 	[7:0];
wire			thread_block_status_core 	[7:0];
wire [15:0]	cache_in				 	[7:0];
wire [12:0] cache_address				  ;
wire 			cache_wr						  ;
wire			block_freeze			[7:0];
wire			predicate			[7:0];
wire 			block_waiting			[7:0];
wire			PM_hold					[7:0];

wire [15:0]	PM_out					[7:0];
wire [15:0]	PM_pc						[7:0];
wire [3:0] PM_branch_depth			[7:0];
wire 			PM_ready					[7:0];
wire			PM_block_free			[7:0];
wire [11:0]	thread_block_address	[7:0];
wire			PM_access_req			[7:0];

genvar i;


//------------------------------------------------------------------------------------
// Structural section of the code.  The order of the assignments doesn't matter.
//------------------------------------------------------------------------------------

generate 
	for (i=0; i<8; i=i+1) begin : PM_hold_logic
		assign PM_hold[i] = block_freeze[i] | block_waiting[i];
	end
endgenerate

rjh_GPU721_block_scheduler_sv block_scheduler (
.Resetn_pin   			 		(Resetn_pin),
.Clock_pin     			 	(Clock_pin),
.thread_block_request_i 	(thread_block_request_i),
.thread_block_address_i 	(thread_block_address_i),
.PM_out_i						(PM_out),
.PM_pc_i							(PM_pc),
.PM_branch_depth_i			(PM_branch_depth),
.PM_ready_i 					(PM_ready),
.thread_status_i 				(thread_status),
.thread_block_status_i		(thread_block_status_core),
.PM_block_free_i 				(PM_block_free),
.block_freeze_i 				(block_freeze),

.thread_block_address_o 	(thread_block_address),
.PM_access_req_o 				(PM_access_req),
.thread_block_iw_o			(thread_block_iw),
.thread_block_idx_o    		(thread_block_idx),
.thread_block_width_o	 	(thread_block_width),
.thread_block_status_o 		(thread_block_status_top),
.thread_pc_o				 	(thread_pc),
.branch_depth_o					(branch_depth),
.PM_freeze_o				 	(PM_freeze),
.block_waiting_o				(block_waiting),		
.GPU_busy_o						(GPU_busy_o)				
);

rjh_GPU721_program_mem_module_sv PM_module (
.Resetn_pin    				(Resetn_pin),
.Clock_pin	  					(Clock_pin),
.thread_block_address_i 	(thread_block_address),
.PM_access_req_i 				(PM_access_req),
.block_freeze_i 				(PM_hold),
.predicate_i					(predicate),

.PM_out_o						(PM_out),
.PM_pc_o							(PM_pc),
.PM_branch_depth_o				(PM_branch_depth),
.PM_ready_o 					(PM_ready),
.PM_block_free_o 				(PM_block_free)
);

rjh_GPU721_GPU_cache GPU_cache_module(
.Resetn_pin   			 		(Resetn_pin),
.Clock_pin     			 	(Clock_pin),
.WR_i          			 	(cache_wr),
.MEM_address_i 			 	(cache_address),
.MEM_in_i      			 	(cache_in),

.MEM_out_o     			 	(cache_out),
.Done_o  						(cache_done)
);


rjh_GPU721_processor_core_sv GPU_core0 (
.Resetn_pin					(Resetn_pin),
.Clock_pin					(Clock_pin),
.thread_block_iw_i		(thread_block_iw),
.thread_block_idx_i		(thread_block_idx),
.thread_block_width_i	(thread_block_width),
.thread_block_status_i	(thread_block_status_top),
.thread_pc_i				(thread_pc),
.PM_freeze_i				(PM_freeze),
.cache_out_i				(cache_out),
.cache_done_i				(cache_done),
.branch_depth_i				(branch_depth),
.thread_status_o			(thread_status),
.thread_block_status_o	(thread_block_status_core),
.cache_in_o					(cache_in),
.cache_address_o			(cache_address),
.cache_wr_o					(cache_wr),
.block_freeze_o			(block_freeze),
.predicate_o			(predicate)
);





endmodule 