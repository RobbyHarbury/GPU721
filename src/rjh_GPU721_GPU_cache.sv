module rjh_GPU721_GPU_cache 
#(
parameter core_count = 2  
)
(
input             Resetn_pin   			 , // Reset
input             Clock_pin     			 , // Clock
input             WR_i  [core_count-1:0]        			 ,
input      [12:0] MEM_address_i [core_count-1:0]			 ,
input			  cache_access_req_i [core_count-1:0]		,
input      [15:0] MEM_in_i	[core_count-1:0][7:0]      	 ,

output reg    [15:0] MEM_out_o [core_count-1:0][7:0]    	 ,
output            Done_o  [core_count-1:0]
);


//----------------------------------------------------------------------------
//-- Declare internal signals
//----------------------------------------------------------------------------

wire			clock_not;
wire 			   WR;
wire		[12:0] MEM_address;
wire 		[15:0] MEM_in [7:0];
wire 		[15:0] MEM_out [7:0];
wire 			   Done;

reg	[31:0] access_counter [core_count-1:0];
reg [31:0] largest_count;
reg [31:0] core_index;
integer i;

genvar j;


//------------------------------------------------------------------------------------
// Structural section of the code.  The order of the assignments doesn't matter.
//------------------------------------------------------------------------------------

not clock_inverter ( clock_not, Clock_pin );

rjh_cache_4w 
#(
		.data_width(128) ,
		.address_width(13) ,
		.word_addr_width(2)  ,
		.group_addr_width(2)  , 
		.tag_addr_width(9)
) GPU_cache
(
		.Clock			(clock_not) ,
		.Resetn     	(Resetn_pin) ,
		.WR         	(WR) ,
		.MEM_address	(MEM_address) ,
		.MEM_in      	({MEM_in[7], MEM_in[6], MEM_in[5], MEM_in[4], MEM_in[3], MEM_in[2], MEM_in[1], MEM_in[0]}) ,
		.MEM_out    	({MEM_out[7], MEM_out[6], MEM_out[5], MEM_out[4], MEM_out[3], MEM_out[2], MEM_out[1], MEM_out[0]}) ,
		.Done          (Done) 
);

generate
	for (j=0; j<core_count; j+=1) begin : GPU_cache_selector
		assign MEM_out_o[j] = (core_index == j) ? MEM_out : MEM_out_o[j];
		assign Done_o[j] = (core_index == j) ? Done : ~cache_access_req_i[j];

	end
endgenerate

assign WR = WR_i[core_index];
assign MEM_address = MEM_address_i[core_index];
assign MEM_in = MEM_in_i[core_index];

always@(posedge Clock_pin) begin : GPU_data_memory_controller
	if (Resetn_pin == 0) begin  

		for (i=0; i<core_count; i=i+1) begin
			access_counter[i] = 32'd0;
		end
		core_index = 32'd0;
		largest_count = 32'd0;
	end // reset
	else begin //normal operation
		if (Done == 1'b1) begin
			largest_count = 32'd0;
			for (i=0; i<core_count; i=i+1) begin
				if ((cache_access_req_i[i] == 1'b1) && (access_counter[i] > largest_count)) begin
					largest_count = access_counter[i];
					core_index = i;
				end
				access_counter[i] = access_counter[i] + 1;
			access_counter[core_index] = 0;

			end
		end
	end //normal operation
end //GPU_data_memory_controller







endmodule 