// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
//----------------------------------------------------------------------------
// (c) Dorin Patru 2022; Updated by Stefan Maczynski 2023
//----------------------------------------------------------------------------
module rjh_CAM_sv 
#(
parameter addr_width = 2  , // group field width
parameter data_width = 9    // tag field width  
)
(
input                        Clock        , // Used for syncronous write
input                        Resetn       , // Syncronous reset
input                        WR           , // Write-Enable
input  [addr_width-1    : 0] Write_Addr   , // "Group" to write incoming "TAG or Block" to
input  [data_width-1    : 0] Data_In      , // "TAG or Block" to check for stored in CAM
output                       Hit          , // Was "TAG or Block" found in CAM? This is just the bitwise or of CAM_Out
output [2**addr_width-1 : 0] CAM_Out      , // "Group" where tag was found encoded in one-hot
output [data_width-1    : 0] ADDR_Out       // "TAG or Block" stored at "GROUP"
);

integer i; // Used in "for" loops -> loops must be written for synthesis tool to unroll
genvar  j; // Used in "generate for" loops -> unrolled guarenteed by synthesis tool

// "TAGs" stored in CAM
    //  -> Note that MSB tracks whether the cell has ever been written to
reg  [data_width : 0] cam_contents [2**addr_width-1 : 0];

// We want to store information in flip-flops, never latches
always @(posedge Clock) begin : write_and_reset_block
    if (!Resetn) begin
        for(i=0; i<2**addr_width; i=i+1) begin
            cam_contents[i] = {data_width+1{1'd1}};
        end
    end
    else begin
        if(WR) begin
            cam_contents[Write_Addr] = {1'd0,Data_In};
        end
    end // else Resetn
end // write_reset_block

// We want to test the contents of the CAM asyncronously
// Note that this portion MUST synthesize to ONLY combinational logic
// -> Designing hardware is the job of the engineer, not the tool!
    // No latches!
        // Remember: latches cannot be attached to a scan chain (DFT!), and create obnoxious setup and hold time requirements
        // Your RTL sim may look good, but behavior may not be idential once in an FPGA or Silicon, how would you debug that? (DFT!)
// Content-Addressable Read:
generate
    for (j=0; j<(2**addr_width); j=j+1) begin : search
        assign CAM_Out[j] = (cam_contents[j] == {1'd0,Data_In});
    end
endgenerate

// Address-Addressable Read:
assign Hit = |CAM_Out;
assign ADDR_Out = cam_contents[Write_Addr][data_width-1 : 0];

endmodule
