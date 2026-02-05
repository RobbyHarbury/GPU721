// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on

module rjh_GPU721_processor_core_sv (
input             Resetn_pin    , // Reset
input             Clock_pin     , // Clock

// eight IW buses for a maxumim of 8 thread blocks at once
input 	  [15:0] thread_block_iw_i     [7:0] , // IW buses for up to 8 thread blocks

// eight buses for a maximum of 8 thread block IDs
input 	  [8:0]  thread_block_idx_i    [7:0] , // id buses for up to 8 thread blocks

// eight buses for a maximum of 8 thread block widths
input 	  [2:0]  thread_block_width_i	 [7:0] , // thread width buses for up to 8 thread blocks

// eight buses for a maximum of 8 thread block statuses
input 	  		   thread_block_status_i [7:0] , // thread operation status bus for up to 8 thread blocks

input		  [15:0]	thread_pc_i				 [7:0] , // PC for each thread block

input		  			PM_freeze_i				 [7:0] ,

input		  [15:0]	cache_out_i				 [7:0] ,

input					cache_done_i					 ,

// eight flags for individual thread availability: 0->free, 1->unavailable
output reg			thread_status_o    	 [7:0] , // flag bus for all 8 thread availabilities

// eight flags for individual thread availability: 0->free, 1->unavailable
output reg			thread_block_status_o [7:0] , // flag bus for all 8 thread block statuses

output	  [15:0]	cache_in_o				 [7:0] ,

output	  [12:0] cache_address_o				 ,

output				cache_wr_o						 ,

output				block_freeze_o			 [7:0]

);



//----------------------------------------------------------------------------
//-- Declare internal signals
//----------------------------------------------------------------------------
reg	[15:0] thread_IW 			[7:0] ; // IW buffer registers for up to 8 thread blocks
reg			 lane_status 		[7:0] ; // processing status for each SIMD lane: 0->free, 1->running
reg			 block_allocated 	[7:0] ; //flags that track if a thread block has had its id's allocated to threads

wire	[15:0] lane_IW 			[7:0] ; // IW for each SIMD lane
wire	[8:0]  lane_block_idx 	[7:0] ; // thread block idx for each SIMD lane
wire	[2:0]  lane_thread_idx 	[7:0] ; // thread idx for each SIMD lane
wire 			 lane_done 			[7:0] ; // flag for when SIMD thread lane has reached exit instruction
wire			 lane_freeze 		[7:0] ; // frozen status of each SIMD lane
wire			 lane_freeze_mm	[7:0] ; // forzen status of each lane due to mm access
wire	[15:0] MM_out 				[7:0] ; // memory out from memory module
wire 			 WR 					[7:0] ; // write enable for memory access
wire 			 mem_type 			[7:0] ; // type of memory to access
wire	[15:0] MA 					[7:0] ; // memory address bus
wire	[15:0] MM_in 				[7:0] ; // memory in for memory module
wire			 mem_access			[7:0]	; // bus wire for data memory access flags for all lanes

integer width;

genvar i;

//------------------------------------------------------------------------------------------------------------------------------------------
// Structural section of the code.  The order of the assignments doesn't matter.
//------------------------------------------------------------------------------------------------------------------------------------------

generate 
	for (i=0; i<8; i=i+1) begin : thread_freeze
		assign lane_freeze[i] = (lane_freeze_mm[i] | 
				(((lane_block_idx[i] == thread_block_idx_i[0]) & PM_freeze_i[0]) | ((lane_block_idx[i] == thread_block_idx_i[1]) & PM_freeze_i[1]) |
				 ((lane_block_idx[i] == thread_block_idx_i[2]) & PM_freeze_i[2]) | ((lane_block_idx[i] == thread_block_idx_i[3]) & PM_freeze_i[3]) |
				 ((lane_block_idx[i] == thread_block_idx_i[4]) & PM_freeze_i[4]) | ((lane_block_idx[i] == thread_block_idx_i[5]) & PM_freeze_i[5]) |
				 ((lane_block_idx[i] == thread_block_idx_i[6]) & PM_freeze_i[6]) | ((lane_block_idx[i] == thread_block_idx_i[7]) & PM_freeze_i[7])));
	end
endgenerate

rjh_GPU721_thread_scheduler_sv thread_scheduler (
.Resetn_pin					(Resetn_pin),
.Clock_pin					(Clock_pin),
.thread_block_iw_i     	(thread_block_iw_i),
.thread_block_idx_i    	(thread_block_idx_i),
.thread_block_width_i  	(thread_block_width_i),
.thread_block_status_i 	(thread_block_status_i),
.lane_done_i 			  	(lane_done),
.lane_freeze_i 		  	(lane_freeze_mm),
.PM_freeze_i				(PM_freeze_i),
.thread_status_o       	(thread_status_o),
.thread_block_status_o 	(thread_block_status_o),
.lane_IW_o 				  	(lane_IW),
.lane_block_idx_o 	  	(lane_block_idx),
.lane_thread_idx_o 	  	(lane_thread_idx)
);

rjh_GPU721_core_mem_module_sv mem_module(
.Resetn_pin    			(Resetn_pin),
.Clock_pin     			(Clock_pin), 
.MA_i			 				(MA),
.MM_in_i 					(MM_in),
.WR_i 						(WR),
.mem_type_i					(mem_type), 
.mem_access_i				(mem_access),
.lane_block_idx_i			(lane_block_idx),
.thread_block_idx_i		(thread_block_idx_i),
.cache_out_i				(cache_out_i),
.cache_done_i				(cache_done_i), 
.mm_out_o 					(MM_out), 
.lane_freeze_o				(lane_freeze_mm), 
.cache_in_o					(cache_in_o),
.cache_address_o			(cache_address_o), 
.cache_wr_o					(cache_wr_o),  
.block_freeze_o			(block_freeze_o)
);


rjh_GPU721_SIMD_lane_sv SIMD_lane_0( // Core 0
.Resetn_pin					(Resetn_pin),
.Clock_pin					(Clock_pin),
.IW_i							(lane_IW[0]),
.thread_block_idx_i		(lane_block_idx[0]),
.thread_idx_i				(lane_thread_idx[0]),
.MM_out_i					(MM_out[0]),
.lane_freeze_i				(lane_freeze[0]),
.PC_i							(thread_pc_i[0]),	
.mem_access_o				(mem_access[0]),
.lane_done_o				(lane_done[0]),
.WR_o							(WR[0]),
.mem_type_o					(mem_type[0]),
.MA_o							(MA[0]),
.MM_in_o						(MM_in[0])
);

rjh_GPU721_SIMD_lane_sv SIMD_lane_1( // Core 1
.Resetn_pin					(Resetn_pin),
.Clock_pin					(Clock_pin),
.IW_i							(lane_IW[1]),
.thread_block_idx_i		(lane_block_idx[1]),
.thread_idx_i				(lane_thread_idx[1]),
.MM_out_i					(MM_out[1]),
.lane_freeze_i				(lane_freeze[1]),
.PC_i							(thread_pc_i[1]),	
.mem_access_o				(mem_access[1]),
.lane_done_o				(lane_done[1]),
.WR_o							(WR[1]),
.mem_type_o					(mem_type[1]),
.MA_o							(MA[1]),
.MM_in_o						(MM_in[1])
);

rjh_GPU721_SIMD_lane_sv SIMD_lane_2( // Core 2
.Resetn_pin					(Resetn_pin),
.Clock_pin					(Clock_pin),
.IW_i							(lane_IW[2]),
.thread_block_idx_i		(lane_block_idx[2]),
.thread_idx_i				(lane_thread_idx[2]),
.MM_out_i					(MM_out[2]),
.lane_freeze_i				(lane_freeze[2]),
.PC_i							(thread_pc_i[2]),	
.mem_access_o				(mem_access[2]),
.lane_done_o				(lane_done[2]),
.WR_o							(WR[2]),
.mem_type_o					(mem_type[2]),
.MA_o							(MA[2]),
.MM_in_o						(MM_in[2])
);

rjh_GPU721_SIMD_lane_sv SIMD_lane_3( // Core 3
.Resetn_pin					(Resetn_pin),
.Clock_pin					(Clock_pin),
.IW_i							(lane_IW[3]),
.thread_block_idx_i		(lane_block_idx[3]),
.thread_idx_i				(lane_thread_idx[3]),
.MM_out_i					(MM_out[3]),
.lane_freeze_i				(lane_freeze[3]),
.PC_i							(thread_pc_i[3]),	
.mem_access_o				(mem_access[3]),
.lane_done_o				(lane_done[3]),
.WR_o							(WR[3]),
.mem_type_o					(mem_type[3]),
.MA_o							(MA[3]),
.MM_in_o						(MM_in[3])
);

rjh_GPU721_SIMD_lane_sv SIMD_lane_4( // Core 4
.Resetn_pin					(Resetn_pin),
.Clock_pin					(Clock_pin),
.IW_i							(lane_IW[4]),
.thread_block_idx_i		(lane_block_idx[4]),
.thread_idx_i				(lane_thread_idx[4]),
.MM_out_i					(MM_out[4]),
.lane_freeze_i				(lane_freeze[4]),
.PC_i							(thread_pc_i[4]),	
.mem_access_o				(mem_access[4]),
.lane_done_o				(lane_done[4]),
.WR_o							(WR[4]),
.mem_type_o					(mem_type[4]),
.MA_o							(MA[4]),
.MM_in_o						(MM_in[4])
);

rjh_GPU721_SIMD_lane_sv SIMD_lane_5( // Core 5
.Resetn_pin					(Resetn_pin),
.Clock_pin					(Clock_pin),
.IW_i							(lane_IW[5]),
.thread_block_idx_i		(lane_block_idx[5]),
.thread_idx_i				(lane_thread_idx[5]),
.MM_out_i					(MM_out[5]),
.lane_freeze_i				(lane_freeze[5]),
.PC_i							(thread_pc_i[5]),	
.mem_access_o				(mem_access[5]),
.lane_done_o				(lane_done[5]),
.WR_o							(WR[5]),
.mem_type_o					(mem_type[5]),
.MA_o							(MA[5]),
.MM_in_o						(MM_in[5])
);

rjh_GPU721_SIMD_lane_sv SIMD_lane_6( // Core 6
.Resetn_pin					(Resetn_pin),
.Clock_pin					(Clock_pin),
.IW_i							(lane_IW[6]),
.thread_block_idx_i		(lane_block_idx[6]),
.thread_idx_i				(lane_thread_idx[6]),
.MM_out_i					(MM_out[6]),
.lane_freeze_i				(lane_freeze[6]),
.PC_i							(thread_pc_i[6]),	
.mem_access_o				(mem_access[6]),
.lane_done_o				(lane_done[6]),
.WR_o							(WR[6]),
.mem_type_o					(mem_type[6]),
.MA_o							(MA[6]),
.MM_in_o						(MM_in[6])
);

rjh_GPU721_SIMD_lane_sv SIMD_lane_7( // Core 7
.Resetn_pin					(Resetn_pin),
.Clock_pin					(Clock_pin),
.IW_i							(lane_IW[7]),
.thread_block_idx_i		(lane_block_idx[7]),
.thread_idx_i				(lane_thread_idx[7]),
.MM_out_i					(MM_out[7]),
.lane_freeze_i				(lane_freeze[7]),
.PC_i							(thread_pc_i[7]),	
.mem_access_o				(mem_access[7]),
.lane_done_o				(lane_done[7]),
.WR_o							(WR[7]),
.mem_type_o					(mem_type[7]),
.MA_o							(MA[7]),
.MM_in_o						(MM_in[7])
);




//------------------------------------------------------------------------------------------------------------------------------------------
// - Behavioral section of the code.  Assignments are evaluated in order, i.e. sequentially.
//------------------------------------------------------------------------------------------------------------------------------------------





endmodule 