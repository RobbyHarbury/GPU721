module rjh_GPU721_GPU_cache (
input             Resetn_pin   			 , // Reset
input             Clock_pin     			 , // Clock
input             WR_i          			 ,
input      [12:0] MEM_address_i 			 ,
input      [15:0] MEM_in_i	[7:0]      	 ,

output     [15:0] MEM_out_o [7:0]    	 ,
output            Done_o  
);


//----------------------------------------------------------------------------
//-- Declare internal signals
//----------------------------------------------------------------------------

wire			clock_not;


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
		.WR         	(WR_i) ,
		.MEM_address	(MEM_address_i) ,
		.MEM_in      	({MEM_in_i[7], MEM_in_i[6], MEM_in_i[5], MEM_in_i[4], MEM_in_i[3], MEM_in_i[2], MEM_in_i[1], MEM_in_i[0]}) ,
		.MEM_out    	({MEM_out_o[7], MEM_out_o[6], MEM_out_o[5], MEM_out_o[4], MEM_out_o[3], MEM_out_o[2], MEM_out_o[1], MEM_out_o[0]}) ,
		.Done          (Done_o) 
);







endmodule 