// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on

`include "rjh_ir2assembly_sv.sv"
`define SIMULATION

module rjh_GPU721_tb;

reg         Resetn_tb       ; // Active low reset signal
reg         Clock_tb        ;
reg [11:0]	thread_block_address_tb;
reg			thread_block_request_tb;

wire GPU_busy_tb;
wire [119:0] ICis_lane0_tb [2:0]    ; // Instruction to ASCII
wire [119:0] ICis_lane1_tb [2:0]    ; // Instruction to ASCII
wire [119:0] ICis_lane2_tb [2:0]    ; // Instruction to ASCII
wire [119:0] ICis_lane3_tb [2:0]    ; // Instruction to ASCII
wire [119:0] ICis_lane4_tb [2:0]    ; // Instruction to ASCII
wire [119:0] ICis_lane5_tb [2:0]    ; // Instruction to ASCII
wire [119:0] ICis_lane6_tb [2:0]    ; // Instruction to ASCII
wire [119:0] ICis_lane7_tb [2:0]    ; // Instruction to ASCII


rjh_GPU721_top_sv dut(
.Resetn_pin   			 	(Resetn_tb), // Reset
.Clock_pin     			(Clock_tb), // Clock
.thread_block_address_i (thread_block_address_tb), //address for thread block to be executed from CPU
.thread_block_request_i (thread_block_request_tb), // thread block execution request from CPU

.GPU_busy_o					(GPU_busy_tb)  // flag for if GPU threads are too busy for block request
);

//Lane 0-----------------------

rjh_ir2assembly_sv instruction_translate_0_IR1 (
    .IR           ( dut.GPU_core0.SIMD_lane_0.IR1[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane0_tb[0][119:0] )  // ASCII stream translating IR from Binary to English
);

rjh_ir2assembly_sv instruction_translate_0_IR2 (
    .IR           ( dut.GPU_core0.SIMD_lane_0.IR2[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane0_tb[1][119:0] )  // ASCII stream translating IR from Binary to English
);

rjh_ir2assembly_sv instruction_translate_0_IR3 (
    .IR           ( dut.GPU_core0.SIMD_lane_0.IR3[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane0_tb[2][119:0] )  // ASCII stream translating IR from Binary to English
);

//Lane 1-----------------------

rjh_ir2assembly_sv instruction_translate_1_IR1 (
    .IR           ( dut.GPU_core0.SIMD_lane_1.IR1[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane1_tb[0][119:0] )  // ASCII stream translating IR from Binary to English
);

rjh_ir2assembly_sv instruction_translate_1_IR2 (
    .IR           ( dut.GPU_core0.SIMD_lane_1.IR2[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane1_tb[1][119:0] )  // ASCII stream translating IR from Binary to English
);

rjh_ir2assembly_sv instruction_translate_1_IR3 (
    .IR           ( dut.GPU_core0.SIMD_lane_1.IR3[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane1_tb[2][119:0] )  // ASCII stream translating IR from Binary to English
);

//Lane 2-----------------------

rjh_ir2assembly_sv instruction_translate_2_IR1 (
    .IR           ( dut.GPU_core0.SIMD_lane_2.IR1[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane2_tb[0][119:0] )  // ASCII stream translating IR from Binary to English
);

rjh_ir2assembly_sv instruction_translate_2_IR2 (
    .IR           ( dut.GPU_core0.SIMD_lane_2.IR2[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane2_tb[1][119:0] )  // ASCII stream translating IR from Binary to English
);

rjh_ir2assembly_sv instruction_translate_2_IR3 (
    .IR           ( dut.GPU_core0.SIMD_lane_2.IR3[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane2_tb[2][119:0] )  // ASCII stream translating IR from Binary to English
);

//Lane 3-----------------------

rjh_ir2assembly_sv instruction_translate_3_IR1 (
    .IR           ( dut.GPU_core0.SIMD_lane_3.IR1[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane3_tb[0][119:0] )  // ASCII stream translating IR from Binary to English
);

rjh_ir2assembly_sv instruction_translate_3_IR2 (
    .IR           ( dut.GPU_core0.SIMD_lane_3.IR2[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane3_tb[1][119:0] )  // ASCII stream translating IR from Binary to English
);

rjh_ir2assembly_sv instruction_translate_3_IR3 (
    .IR           ( dut.GPU_core0.SIMD_lane_3.IR3[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane3_tb[2][119:0] )  // ASCII stream translating IR from Binary to English
);

//Lane 4-----------------------

rjh_ir2assembly_sv instruction_translate_4_IR1 (
    .IR           ( dut.GPU_core0.SIMD_lane_4.IR1[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane4_tb[0][119:0] )  // ASCII stream translating IR from Binary to English
);

rjh_ir2assembly_sv instruction_translate_4_IR2 (
    .IR           ( dut.GPU_core0.SIMD_lane_4.IR2[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane4_tb[1][119:0] )  // ASCII stream translating IR from Binary to English
);

rjh_ir2assembly_sv instruction_translate_4_IR3 (
    .IR           ( dut.GPU_core0.SIMD_lane_4.IR3[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane4_tb[2][119:0] )  // ASCII stream translating IR from Binary to English
);

//Lane 5-----------------------

rjh_ir2assembly_sv instruction_translate_5_IR1 (
    .IR           ( dut.GPU_core0.SIMD_lane_5.IR1[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane5_tb[0][119:0] )  // ASCII stream translating IR from Binary to English
);

rjh_ir2assembly_sv instruction_translate_5_IR2 (
    .IR           ( dut.GPU_core0.SIMD_lane_5.IR2[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane5_tb[1][119:0] )  // ASCII stream translating IR from Binary to English
);

rjh_ir2assembly_sv instruction_translate_5_IR3 (
    .IR           ( dut.GPU_core0.SIMD_lane_5.IR3[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane5_tb[2][119:0] )  // ASCII stream translating IR from Binary to English
);

//Lane 6-----------------------

rjh_ir2assembly_sv instruction_translate_6_IR1 (
    .IR           ( dut.GPU_core0.SIMD_lane_6.IR1[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane6_tb[0][119:0] )  // ASCII stream translating IR from Binary to English
);

rjh_ir2assembly_sv instruction_translate_6_IR2 (
    .IR           ( dut.GPU_core0.SIMD_lane_6.IR2[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane6_tb[1][119:0] )  // ASCII stream translating IR from Binary to English
);

rjh_ir2assembly_sv instruction_translate_6_IR3 (
    .IR           ( dut.GPU_core0.SIMD_lane_6.IR3[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane6_tb[2][119:0] )  // ASCII stream translating IR from Binary to English
);

//Lane 7-----------------------

rjh_ir2assembly_sv instruction_translate_7_IR1 (
    .IR           ( dut.GPU_core0.SIMD_lane_7.IR1[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane7_tb[0][119:0] )  // ASCII stream translating IR from Binary to English
);

rjh_ir2assembly_sv instruction_translate_7_IR2 (
    .IR           ( dut.GPU_core0.SIMD_lane_7.IR2[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane7_tb[1][119:0] )  // ASCII stream translating IR from Binary to English
);

rjh_ir2assembly_sv instruction_translate_7_IR3 (
    .IR           ( dut.GPU_core0.SIMD_lane_7.IR3[15:0] ), // Instruction word within dut
    .Resetn_pin   ( dut.Resetn_pin        ), // Reset within dut
    .ICis         ( ICis_lane7_tb[2][119:0] )  // ASCII stream translating IR from Binary to English
);

// Setup Free-Running Clock
always #20000 Clock_tb = ~(Clock_tb === 1'd1);

initial begin 
    // Reset DUT
    Resetn_tb = 1'd0;
    repeat (10) @(posedge Clock_tb);

    // Take DUT out of Reset
    Resetn_tb = 1'd1;
	 
	 
	 thread_block_address_tb = 12'd0;
	 thread_block_request_tb = 1'b1;
	 @(posedge Clock_tb);
	 thread_block_address_tb = 12'd32;
	 thread_block_request_tb = 1'b1;
	 @(posedge Clock_tb);
	 thread_block_address_tb = 12'd64;
	 thread_block_request_tb = 1'b1;
	 @(posedge Clock_tb);
	 thread_block_address_tb = 12'd96;
	 thread_block_request_tb = 1'b1;
	 @(posedge Clock_tb);
	 thread_block_address_tb = 12'd128;
	 thread_block_request_tb = 1'b1;
	 @(posedge Clock_tb);
	 thread_block_request_tb = 1'b0;
	 repeat (300) @(posedge Clock_tb);

    // End simultaion (normally we would use "$finish()" but modelsim prefers "$stop()")
    $stop();
end

endmodule 