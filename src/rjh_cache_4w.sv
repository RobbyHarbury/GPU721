// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
//----------------------------------------------------------------------------
// (c) Dorin Patru 2022; Updated by Stefan Maczynski 2023
//
// 4-Way Set Associative Mapped Cache and Memory;
// The maximum memory capacity is 2^16 16-bit words.
// There are 2^5=32 words per block, and therefore 2^11 total blocks in MEM.
// The cache has 32 block locations.
// The address structure is: TAG=8-bit | Group=3-bit | Word=5-bit
//----------------------------------------------------------------------------

/*************************************************************************************************************************
*   THEORY OF OPERATION:                                                                                                 *
*   - HIT:  requested word stored in the cache, data at that address propages to output after a single clock edge        *
*   - MISS: requested word is not stored in the cache, cache controller FSM moves blocks between main mem and cache mem  *
*************************************************************************************************************************/

module rjh_cache_4w 
#(
parameter data_width          = 128 , // architecture width
parameter address_width       = 13 , // note that it is shortened to speed compilation
parameter word_addr_width     = 2  , // word field width
parameter group_addr_width    = 2  , // group field width
parameter tag_addr_width      = 9   // tag field width, note that it is shortened to speed compilation
)
(
input                          Clock       ,
input                          Resetn      ,
input                          WR          ,
input      [address_width-1:0] MEM_address , // To speedup synthesis and simulation only 12K are being instantiated
input      [data_width-1   :0] MEM_in      ,
output     [data_width-1   :0] MEM_out     ,
output reg                     Done          // Means READ or WRITE ACCESS is complete, i.e. the output is valid during a READ, and done updating location during a WRITE
);

integer i; // Used in "for" loops -> loops must be written for synthesis tool to unroll
genvar  j; // Used in "generate for" loops -> unrolled guarenteed by synthesis tool

localparam set_addr_width = 2; // 2 bit for 4-way set associativity (2^2 = 4)

// Machine Main States
localparam IDLE       = 2'd0 ; // Expected state for "HIT"
localparam FETCH      = 2'd1 ; // Fetch new block
localparam WRITEBACK  = 2'd2 ; // Write back dirty block
// Machine Sub States
localparam FETCH0     = 2'd0 ;
localparam FETCH1     = 2'd1 ;
localparam FETCH2     = 2'd2 ;
localparam FETCH3     = 2'd3 ;
localparam WRITEBACK0 = 2'd0 ;
localparam WRITEBACK1 = 2'd1 ;
localparam WRITEBACK2 = 2'd2 ;
localparam WRITEBACK3 = 2'd3 ;

// Internal Wires
wire cam_hit;
wire [2**set_addr_width-1   : 0] set_hit                  ; // set pointed to by CAM hit
wire [set_addr_width-1      : 0] set_hit_search [2**set_addr_width-1 : 0] ; // intermediate signals for linear search
wire [set_addr_width-1      : 0] set_hit_encoded          ; // set_hit is 1-hot, this is normal binary
wire [2**group_addr_width-1 : 0] CAM_Out [2**set_addr_width-1 : 0] ; // one hot encoded CAM results
wire [set_addr_width-1      : 0] set_control              ; // set controlled for writeback/fetch
wire [tag_addr_width-1      : 0] tag                      ; // tag component of address
wire [tag_addr_width-1      : 0] tag_replace [2**set_addr_width-1 : 0]; // tag stored in group of CAM
wire [group_addr_width-1    : 0] group                    ; // group component of address
wire [word_addr_width-1     : 0] word                     ; // word component of address
wire [address_width-1       : 0] main_address             ; // Main memory inst address
wire [data_width-1          : 0] main_q                   ; // main memory inst data out
wire [set_addr_width+group_addr_width+word_addr_width-1:0] cache_address ; // cache mem inst address
wire [data_width-1          : 0] cache_data               ; // cache mem inst data out
wire                             cache_wren               ; // cache mem inst write enable



// State Machine Controlled Signals
reg [1:0]                                        Cache_Controller_State                ;
reg [1:0]                                        Fetch_State                           ;
reg [1:0]                                        Writeback_State                       ;
reg [word_addr_width-1     : 0]                  mm_word_cnt                           ; // used to iterate across words in a block for the main mem
reg [word_addr_width-1     : 0]                  cm_word_cnt                           ; // used to iterate across words in a block for the cache
reg [set_addr_width-1      : 0]                  set_replace [2**group_addr_width-1:0] ; // Set to replace -> need to keep track of this for each group
reg [2**(group_addr_width+set_addr_width)-1 : 0] dirty_bit                             ; // used to track when a block in the cache is written to
reg                                              writeback                             ; // control signal for multiplexors from fsm
reg                                              fetch                                 ; // control signal for multiplexors from fsm
reg                                              cam_wr0,cam_wr1,cam_wr2,cam_wr3       ; // CAM write enable										;


// A "Content Addressable Memory" is used to store the TAG of the blocks stored in the cache
    // Remember, the tags are stored at the group that aligns with the stored block
rjh_CAM_sv 
#(
    .addr_width    ( group_addr_width),
    .data_width    ( tag_addr_width                    ) 
) cam0 (
    .Clock         ( Clock                   ), // input  // Used for syncronous write
    .Resetn        ( Resetn                  ), // input  // Syncronous reset
    .WR            ( cam_wr0                  ), // input  // Write-Enable
    .Write_Addr    ( group     					), // input  // "{Set,Group}" to write incoming "TAG" to
    .Data_In       ( tag                     ), // input  // "TAG" to check for stored in CAM
    .Hit           ( /* Unused */             ), // output // Was "TAG" found in CAM? Not useful since we need group association
    .CAM_Out       ( CAM_Out[0]                 ), // output // "{Set,Group}" where tag was found -> encoded in white hot
    .ADDR_Out      ( tag_replace[0]             )  // output // "TAG" stored at "{Set,Group}"
);
rjh_CAM_sv 
#(
    .addr_width    ( group_addr_width),
    .data_width    ( tag_addr_width                    ) 
) cam1 (
    .Clock         ( Clock                   ), // input  // Used for syncronous write
    .Resetn        ( Resetn                  ), // input  // Syncronous reset
    .WR            ( cam_wr1                  ), // input  // Write-Enable
    .Write_Addr    ( group     					), // input  // "{Set,Group}" to write incoming "TAG" to
    .Data_In       ( tag                     ), // input  // "TAG" to check for stored in CAM
    .Hit           ( /* Unused */            ), // output // Was "TAG" found in CAM? Not useful since we need group association
    .CAM_Out       ( CAM_Out[1]                 ), // output // "{Set,Group}" where tag was found -> encoded in white hot
    .ADDR_Out      ( tag_replace[1]             )  // output // "TAG" stored at "{Set,Group}"
);
rjh_CAM_sv 
#(
    .addr_width    ( group_addr_width),
    .data_width    ( tag_addr_width                    ) 
) cam2 (
    .Clock         ( Clock                  ), // input  // Used for syncronous write
    .Resetn        ( Resetn                  ), // input  // Syncronous reset
    .WR            ( cam_wr2                  ), // input  // Write-Enable
    .Write_Addr    ( group     					), // input  // "{Set,Group}" to write incoming "TAG" to
    .Data_In       ( tag                     ), // input  // "TAG" to check for stored in CAM
    .Hit           ( /* Unused */         	), // output // Was "TAG" found in CAM? Not useful since we need group association
    .CAM_Out       ( CAM_Out[2]                 ), // output // "{Set,Group}" where tag was found -> encoded in white hot
    .ADDR_Out      ( tag_replace[2]             )  // output // "TAG" stored at "{Set,Group}"
);
rjh_CAM_sv 
#(
    .addr_width    ( group_addr_width),
    .data_width    ( tag_addr_width                    ) 
) cam3 (
    .Clock         ( Clock                  ), // input  // Used for syncronous write
    .Resetn        ( Resetn                  ), // input  // Syncronous reset
    .WR            ( cam_wr3                  ), // input  // Write-Enable
    .Write_Addr    ( group     					), // input  // "{Set,Group}" to write incoming "TAG" to
    .Data_In       ( tag                     ), // input  // "TAG" to check for stored in CAM
    .Hit           ( /* Unused */             ), // output // Was "TAG" found in CAM? Not useful since we need group association
    .CAM_Out       ( CAM_Out[3]                 ), // output // "{Set,Group}" where tag was found -> encoded in white hot
    .ADDR_Out      ( tag_replace[3]             )  // output // "TAG" stored at "{Set,Group}"
);



// Now check to see if tag was found in CAM at group, and if so which set
generate // Using a generate block to create a priority encoder, which will produce a binary from a 1-hot
	 for (j=0; j<(2**set_addr_width); j=j+1) begin : set_hit_seperate
        assign set_hit[j]         = CAM_Out[j][group] ; // This line generates a warning in quartus which is invalid, due to masking off of MSBs for small values of "j"
    end
    assign set_hit_search [0] = {set_addr_width{1'd0}};
	 
    for (j=1; j<(2**set_addr_width); j=j+1) begin : set_hit_encoder
        assign set_hit_search [j] = (set_hit[j]) ? j[set_addr_width-1:0] : set_hit_search[j-1] ;
    end
    assign set_hit_encoded = set_hit_search[2**set_addr_width-1];
endgenerate

assign cam_hit          = |set_hit                ;
assign {tag,group,word} = MEM_address             ;
assign set_control      = set_replace[group]      ;


// "Main Memory" implemented as a RAM
GPU_main_mem main_mem (
    .address       ( main_address  ), // input
    .clock         ( Clock         ), // input
    .data          ( MEM_out       ), // input
    .wren          ( writeback     ), // input
    .q             ( main_q        )  // output
);

// "Cache Memory" implemented as a RAM
rjh_cache_v cache_mem (
    .address       ( cache_address ), // input
    .clock         ( Clock         ), // input
    .data          ( cache_data    ), // input
    .wren          ( cache_wren    ), // input
    .q             ( MEM_out       )  // output
);

// Cache Mem Signal Multiplexing
assign cache_address = (~fetch & ~writeback & cam_hit) ? {set_hit_encoded,group,word} : {set_control,group,cm_word_cnt} ;
assign cache_data    = (~fetch & ~writeback & cam_hit) ? MEM_in                  : main_q                          ;
assign cache_wren    = (~fetch & ~writeback & cam_hit) ? WR                      : fetch                           ;

// Main Mem Signal Multiplexing

assign main_address  = (cam_wr0|cam_wr1|cam_wr2|cam_wr3) ? {tag,group,mm_word_cnt} : {tag_replace[set_replace[group]],group,mm_word_cnt}; // Using CAM output for tag selection

// Cache Controller FSM moves blocks between main mem and cache mem
always @(posedge Clock) begin : Cache_Controller
    if(!Resetn) begin // active low reset
        Cache_Controller_State = IDLE;
        Writeback_State        = WRITEBACK0;
        Fetch_State            = FETCH0;
        Done                   = 1'd0;
        writeback              = 1'd0;
        fetch                  = 1'd0;
        cam_wr0                = 1'd0;
		  cam_wr1                = 1'd0;
		  cam_wr2                = 1'd0;
		  cam_wr3                = 1'd0;
        mm_word_cnt            = {word_addr_width {1'd0}};
        cm_word_cnt            = {word_addr_width {1'd0}};
        dirty_bit              = {(set_addr_width+group_addr_width){1'd0}};
        for(i=0; i<2**group_addr_width; i=i+1) begin
            set_replace[i] = {set_addr_width{1'd0}};
        end
    end
    else begin // reset
        case (Cache_Controller_State)
            IDLE: begin
                fetch       = 1'd0;
                writeback   = 1'd0;
                mm_word_cnt = {word_addr_width{1'd0}};
                cm_word_cnt = {word_addr_width{1'd0}};
                if(!cam_hit) begin // TAG is not stored in CAM -> MISS
                    Done = 1'd0; // STALL CPU
                    if(dirty_bit[{set_control,group}]) begin
                        Cache_Controller_State = WRITEBACK;
                    end
                    else begin
                        Cache_Controller_State = FETCH;
                    end
                end
                else begin // -> HIT
                    Done = 1'd1; // CPU execution continues
                    if(WR) begin
                        dirty_bit[{set_hit_encoded,group}] = 1'd1;
                    end
                end
            end
            WRITEBACK: begin
                // During writeback a block is moved from cache memory to main memory 1 word at a time
                // Memories evaluate inputs on positive clock edge -> need source address 1 word ahead of dest
                    // This allows for 1 cycle per word
                    // Main Memory write enable should not be high until output of Cache Mem is valid -> 1 cycle startup delay
                case (Writeback_State)
                    WRITEBACK0: begin // First cycle of writeback, reset dirty bit
                        Writeback_State = WRITEBACK1;
                        dirty_bit[{set_control,group}] = 1'd0;
                    end
                    WRITEBACK1: begin // Second cycle of writeback, word 0 is ready from source
                        Writeback_State = WRITEBACK2;
                        cm_word_cnt = cm_word_cnt + 1'd1;
                        writeback = 1'd1;
                    end
                    WRITEBACK2: begin // transfer words 1 through end of block
                        mm_word_cnt = mm_word_cnt + 1'd1;
                        cm_word_cnt = cm_word_cnt + 1'd1;
                        if(~|cm_word_cnt) begin
                            Writeback_State = WRITEBACK3;
                        end
                    end
                    WRITEBACK3: begin // finished writeback
                        Writeback_State = WRITEBACK0; // for next writeback operation
                        Cache_Controller_State = FETCH; // proceed to fetch new block
                        writeback = 1'd0;
                        mm_word_cnt = mm_word_cnt + 1'd1;
                    end
                endcase // Writeback_State
            end // WRITEBACK
            FETCH: begin
                // During fetch a block is moved from main memory to cache memory 1 word at a time
                // Memories evaluate inputs on positive clock edge -> need source address 1 word ahead of dest
                    // This allows for 1 cycle per word
                    // Cache Memory write enable should not be high until output of Main Mem is valid -> 1 cycle startup delay
                case (Fetch_State)
                    FETCH0: begin // First Fetch cycle, write new tag to CAM and request word zero of block from main mem
                        Fetch_State = FETCH1;
								case (set_replace[group])
								2'd0: cam_wr0 = 1'd1;
								2'd1: cam_wr1 = 1'd1;
								2'd2: cam_wr2 = 1'd1;
								2'd3: cam_wr3 = 1'd1;
								endcase
                    end
                    FETCH1: begin // Word zero output of main mem is ready, begin writing to cache mem
                        cam_wr0 = 1'd0;
								cam_wr1 = 1'd0;
								cam_wr2 = 1'd0;
								cam_wr3 = 1'd0;
                        Fetch_State = FETCH2;
                        mm_word_cnt = mm_word_cnt + 1'd1;
                        fetch = 1'd1;
                    end
                    FETCH2: begin // Write words 1 through end of block to cache
                        mm_word_cnt = mm_word_cnt + 1'd1;
                        cm_word_cnt = cm_word_cnt + 1'd1;
                        if(~|mm_word_cnt)begin // all words have been fetched from main memory
                            Fetch_State = FETCH3;
                        end
                    end
                    FETCH3: begin
                        Fetch_State = FETCH0; // for next fetch operation
                        Cache_Controller_State = IDLE; // Fetch operation is complete
                        fetch = 1'd0;
                        set_replace[group] = set_replace[group] + 1'd1; // next time replace the next set
                    end
                endcase // Fetch_State
            end // FETCH
        endcase // Cache_Controller_State
    end // else reset
end // Cache_Controller
endmodule
