module rjh_GPU721_SIMD_lane_sv (
input             	Resetn_pin    		, // Reset
input             	Clock_pin    		, // Clock
input		  [15:0] 	IW_i			 		, // IW
input		  [8:0]  	thread_block_idx_i, // thread block idx
input		  [2:0]  	thread_idx_i		, // thread block idx
input		  [15:0]		MM_out_i				, // memory data output
input						lane_freeze_i		, // lane is frozen waiting for memory\
input		  [15:0]		PC_i					, // PC for incoming instruction

output reg				mem_access_o		, // flag that signals that the lane is doing a data memory access

output reg				lane_done_o			, // lane has reached exit instruction
output reg				WR_o					, // memory write enable
output reg				mem_type_o			, // type of memory to access:0-> local, 1-> GPU cache
output reg [15:0]		MA_o					, // memory address
output reg [15:0]		MM_in_o				  // memory data input

);

//instructions
	

	//arithmetic manipulation
localparam [3:0] ADD_IC = 4'b0001 ; // add
localparam [3:0] SUB_IC = 4'b0010 ; // sub
localparam [3:0] MUL_IC = 4'b0011 ; // mul
localparam [3:0] DIV_IC = 4'b0100 ; // div
	//logic manipulation
localparam [3:0] AND_IC = 4'b0101 ; // and
localparam [3:0] OR_IC  = 4'b0110 ; // or
localparam [3:0] XOR_IC = 4'b0111 ; // xor
	//shift
localparam [3:0] SLL_IC = 4'b1000 ; // shift left logic
localparam [3:0] SRL_IC = 4'b1001 ; // shift right logic
	//data transfer
localparam [3:0] LD_IC  = 4'b1010 ; // load
localparam [3:0] ST_IC  = 4'b1011 ; // store
	//flow control
localparam [3:0] BR_IC  = 4'b1100 ; // branch
localparam [3:0] BAR_IC = 4'b1101 ; // barrier synchronization
localparam [3:0] EXT_IC = 4'b1110 ; // exit thread

//branch conditions
localparam [1:0] BR_U  = 2'b00 ; // unconditional branch
localparam [1:0] BR_EQ = 2'b01 ; // branch if equal
localparam [1:0] BR_GT = 2'b10 ; // branch if greater than
localparam [1:0] BR_LT = 2'b11 ; // branch if less than


//----------------------------------------------------------------------------
//-- Declare internal signals
//----------------------------------------------------------------------------
reg  [15:0]    R       [31:0] ; // Register File (RF) 32 16-bit registers
reg				predicate		; // Predicate register for branch conditional evaluation
reg  [15:0]    IR3            ; // Instruction Register 3
reg  [15:0]    IR2            ; // Instruction Register 2
reg  [15:0]    IR1            ; // Instruction Register 1
reg            stall_mc0      ; // Stall Control Bits
reg            stall_mc1      ; // Stall Control Bits
reg            stall_mc2      ; // Stall Control Bits
reg            stall_mc3      ; // Stall Control Bits
reg  [15:0]    MAB            ; // Memory Address B
reg  [15:0]    MAX            ; // Memory Address X
reg  [15:0]    MAeff          ; // Memory Address Effective
reg  [15:0]    TA             ; // Temporary Input of Arithmetic-Logic-Unit "A"
reg  [15:0]    TB             ; // Temporary Input of Arithmetic-Logic-Unit "B"
reg  [16:0]    TALUout        ; // Temoprary Output of Arithmetic-Logic-Unit with carry
reg  [15:0]    TALUH          ; // Temporary Output of Arithmetic-Logic-Unit "High"
reg  [15:0]    TALUL          ; // Temporary Output of Arithmetic-Logic-Unit "Low"
reg  [4:0]    Ri1             ; // Index within registerfile
reg  [4:0]    Rj1             ; // Index within registerfile
reg  [4:0]    Ri2             ; // Index within registerfile
reg  [4:0]    Rj2             ; // Index within registerfile
reg  [4:0]    Ri3             ; // Index within registerfile
reg  [4:0]    Rj3             ; // Index within registerfile
wire [15:0]   MUL_SIMD_out_0	; // Mul output from SIMD multiplier 0
wire [15:0]   MUL_SIMD_out_1	; // Mul output from SIMD multiplier 1
wire [31:0]		MUL_out			; // Output from multiplier
wire [7:0]		DIV_SIMD_q_0	; // DIV SIMD quotient out 0
wire [7:0]		DIV_SIMD_q_1	; // DIV SIMD quotient out 1
wire [7:0]		DIV_SIMD_rem_0	; // DIV SIMD remainder out 0
wire [7:0]		DIV_SIMD_rem_1	; // DIV SIMD remainder out 1
wire [15:0] 	DIV_q				; // DIV quotient out
wire [15:0] 	DIV_rem			; // DIV remainder out

integer k;

rjh_mul_8 mul_SIMD_0 (
	 .dataa		 ( TA [7:0]			), // input
	 .datab		 ( TB [7:0]			), // input
	 .result		 ( MUL_SIMD_out_0 [15:0]		)  // output
);
rjh_mul_8 mul_SIMD_1 (
	 .dataa		 ( TA [15:8]			), // input
	 .datab		 ( TB [15:8]			), // input
	 .result		 ( MUL_SIMD_out_1 [15:0]		)  // output
);

rjh_mul_16 mul_16 (
	 .dataa		 ( TA [15:0]			), // input
	 .datab		 ( TB [15:0]			), // input
	 .result		 ( MUL_out [31:0]		)  // output
);

rjh_div_8 div_SIMD_0 (
	 .denom		 ( TB [7:0]			), // input
	 .numer		 ( TA [7:0]			), // input
	 .quotient	 ( DIV_SIMD_q_0 [7:0]			), // output
	 .remain	 	 ( DIV_SIMD_rem_0 [7:0]			) // output
);

rjh_div_8 div_SIMD_1 (
	 .denom		 ( TB [15:8]			), // input
	 .numer		 ( TA [15:8]			), // input
	 .quotient	 ( DIV_SIMD_q_1 [7:0]			), // output
	 .remain	 	 ( DIV_SIMD_rem_1 [7:0]			) // output
);

rjh_div_16 div (
	 .denom		 ( TB [15:0]			), // input
	 .numer		 ( TA [15:0]			), // input
	 .quotient	 ( DIV_q [15:0]			), // output
	 .remain	 	 ( DIV_rem [15:0]			) // output
);



//------------------------------------------------------------------------------------------------------------------------------------------
// - Behavioral section of the code.  Assignments are evaluated in order, i.e. sequentially.
// - New assigned values are visible outside the always block only after it is exit.
// - Last assigned value will be the exit value.
//------------------------------------------------------------------------------------------------------------------------------------------
always@(posedge Clock_pin) begin : my_SIMD_lane
//----------------------------------------------------------------------------
// RESET 
//----------------------------------------------------------------------------
if (Resetn_pin == 0) begin    
   // - The reset is active low and clock synchronous.
   // - Initialize registers.
	for (k = 0; k < 30; k = k+1) begin R[k] = 0; end    
	MAB         = 16'd0;
   MAX         = 16'd0;
   MAeff       = 16'd0;
   TA          = 16'd0;
   TB          = 16'd0;
   TALUH       = 16'd0;
   TALUL       = 16'd0;
	TALUout     = 17'd0;
   IR1         = 16'hffff; // All IRs are initialized to the "don't care OpCode value 0xffff
   IR2         = 16'hffff;
   IR3         = 16'hffff;
	Ri1         = 5'd0;
   Rj1         = 5'd0;
   Ri2         = 5'd0;
   Rj2         = 5'd0;
   Ri3         = 5'd0;
	Rj3         = 5'd0;
	stall_mc0   = 1'd0;
	stall_mc1   = 1'd0;
	stall_mc2   = 1'd0;
	stall_mc3   = 1'd0;
	predicate	= 1'd0;
	lane_done_o = 1'd0;
	WR_o			= 1'd0;
	mem_type_o  = 1'd0;
	MA_o			= 16'd0;
	MM_in_o		= 16'd0;
	mem_access_o = 1'd0;
	
end // if (Resetn_pin == 0)
else begin // Normal Operation
if (lane_freeze_i == 0) begin

//----------------------------------------------------------------------------
// MACHINE CYCLE 3
//----------------------------------------------------------------------------
    // MC3 is executed first because its assignments might be needed by the instructions executing MC2 or MC1 to resolve data or control D/H.
    // An instruction that has arrived in MC3 does not have any dependency.
    if ((stall_mc3 == 0) && (IR3 != 16'hffff)) begin 
        case (IR3[15:12]) // Decode the OpCode of the IW
            LD_IC: begin
               R[Rj3] = MM_out_i;
					mem_access_o = 1'b0;
            end // LD_IC
            ST_IC: begin 
					WR_o = 1'b0;
					mem_access_o = 1'b0;
				end // ST_IC
            BR_IC: begin

            end // BR_IC
				MUL_IC, DIV_IC: begin
				R[Ri3] = TALUH;
				R[Rj3] = TALUL;
				end // MUL_IC, DIV_IC
            ADD_IC, SUB_IC, AND_IC, OR_IC, XOR_IC, SLL_IC, SRL_IC: begin
                R[Ri3] = TALUH;
            end // ADD_IC, SUB_IC, AND_IC, OR_IC, XOR_IC, SLL_IC, SRL_IC
				EXT_IC: begin
					lane_done_o = 0;// reached exit, lane is done with thread block
				end // EXT_IC
            default: begin // Default case should not be reached0
                `ifdef SIMULATION
                $display("ERROR: Default Case Selection Reached from MC3 , OPCODE: %b @ %t",IR3[15:12], $time());
                `endif
            end // default
        endcase // IR3[15:12]
    end // stall_mc3

//----------------------------------------------------------------------------
// MACHINE CYCLE 2
//----------------------------------------------------------------------------
    if ((stall_mc2 == 0) && (IR2 != 16'hffff)) begin
        case (IR2[15:12]) // Decode the OpCode of the IW
            BR_IC: begin

            end // BR_IC
				LD_IC: begin
					mem_access_o = 1'b1;
				end
            ST_IC: begin
					mem_access_o = 1'b1;
            end // ST_IC
				
            //----------------------------------------------------------------------------
            // For all assignments that target TALUH we use TALUout.  This is 17-bits wide
            //     to account for the value of the carry when necessary.
            //----------------------------------------------------------------------------
            ADD_IC: begin
					 if (IR2[10] == 0) begin //non SIMD
						TALUout = TA + TB;
						TALUH = TALUout[15:0];
					 end
                else begin // SIMD version
						TALUout[8:0] = TA[7:0] + TB[7:0];
						TALUout[16:8] = TA[15:8] + TB[15:8];
						TALUH = TALUout[15:0];
					 end
            end // ADD_IC
                
            SUB_IC: begin
                if (IR2[10] == 0) begin //non SIMD
						TALUout = TA - TB;
						TALUH = TALUout[15:0];
					 end
                else begin // SIMD version
						TALUout[8:0] = TA[7:0] - TB[7:0];
						TALUout[16:8] = TA[15:8] - TB[15:8];
						TALUH = TALUout[15:0];
					 end
            end // SUB_IC
				MUL_IC: begin
					 if (IR2[10] == 0) begin //non SIMD
						TALUH = MUL_out[31:16];
						TALUL = MUL_out[15:0];
					 end
                else begin // SIMD version
						TALUH = {MUL_SIMD_out_1[15:8], MUL_SIMD_out_0[15:8]};
						TALUL = {MUL_SIMD_out_1[7:0], MUL_SIMD_out_0[7:0]};
					 end
				end // MUL_IC
				DIV_IC: begin
					 if (IR2[10] == 0) begin //non SIMD
						TALUH = DIV_q[15:0];
						TALUL = DIV_rem[15:0];
					 end
                else begin // SIMD version
						TALUH = {DIV_SIMD_q_1[7:0], DIV_SIMD_q_0[7:0]};
						TALUL = {DIV_SIMD_rem_1[7:0], DIV_SIMD_rem_0[7:0]};
					 end
				end // DIV_IC
            AND_IC: begin
                if (IR2[10] == 0) begin //non SIMD
						TALUout = TA & TB;
						TALUH = TALUout[15:0];
					 end
                else begin // SIMD version
						TALUout[8:0] = TA[7:0] & TB[7:0];
						TALUout[15:8] = TA[15:8] & TB[15:8];
						TALUH = TALUout[15:0];
					 end
            end // AND_IC
            OR_IC: begin
                if (IR2[10] == 0) begin //non SIMD
						TALUout = TA | TB;
						TALUH = TALUout[15:0];
					 end
                else begin // SIMD version
						TALUout[8:0] = TA[7:0] | TB[7:0];
						TALUout[15:8] = TA[15:8] | TB[15:8];
						TALUH = TALUout[15:0];
					 end
            end // OR_IC
				XOR_IC: begin
                if (IR2[10] == 0) begin //non SIMD
						TALUout = TA ^ TB;
						TALUH = TALUout[15:0];
					 end
                else begin // SIMD version
						TALUout[8:0] = TA[7:0] ^ TB[7:0];
						TALUout[15:8] = TA[15:8] ^ TB[15:8];
						TALUH = TALUout[15:0];
					 end
            end // XOR_IC
            SLL_IC: begin
					 if (IR2[10] == 0) begin //non SIMD
						TALUout = TA << Rj2;
						TALUH = TALUout[15:0];
					 end
                else begin // SIMD version
						TALUout[8:0] = TA[7:0] << Rj2;
						TALUout[15:8] = TA[15:8] << Rj2;
						TALUH = TALUout[15:0];
					 end
            end // SLL_IC
				SRL_IC: begin
					 if (IR2[10] == 0) begin //non SIMD
						TALUout = TA >> Rj2;
						TALUH = TALUout[15:0];
					 end
                else begin // SIMD version
						TALUout[8:0] = TA[7:0] >> Rj2;
						TALUout[15:8] = TA[15:8] >> Rj2;
						TALUH = TALUout[15:0];
					 end
            end // SRL_IC
				EXT_IC: begin
					lane_done_o = 1;// reached exit, lane is done with thread block
				end // EXT_IC
				
				
            default: begin // Default case should not be reached
                `ifdef SIMULATION
                $display("ERROR: Default Case Selection Reached from MC2 , OPCODE: %b @ %t",IR2[15:12], $time());
                `endif
            end //default
        endcase // IR2[15:12]
    end // stall_mc2

//----------------------------------------------------------------------------
// MACHINE CYCLE 1
//----------------------------------------------------------------------------
    if ((stall_mc1 == 0) && (IR1 != 16'hffff)) begin // MC1, or Operand Fetch for manip inst, or Address_Fetch for transfer and flow control inst
        case (IR1[15:12]) // Decode the OpCode of the IW
		  		BR_IC: begin
					MAB = IW_i[15:0]; // Load MAB with base address constant value embedded in IW-field; the value 0 emulates the Register Direct AM
					case (IR1[11:10])
                   BR_U : begin predicate = 1'b1; end
                   BR_EQ: begin if (R[Ri1] == R[Rj1]) predicate = 1'b1; end
						 BR_GT: begin if (R[Ri1] > R[Rj1]) predicate = 1'b1; end
						 BR_LT: begin if (R[Ri1] < R[Rj1]) predicate = 1'b1; end
                   default: predicate = 1'b0;
               endcase
					lane_done_o = 0;
				
            end // BR_IC
				LD_IC: begin
					 MAB = IW_i[15:0]; // Load MAB with base address constant value embedded in IW-field; the value 0 emulates the Register Direct AM
                if (Ri1 == 0) begin
                    MAX = 0; 
                end
					 else if (Ri1 == 1) begin
                    MAX = PC_i; // Load MAX with PC; the value 1 emulates the PC-relative AM
                end
                else if ((Ri1 == Ri2) && (IR2[15:12] != 4'b1111) && (IR2[15:12] != BR_IC) && (IR2[15:12] != BAR_IC) && (IR2[15:12] != EXT_IC)) begin
                    MAX = TALUH[15:0]; // <-- DF-FU = Data Forwarding from the instruction in MC2
                end
					 else if ((Ri1 == Rj2) && ((IR2[15:12] == MUL_IC) || (IR2[15:12] == DIV_IC))) begin
						  MAX = TALUL[15:0];
					 end
                else begin
                    MAX = R[Ri1][15:0];
                end
					 MAeff = MAB + MAX;
					 MA_o = MAeff;
					 mem_type_o = IR1[10];
                WR_o = 1'b0; // For LD_IC we ensure here that WR_MM=0.
					 mem_access_o = 1'b1;
					 lane_done_o = 0;
            end // LD_IC
				ST_IC: begin
					 MAB = IW_i[15:0]; // Load MAB with base address constant value embedded in IW-field; the value 0 emulates the Register Direct AM
                if (Ri1 == 0) begin
                    MAX = 0; 
                end
					 else if (Ri1 == 1) begin
                    MAX = PC_i; // Load MAX with PC; the value 1 emulates the PC-relative AM
                end

                else if ((Ri1 == Ri2) && (IR2[15:12] != 4'b1111) && (IR2[15:12] != BR_IC) && (IR2[15:12] != BAR_IC) && (IR2[15:12] != EXT_IC))begin
                    MAX = TALUH[15:0]; // <-- DF-FU = Data Forwarding from the instruction in MC2
                end
					 else if ((Ri1 == Rj2) && ((IR2[15:12] == MUL_IC) || (IR2[15:12] == DIV_IC))) begin
						  MAX = TALUL[15:0];
					 end
                else begin
                    MAX = R[Ri1][15:0];
                end
					 
					 MAeff = MAB + MAX;
					 if (MAeff != 16'hffff) begin
                    WR_o = 1'b1;
						  end
						  else begin
                    WR_o = 1'b0;
						  end
		
					 if ((Rj1 == Ri2) && (IR2[15:12] != 4'b1111) && (IR2[15:12] != BR_IC) && (IR2[15:12] != BAR_IC) && (IR2[15:12] != EXT_IC))begin
					 MM_in_o = TALUH;
					 end
					 else if ((Rj1 == Rj2) && ((IR2[15:12] == MUL_IC) || (IR2[15:12] == DIV_IC))) begin
					 MM_in_o = TALUL;
					 end
					 else begin
					 MM_in_o = R[Rj1];
					 end
					 MA_o = MAeff;
					 mem_type_o = IR1[10];
					 mem_access_o = 1'b1;
					 lane_done_o = 0;
            end // ST_IC

            SLL_IC, SRL_IC: begin
               if ((Ri1 == Ri2) && (IR2[15:12] != 4'b1111) && (IR2[15:12] != BR_IC) && (IR2[15:12] != BAR_IC) && (IR2[15:12] != EXT_IC))begin
						TA = TALUH;
					end
					else if ((Ri1 == Rj2) && ((IR2[15:12] == MUL_IC) || (IR2[15:12] == DIV_IC))) begin
						TA = TALUL;
					end
					else begin
						TA = R[Ri1];
					end
					lane_done_o = 0;
            end // SLL_IC, SRL_IC
           
            ADD_IC, SUB_IC, AND_IC, OR_IC, MUL_IC, DIV_IC, XOR_IC: begin
               if ((Ri1 == Ri2) && (IR2[15:12] != 4'b1111) && (IR2[15:12] != BR_IC) && (IR2[15:12] != BAR_IC) && (IR2[15:12] != EXT_IC)) begin
						TA = TALUH;
					end
					else if ((Ri1 == Rj2) && ((IR2[15:12] == MUL_IC) || (IR2[15:12] == DIV_IC))) begin
						TA = TALUL;
					end
					else begin
						TA = R[Ri1];
					end
               if ((Rj1 == Ri2) && (IR2[15:12] != 4'b1111) && (IR2[15:12] != BR_IC) && (IR2[15:12] != BAR_IC) && (IR2[15:12] != EXT_IC))begin
						TB = TALUH;
					end
					else if ((Rj1 == Rj2) && ((IR2[15:12] == MUL_IC) || (IR2[15:12] == DIV_IC))) begin
						TB = TALUL;
					end
					else begin
						TB = R[Rj1];
					end
					lane_done_o = 0;
            end // SWAP_IC, ADD_IC, SUB_IC, AND_IC, OR_IC
				EXT_IC: begin
					lane_done_o = 1;// reached exit, lane is done with thread block
				end // EXT_IC
            default: begin // Default case should not be reached
                `ifdef SIMULATION
                $display("ERROR: Default Case Selection Reached from MC1 , OPCODE: %b @ %t",IR1[15:12], $time());
                `endif
            end //default
        endcase // IR1[15:12]
    end // stall_mc1

//----------------------------------------------------------------------------
// MACHINE CYCLE 0 and Stall Control
//----------------------------------------------------------------------------
    // The only data D/H that can occur are RAW.  These are automatically resolved.  
    // In the case of the JUMPS we stall until the adress of the next instruction to be executed is known.
    // The IR value 0xffff I call a "don't care" OpCode value.  
    // It allows us to control the refill of the pipe after the stalls of a jump emptied it.
    // Instruction in MC2 can move to MC3; 
    IR3 = IR2;
    Ri3 = Ri2;
    Rj3 = Rj2;

    // Instruction in MC1 can move to MC2; Rj2 may need to be = Ri1 for certain instruction sequences
    IR2 = IR1;
    Ri2 = Ri1;
    Rj2 = Rj1;
	 
	 R[30] = {7'd0, thread_block_idx_i};
	 R[31] = {13'd0, thread_idx_i};



    // Instruction in MC0 can move to MC1;     
    if ((stall_mc0 == 0) && (IR1[15:12] != LD_IC) && (IR1[15:12] != ST_IC)) begin
        // Below: IW0 is fetched directly into IR1, Ri1, and Rj1
        IR1 = IW_i; 
        Ri1 = IW_i[9:5];
        Rj1 = IW_i[4:0]; 
        stall_mc1 = 0; 
    end
    // Instruction in MC0 is stalled and IR1 is loaded with the "don't care IW"    
    else begin 
        stall_mc0 = 1; 
        IR1 = 16'hffff; 
    end 
    // After the JMP_IC instruction reaches MC3 OR (LD_IC or ST_C) reach MC1,
    // start refilling the pipe by removing the stalls. For JMP_IC the stalls are 
    // removed in this order: stall_mc0 --> stall_mc1 --> stall_mc2
    if ((IR3 == 16'hffff) || (IR2[15:12] == LD_IC) || (IR2[15:12] == ST_IC)) begin
        stall_mc0 = 0; 
    end
end
end//normal operation
end //my_SIMD_lane
	

endmodule 