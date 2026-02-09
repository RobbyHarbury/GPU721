module rjh_ir2assembly_sv (
input      [15:0] IR         ,
input             Resetn_pin ,
output reg [119:0] ICis
);

// This module is converting the IW information into a string of ASCII characters. 
// This is ONLY needed for debugging purposes. 
// It should be eliminated when compiling/ synthesizing for FPGA implementation. 
// It is described behaviorally. 
// In the ModelSim wavform, select the display radix for this output signal to be ASCII.

// Internal wire declarations
reg [7:0] IR9to5  ;
reg [7:0] IR4to0   ;
reg [31:0] SIMD_status;
reg [7:0] br_val ;


always @ (*) begin
    // Converting register numbers to ASCII digit character numbers
    IR9to5 = 8'h30 + {2'b00, IR[9:5]};
    IR4to0 = 8'h30 + {2'b00, IR[4:0]};

    // Similarly for the status bit and status bit value used in the (conditional) JUMP
    if          (IR[11:10] == 2'b00) begin br_val = "U"; end
	 else if     (IR[11:10] == 2'b01) begin br_val = "="; end
	 else if     (IR[11:10] == 2'b10) begin br_val = ">"; end
	 else if     (IR[11:10] == 2'b11) begin br_val = "<"; end
	 
	 if			 (IR[10] == 1'b1) begin SIMD_status = "SIMD"; end
	 else									begin SIMD_status = " x16";  end

    // After the IR (IW) is passed on to the CU in MC1, the current IC/IW can be 
    // idenitified and the corresponding assembly instruction displayed.

    if (Resetn_pin == 1'b0)
        ICis = {8'h52, 8'h53, 8'h54, 8'h20}; //RST;

		  else case (IR[15:12])
        
        4'b0001 : ICis = {"ADD R", IR9to5, ", R", IR4to0, SIMD_status, ";"}; //ADD
        4'b0010 : ICis = {"SUB R", IR9to5, ", R", IR4to0, SIMD_status, ";"}; //SUB
		  4'b0011 : ICis = {"MUL R", IR9to5, ", R", IR4to0, SIMD_status, ";"}; //MUL
		  4'b0100 : ICis = {"DIV R", IR9to5, ", R", IR4to0, SIMD_status, ";"}; //DIV
        4'b0101 : ICis = {"AND R", IR9to5, ", R", IR4to0, SIMD_status, ";"}; //AND
        4'b0110 : ICis = {"OR  R", IR9to5, ", R", IR4to0, SIMD_status, ";"}; //OR
		  4'b0111 : ICis = {"XOR R", IR9to5, ", R", IR4to0, SIMD_status, ";"}; //XOR
		  4'b1000 : ICis = {"SLL R", IR9to5, ", #", IR4to0, SIMD_status, ";"}; //SLL
		  4'b1001 : ICis = {"SRL R", IR9to5, ", #", IR4to0, SIMD_status, ";"}; //SRL
		  4'b1010 : ICis = {"LD ", IR4to0, ", MA", IR9to5, ";"}; //LD
        4'b1011 : ICis = {"ST ", IR4to0, ", MA", IR9to5, ";"}; //ST
		  4'b1100 : ICis = {"BR R", IR9to5, br_val, "R", IR4to0, ";"}; //BR
		  4'b1101 : ICis = {"SYNC;"}; //sync
		  4'b1110 : ICis = {"EXIT;"}; //exit
		  4'b1111 : ICis = {"STALL;"}; //STALL
        // Note that this can also be written as: ICis = {"VSUB R",IR9to5,", R",IR4to0,";"};
        default : ICis = {"NDEF"}; //NDEF
        endcase
end
endmodule
