module rjh_GPU721_core_mem_module_sv(
input             Resetn_pin    , // Reset
input             Clock_pin     , // Clock
input			[15:0] MA_i [7:0] 				, // memory adresses from lanes
input			[15:0] MM_in_i [7:0]				, // memory data input from lanes
input		 			 WR_i [7:0] 				, // write enables from lanes
input 				 mem_type_i [7:0]			, // target memory location for each lane: 0->local, 1->cache
input					 mem_access_i [7:0] 		, // memory access flags from each lane. Will be high for 1 clock cycle when a lane has a memory access
input			[8:0]  lane_block_idx_i [7:0] , // thread block idx assigned to each SIMD lane
input			[8:0]  thread_block_idx_i [7:0] , // thread block idx up to mx of 8
input			[15:0] cache_out_i [7:0]		, // data out from GPU cache
input					 cache_done_i					, // done signal from the GPU cache

output reg	[15:0] mm_out_o [7:0]			, // data memory out 
output reg			 lane_freeze_o [7:0]		, // freeze bits for each lane. Lanes will freeze until all memory access from their thread block are finished
output		[15:0] cache_in_o	[7:0]			, // data memory in for the GPU cache
output reg	[12:0] cache_address_o			, // GPU cache memory address
output reg			 cache_wr_o					, // write enable for the cache
output reg			 block_freeze_o [7:0]	


);

//----------------------------------------------------------------------------
//-- Declare local parameters
//----------------------------------------------------------------------------
localparam local_partition_size = 2**3; // size of the address space assigned to each thread block in local memory == 8 (8 x 128 == 1024)

//----------------------------------------------------------------------------
//-- Declare internal signals
//----------------------------------------------------------------------------

reg  [15:0] mem_line [7:0] ; //regester that stores the memory line that is read from or going to be written to memory
reg 			lane_done [7:0] ; // status bits for if each lane has finished its memory access: 0->done, 1->not done
reg  [5:0]	local_mem_address; // address for the local memory
reg  [12:0] mem_address 	; // memory address for the block of memory
//reg  [12:0] current_address 	; // address of memory currently loaded into mem_line
reg			current_access_type; // target of current memory access
reg  [5:0] local_mem_offset [7:0] ; //memory location offset to split up local memory for each thread block

reg			local_mem_wr	; // write signal for local memory
//wire [15:0] local_mem_in [7:0] ;
wire [15:0] local_mem_out [7:0] ;
wire 			clock_not;
integer i, k;
integer mem_line_index;
genvar j;


//-------------------------------------------------------------------------------------------------
// Structural section of the code.  The order of the assignments doesn't matter.
//-------------------------------------------------------------------------------------------------

not clock_inverter ( clock_not, Clock_pin );

local_ram local_ram (
	 .address       ( local_mem_address  ), // input
    .clock         ( clock_not         ), // input
	 .data          ( {mem_line[7], mem_line[6], mem_line[5], mem_line[4], mem_line[3], mem_line[2], mem_line[1], mem_line[0]}),  // input
    .wren          ( local_mem_wr     ), // input
    .q	          ( {local_mem_out[7], local_mem_out[6], local_mem_out[5], local_mem_out[4], 
							local_mem_out[3], local_mem_out[2], local_mem_out[1], local_mem_out[0]})  // output
);



generate 
	
	for (j=0; j<8; j=j+1) begin : lane_freeze_logic // lane_freeze == 0 if that lane and all lanes with the same lane block idx are done. else lane is frozen
		assign lane_freeze_o[j] = (((lane_block_idx_i[j] == lane_block_idx_i[0]) & lane_done[0]) | ((lane_block_idx_i[j] == lane_block_idx_i[1]) & lane_done[1]) |
											((lane_block_idx_i[j] == lane_block_idx_i[2]) & lane_done[2]) | ((lane_block_idx_i[j] == lane_block_idx_i[3]) & lane_done[3]) |
											((lane_block_idx_i[j] == lane_block_idx_i[4]) & lane_done[4]) | ((lane_block_idx_i[j] == lane_block_idx_i[5]) & lane_done[5]) |
											((lane_block_idx_i[j] == lane_block_idx_i[6]) & lane_done[6]) | ((lane_block_idx_i[j] == lane_block_idx_i[7]) & lane_done[7]));
											
		assign block_freeze_o[j] = (((thread_block_idx_i[j] == lane_block_idx_i[0]) & lane_freeze_o[0]) | ((thread_block_idx_i[j] == lane_block_idx_i[1]) & lane_freeze_o[1]) |
											 ((thread_block_idx_i[j] == lane_block_idx_i[2]) & lane_freeze_o[2]) | ((thread_block_idx_i[j] == lane_block_idx_i[3]) & lane_freeze_o[3]) |
											 ((thread_block_idx_i[j] == lane_block_idx_i[4]) & lane_freeze_o[4]) | ((thread_block_idx_i[j] == lane_block_idx_i[5]) & lane_freeze_o[5]) |
											 ((thread_block_idx_i[j] == lane_block_idx_i[6]) & lane_freeze_o[6]) | ((thread_block_idx_i[j] == lane_block_idx_i[7]) & lane_freeze_o[7]));
	end 

	
endgenerate

assign cache_in_o = mem_line;

	
	
//------------------------------------------------------------------------------------------------------------------------------------------
// - Behavioral section of the code.  Assignments are evaluated in order, i.e. sequentially.
//------------------------------------------------------------------------------------------------------------------------------------------

always@(posedge Clock_pin) begin : memory_controller

if (Resetn_pin == 0) begin    
   // - The reset is active low and clock synchronous.
   // - Initialize registers.
	mem_line[7:0] = '{16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0};
	lane_done[7:0] = '{1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0};
	local_mem_address = 6'd0;
	mem_address = 13'd0;
	//current_address = 13'd0;
	current_access_type = 1'd0;
	local_mem_offset[7:0] = '{6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0};
	mm_out_o[7:0] = '{16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0};
	cache_address_o = 13'd0;
	cache_wr_o = 1'd0;
	
end
else begin //normal execution
for (i=0; i<8; i=i+1) begin
	lane_done[i] |= mem_access_i[i];
	for (k=0; k<8; k=k+1) begin
		if (lane_block_idx_i[i] == thread_block_idx_i[k]) begin
			local_mem_offset[i] = local_partition_size[5:0] * k[5:0];
		end
	end
end
if(cache_done_i) begin
// MC 1
	local_mem_wr = 1'b0; // clear write enables
	cache_wr_o = 1'b0;
	if (current_access_type == 1'b1) begin
		mem_line[7:0] = cache_out_i[7:0];
	end
	else begin
		mem_line[7:0] = local_mem_out[7:0];
	end
	//current_address = mem_address;
	for (i=0; i<8; i=i+1) begin
		mem_line_index = MA_i[i][2:0];
		if ((lane_done[i] == 1'b1) && (MA_i[i][15:3] == mem_address) && (mem_type_i[i] == current_access_type)) begin
			if (WR_i[i] == 1'b1) begin // Write state
				mem_line[mem_line_index] = MM_in_i[i];
				if (current_access_type == 1'b1) begin
					cache_wr_o = 1'b1;
				end
				else begin
					local_mem_wr = 1'b1;
				end
				lane_done[i] = 1'b0;
			end
			else begin // read state
				mm_out_o[i] = mem_line[mem_line_index];
				lane_done[i] = 1'b0;
			end
		end
	end 
// MC0
	if ((local_mem_wr != 1'b1) && (cache_wr_o != 1'b1)) begin // if storing a line then do nothing
		// find new memory access to complete
		for (i=0; i<8; i=i+1) begin
			if (lane_done[i] == 1'b1) begin
				mem_address = MA_i[i][15:3];
				
				if (current_access_type == 1'b1) begin
					cache_address_o = mem_address;
				end
				else begin
					local_mem_address = mem_address[2:0] + local_mem_offset[i];
				end
				current_access_type = mem_type_i[i];
				break;
			end
		end
	end
	
	
	
end
end
end //memory_controller





endmodule 