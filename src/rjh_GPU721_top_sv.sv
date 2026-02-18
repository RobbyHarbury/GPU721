module rjh_GPU721_top_sv 
#(
parameter core_count = 2  
)(
input             Resetn_pin   			 , // Reset
input             Clock_pin     			 , // Clock
input 	  [11:0] thread_block_address_i, //address for thread block to be executed from CPU
input					thread_block_request_i , // thread block execution request from CPU

output reg			GPU_busy_o					  // flag for if GPU threads are too busy for block request

);

//----------------------------------------------------------------------------
//-- Declare internal signals
//----------------------------------------------------------------------------

wire [15:0] thread_block_iw 		[core_count-1:0][7:0];
wire [3:0] branch_depth		[core_count-1:0][7:0];
wire [8:0]  thread_block_idx 		[core_count-1:0][7:0];
wire [2:0]  thread_block_width	[core_count-1:0][7:0];
wire	  		thread_block_status_top 	[core_count-1:0][7:0];
wire [15:0]	thread_pc				[core_count-1:0][7:0];
wire			PM_freeze				[core_count-1:0][7:0];
wire [15:0]	cache_out				[core_count-1:0][7:0];
wire 			cache_done			[core_count-1:0]		  ;
wire 			thread_status    	 	[core_count-1:0][7:0];
wire			thread_block_status_core 	[core_count-1:0][7:0];
wire [15:0]	cache_in				 	[core_count-1:0][7:0];
wire [12:0] cache_address				[core_count-1:0]  ;
wire 		cache_access_req			[core_count-1:0]	;
wire 			cache_wr				[core_count-1:0]		  ;
wire			block_freeze			[core_count-1:0][7:0];
wire			predicate_core			[core_count-1:0][7:0];
wire			predicate_PM			[core_count-1:0][7:0];
wire			PM_hold					[core_count-1:0][7:0];

wire [15:0]	PM_out					[core_count-1:0][7:0];
wire [15:0]	PM_pc						[core_count-1:0][7:0];
wire [3:0] PM_branch_depth			[core_count-1:0][7:0];
wire 			PM_ready					[core_count-1:0][7:0];
wire			PM_block_free			[core_count-1:0][7:0];
wire [11:0]	thread_block_address	[core_count-1:0][7:0];
wire			PM_access_req			[core_count-1:0][7:0];

genvar i, j;


//------------------------------------------------------------------------------------
// Structural section of the code.  The order of the assignments doesn't matter.
//------------------------------------------------------------------------------------


rjh_GPU721_block_scheduler_sv 
#(
	.core_count(core_count)
)
block_scheduler (
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
.predicate_i					(predicate_core),

.thread_block_address_o 	(thread_block_address),
.PM_access_req_o 				(PM_access_req),
.thread_block_iw_o			(thread_block_iw),
.thread_block_idx_o    		(thread_block_idx),
.thread_block_width_o	 	(thread_block_width),
.thread_block_status_o 		(thread_block_status_top),
.thread_pc_o				 	(thread_pc),
.branch_depth_o					(branch_depth),
.PM_freeze_o				 	(PM_freeze),
.block_freeze_PM_o				(PM_hold),		
.predicate_o					(predicate_PM),
.GPU_busy_o						(GPU_busy_o)				
);

rjh_GPU721_program_mem_module_sv 
#(
	.core_count(core_count)
)
PM_module (
.Resetn_pin    				(Resetn_pin),
.Clock_pin	  					(Clock_pin),
.thread_block_address_i 	(thread_block_address),
.PM_access_req_i 				(PM_access_req),
.block_freeze_i 				(PM_hold),
.predicate_i					(predicate_PM),

.PM_out_o						(PM_out),
.PM_pc_o							(PM_pc),
.PM_branch_depth_o				(PM_branch_depth),
.PM_ready_o 					(PM_ready),
.PM_block_free_o 				(PM_block_free)
);

rjh_GPU721_GPU_cache 
#(
	.core_count(core_count)
)
GPU_cache_module(
.Resetn_pin   			 		(Resetn_pin),
.Clock_pin     			 	(Clock_pin),
.WR_i          			 	(cache_wr),
.MEM_address_i 			 	(cache_address),
.cache_access_req_i			(cache_access_req),
.MEM_in_i      			 	(cache_in),

.MEM_out_o     			 	(cache_out),
.Done_o  						(cache_done)
);

generate
	for(j=0; j<core_count; j=j+1) begin : processor_cores
		rjh_GPU721_processor_core_sv GPU_core (
	.Resetn_pin					(Resetn_pin),
	.Clock_pin					(Clock_pin),
	.thread_block_iw_i		(thread_block_iw[j]),
	.thread_block_idx_i		(thread_block_idx[j]),
	.thread_block_width_i	(thread_block_width[j]),
	.thread_block_status_i	(thread_block_status_top[j]),
	.thread_pc_i				(thread_pc[j]),
	.PM_freeze_i				(PM_freeze[j]),
	.cache_out_i				(cache_out[j]),
	.cache_done_i				(cache_done[j]),
	.branch_depth_i				(branch_depth[j]),
	.thread_status_o			(thread_status[j]),
	.thread_block_status_o	(thread_block_status_core[j]),
	.cache_in_o					(cache_in[j]),
	.cache_address_o			(cache_address[j]),
	.cache_access_req_o			(cache_access_req[j]),
	.cache_wr_o					(cache_wr[j]),
	.block_freeze_o			(block_freeze[j]),
	.predicate_o			(predicate_core[j])
	);
	end
endgenerate






endmodule 