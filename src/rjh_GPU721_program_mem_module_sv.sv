module rjh_GPU721_program_mem_module_sv (
input             Resetn_pin    , // Reset
input             Clock_pin	  , // Clock
input	  [11:0] thread_block_address_i [7:0] ,
input				PM_access_req_i [7:0] ,
input				block_freeze_i [7:0],
input			  predicate_i	   [7:0],

output reg	  [15:0] PM_out_o	[7:0] ,
output reg    [15:0] PM_pc_o	[7:0] ,
output reg    [3:0] PM_branch_depth_o	[7:0] ,
output reg				PM_ready_o [7:0] ,
output reg				PM_block_free_o [7:0]
);

//----------------------------------------------------------------------------
//-- Declare state machine parameters
//----------------------------------------------------------------------------
localparam [2:0] IDLE = 3'b000;
localparam [2:0] SETUP_0 = 3'b001;
localparam [2:0] SETUP_1 = 3'b010;
localparam [2:0] RUN = 3'b011;
localparam [2:0] BRANCH_0 = 3'b100;
localparam [2:0] BRANCH_1 = 3'b101;
localparam [2:0] BRANCH_STALL = 3'b110;

//----------------------------------------------------------------------------
//-- Declare local parameters
//----------------------------------------------------------------------------
localparam [3:0] LD_IC  = 4'b1010 ; // load
localparam [3:0] ST_IC  = 4'b1011 ; // store
localparam [3:0] BR_IC  = 4'b1100 ; // branch

//----------------------------------------------------------------------------
//-- Declare internal signals
//----------------------------------------------------------------------------

reg [15:0]	PM_block_buf [7:0][7:0];
reg [15:0]	PC [7:0];
reg  [2:0]  state_reg [7:0];
reg  			mem_req;
reg			mem_waiting [7:0];
reg  [2:0]  IR_cnt [7:0];
reg  [2:0]  buf_index;
reg	[8:0]	PM_address;
reg			new_block [7:0];
reg			ld_st_flag [7:0];
reg  [15:0] branch_stack [7:0][15:0];
reg  [3:0]  branch_ptr;
reg  [2:0]  branch_delay [7:0];
reg  [15:0]	branch_address;
reg	 [15:0] branch_offset;

wire			clock_not;
wire [15:0]	PM_out [7:0];

wire			PM_done;

integer i;


//------------------------------------------------------------------------------------
// Structural section of the code.  The order of the assignments doesn't matter.
//------------------------------------------------------------------------------------

not clock_inverter ( clock_not, Clock_pin );

rjh_cache_4w_PM 
#(
	 .data_width (128),
	 .address_width (9),
	 .word_addr_width (2),
	 .group_addr_width (2),
	 .tag_addr_width (5))
my_cache (
	 .Clock      (clock_not ),
	 .Resetn     (Resetn_pin),
	 .MEM_address ( PM_address ),
	 .MEM_out    ({PM_out[7], PM_out[6], PM_out[5], PM_out[4], PM_out[3], PM_out[2], PM_out[1], PM_out[0]}),
	 .Done		 (PM_done)	
);

assign PM_block_free_o = PM_access_req_i;

//-----------------------------------------------------------------------------------------------
// - Behavioral section of the code.  Assignments are evaluated in order, i.e. sequentially.
//-----------------------------------------------------------------------------------------------

always@(posedge Clock_pin) begin : program_memory_controller
//----------------------------------------------------------------------------
// RESET 
//----------------------------------------------------------------------------
if (Resetn_pin == 0) begin  
	for (i=0; i<8; i=i+1) begin
		PM_block_buf[i] = '{16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0};
		branch_stack[i][15:0] = '{16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0};
	end
	PC[7:0] = '{16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0};
	state_reg[7:0] = '{3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0};
	mem_req = 1'd0;
	IR_cnt = '{3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0};
	buf_index = 3'd0;
	mem_waiting = '{1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0};
	new_block = '{1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0};
	branch_ptr = 4'd0;
	branch_delay = '{2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0};
	branch_address = 16'd0;
	branch_offset = 16'd0;
	
	PM_out_o[7:0] = '{16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0};
	PM_pc_o[7:0] = '{16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0};
	PM_branch_depth_o = '{4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0};
	PM_ready_o[7:0] = '{1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0};
	ld_st_flag[7:0] = '{1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0};
	
	
end
else begin //normal operation
	if (PM_done == 1'b1) begin
		mem_req = 1'b0;
	end
	for (i=0; i<8; i=i+1) begin
		case (state_reg[i]) 
		IDLE: begin
			if (PM_access_req_i[i] == 1'b1) begin
				mem_waiting[i] = 1'b1;
				if ((PM_done == 1'b1) && (mem_req == 1'b0)) begin
					mem_waiting[i] = 1'b0;
					PM_address = thread_block_address_i[i][11:3];
					PC[i] = thread_block_address_i[i];
					IR_cnt[i] = thread_block_address_i[i][2:0];
					mem_req = 1'b1;
					state_reg[i] = SETUP_0;
				end
			end
			else begin
				state_reg[i] = IDLE;
			end
		end //IDLE
			
		
		SETUP_0: begin
			if (PM_done == 1'b1) begin
				if (mem_waiting[i] == 1'b0) begin // if not stuck in SETUP waiting for mem
					buf_index = IR_cnt[i];
					PM_block_buf[i] = PM_out;
					PM_out_o[i] = PM_block_buf[i][buf_index];
					PM_pc_o[i] = PC[i];
					PC[i] += 16'd1;
				end
				if (IR_cnt[i] == 3'd7) begin
					mem_waiting[i] = 1'b1;
					if (mem_req == 1'b0) begin
						mem_waiting[i] = 1'b0;
						mem_req = 1'b1;
						PM_address = PC[i][11:3];
						PM_ready_o[i] = 1'b1;
						new_block[i] = 1'b1;
						IR_cnt[i] = 3'd0;
						state_reg[i] = SETUP_1;
					end
					else begin
						state_reg[i] = SETUP_0;
					end
				end
				else begin
					IR_cnt[i] += 3'd1;
					PM_ready_o[i] = 1'b1;
					state_reg[i] = SETUP_1;
				end
			end
			else begin
				state_reg[i] = SETUP_0;
			end
		end //SETUP_0
		
		SETUP_1: begin // add a delay for the scheduler to calculate if there are enough free lanes
			state_reg[i] = RUN;
		end // SETUP_1
		
		RUN: begin

			if (PM_access_req_i[i] == 1'b1) begin
				if ((mem_waiting[i] == 1'b0) && (new_block[i] == 1'b1)) begin
					PM_block_buf[i] = PM_out;
					new_block[i] = 1'b0;
				end
				if ((block_freeze_i[i] == 1'b0)) begin
					if (mem_waiting[i] == 1'b0) begin
						buf_index = IR_cnt[i];
						PM_out_o[i] = PM_block_buf[i][buf_index];
						PM_pc_o[i] = PC[i];
						PC[i] += 16'd1;
					
						
					end
					if ((predicate_i[i] == 1'b0) && (branch_delay[i] == 2'b00)) begin
						mem_waiting[i] = 1'b1;
						PM_ready_o[i] = 1'b0;
						if ((PM_done == 1'b1) && (mem_req == 1'b0)) begin
							mem_waiting[i] = 1'b0;
							PM_ready_o[i] = 1'b1;
							PM_out_o[i] = 16'hffff;
							mem_req = 1'b1;
							PM_branch_depth_o[i] -= 1;
							branch_ptr = PM_branch_depth_o[i];
							PC[i] = branch_stack[i][branch_ptr] + 16'd1;
							PM_address = PC[i][11:3];
							IR_cnt[i] = PC[i][2:0];
							branch_delay[i] = 3'd4;
							new_block[i] = 1'b1;
						end
					end
					else if (IR_cnt[i] == 3'd7) begin
						mem_waiting[i] = 1'b1;
						PM_ready_o[i] = 1'b0;
						if ((PM_done == 1'b1) && (mem_req == 1'b0)) begin
							mem_waiting[i] = 1'b0;
							PM_ready_o[i] = 1'b1;
							mem_req = 1'b1;
							PM_address = PC[i][11:3];
							new_block[i] = 1'b1;
							IR_cnt[i] = 3'd0;
						end
					end
					else begin
						IR_cnt[i] += 3'd1;
					end

					if (branch_delay[i] != 3'b000) begin
						branch_delay[i] -= 1;
					end

					if (((PM_out_o[i][15:12] == LD_IC) || (PM_out_o[i][15:12] == ST_IC)) && (ld_st_flag[i] == 1'b0)) begin
						ld_st_flag[i] = 1'b1;
						state_reg[i] = RUN;
					end
					else if ((PM_out_o[i][15:12] == BR_IC) && (ld_st_flag[i] == 1'b0) && (predicate_i[i] == 1'b1)) begin
						state_reg[i] = BRANCH_0;
					end
					else if (predicate_i[i] == 1'b1) begin
						ld_st_flag[i] = 1'b0;
						state_reg[i] = RUN;
					end
				end	
			end
			else begin
				mem_waiting[i] = 1'b0;
				PM_ready_o[i] = 1'b0;
				state_reg[i] = IDLE;
			end
		end // RUN

		BRANCH_0: begin
			if (PM_access_req_i[i] == 1'b1) begin
				if ((mem_waiting[i] == 1'b0) && (IR_cnt[i] == 3'd0) && (new_block[i] == 1'b1)) begin
					PM_block_buf[i] = PM_out;
					new_block[i] = 1'b0;
				end
				if (block_freeze_i[i] == 1'b0) begin
					buf_index = IR_cnt[i];
					if (mem_waiting[i] == 1'b0) begin
						PM_out_o[i] = PM_block_buf[i][buf_index];
						PM_pc_o[i] = PC[i];
					end
					branch_ptr = PM_branch_depth_o[i];
					branch_address = PC[i] + PM_block_buf[i][buf_index];
					branch_offset = {13'd0, IR_cnt[i]} + PM_block_buf[i][buf_index];
					if ((branch_offset < 7) && (branch_offset > -1)) begin
						if (PC[i] != branch_stack[i][branch_ptr - 4'd1]) begin
							branch_stack[i][branch_ptr] = PC[i];
							PM_branch_depth_o[i] += 4'd1;
						end
						IR_cnt[i] = branch_address[2:0];
						PC[i] = branch_address;
						state_reg[i] = BRANCH_1;
					end
					else begin
						mem_waiting[i] = 1'b1;
						PM_ready_o[i] = 1'b0;
						if ((PM_done == 1'b1) && (mem_req == 1'b0)) begin
							mem_waiting[i] = 1'b0;
							PM_ready_o[i] = 1'b1;
							mem_req = 1'b1;
							PM_address = branch_address[11:3];
							IR_cnt[i] = branch_address[2:0];
							if (PC[i] != branch_stack[i][branch_ptr - 4'd1]) begin
								branch_stack[i][branch_ptr] = PC[i];
								PM_branch_depth_o[i] += 4'd1;
							end
							PC[i] = branch_address;
							state_reg[i] = BRANCH_1;
							new_block[i] = 1'b1;
						end
					end
				end
				else begin
				state_reg[i] = BRANCH_0;
				end
			end
			else begin
				mem_waiting[i] = 1'b0;
				PM_ready_o[i] = 1'b0;
				state_reg[i] = IDLE;
			end
		end // BRANCH_0

		BRANCH_1: begin
			if (PM_access_req_i[i] == 1'b1) begin
				if (new_block[i] == 1'b1)begin
					PM_block_buf[i] = PM_out;
					new_block[i] = 1'b0;
				end
				PM_out_o[i] = 16'hffff;
				state_reg[i] = RUN;
			end
			else begin
				mem_waiting[i] = 1'b0;
				PM_ready_o[i] = 1'b0;
				state_reg[i] = IDLE;
			end
		end // BRANCH_1

		/*BRANCH_STALL: begin // wait for lanes to calculate predicate before feeding next instructions
			if (PM_access_req_i[i] == 1'b1) begin
				PM_block_buf[i] = PM_out;
				PM_out_o[i] = 16'hffff;
				if (branch_delay[i] != 2'b00) begin
					branch_delay[i] -= 1;
					state_reg[i] = BRANCH_STALL;
				end
				else begin
					state_reg[i] = RUN;
				end
			end
			else begin
				mem_waiting[i] = 1'b0;
				PM_ready_o[i] = 1'b0;
				state_reg[i] = IDLE;
			end
		end*/ // BRANCH_STALL

		endcase
	end

end //normal operation
end //program_memory_controller
















endmodule 