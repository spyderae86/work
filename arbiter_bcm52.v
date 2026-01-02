//-----------------------------------------------------------------
//      module
//      test.com
//      Copyright 2025-2026
//      BSD
//-----------------------------------------------------------------
module DW_ahb_dmac_bcm52 (
    clk,
    rst_n,
    init_n,
    enable,
    request,
    prior,
    lock,
    mask,
    parked,
    granted,
    locked,
    grant,
    grant_index
);

parameter integer N                = 4; // RANGE 2 to 32
parameter integer PARK_MODE        = 1; // RANGE 0 or 1
parameter integer PARK_INDEX       = 0; // RANGE 0 to (N - 1)
parameter integer OUTPUT_MODE      = 1; // RANGE 0 or 1
parameter integer INDEX_WIDTH      = 2; // RANGE 1 to 5
parameter integer REAL_INDEX_WIDTH = 3; // RANGE 2 to 6

// spyglass disable_block ParamWidthMismatch-ML
// SMD: Parameter width does not match with the value assigned
// SJ: The legal value of RHS parameter cannot exceed the range that the LHS parameter can represent. Even though there is a width mismatch, no information is lost in the assignment.
localparam [INDEX_WIDTH-1:0] INITIAL_GRANT_INDEX = (PARK_MODE==0)? -1 : PARK_INDEX;
localparam [N-1:0]           INITIAL_GRANT       = (PARK_MODE==0)? 0 : (1 << PARK_INDEX);
// spyglass enable_block ParamWidthMismatch-ML

input                    clk;        // Clock input
input                    rst_n;      // active low reset
input                    init_n;     // active low reset
input                    enable;     // active high register enable
input  [N-1:0]            request;   // client request bus
input  [INDEX_WIDTH*N-1:0] prior;    // client priority bus
input  [N-1:0]            lock;       // client lock bus
input  [N-1:0]            mask;       // client mask bus

output                   parked;     // arbiter parked status flag
output                   granted;    // arbiter granted status flag
output                   locked;     // arbiter locked status flag
output [N-1:0]            grant;      // one-hot client grant bus
output [INDEX_WIDTH-1:0]  grant_index;// index of current granted client


// spyglass disable_block ParamWidthMismatch-ML
// SMD: Parameter width does not match with the value assigned
// SJ: The legal value of RHS parameter cannot exceed the range that the LHS parameter can represent. Even though there is a width mismatch, no information is lost in the assignment.
localparam [REAL_INDEX_WIDTH-1 : 0] MAXP1_PRIORITY = (N == (1 << INDEX_WIDTH)) ?
                                                   N : ((1 << INDEX_WIDTH) -1);

// spyglass enable_block ParamWidthMismatch-ML

reg  [N-1:0] next_grant;
reg  [INDEX_WIDTH-1:0] next_grant_index;
wire next_parked, next_granted, next_locked;

reg  [N-1:0] grant_int;
reg  [INDEX_WIDTH-1:0] grant_index_int;
reg  granted_int;

wire [N-1:0] masked_req;

wire [N-1:0] temp_gnt;

reg  [(N*REAL_INDEX_WIDTH)-1:0] priority_vec;

reg  [N*REAL_INDEX_WIDTH-1:0] muxed_pri_vec;

wire [INDEX_WIDTH-1:0] current_index;

wire [REAL_INDEX_WIDTH-1:0] priority_value;



assign masked_req = request & (~mask);

assign next_locked = granted_int & (|(grant_int & lock));

assign next_granted = next_locked | (|masked_req);

assign next_parked = ~next_granted;

always @(prior or masked_req) begin : reorder_input_PROC
  integer i1, j1;
  for (i1=0 ; i1<N ; i1=i1+1) begin
    for (j1=0 ; j1<REAL_INDEX_WIDTH ; j1=j1+1) begin
      // spyglass disable_block SelfDeterminedExpr-ML
      // SMD: Self determined expression found
      // SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
      // spyglass disable_block W528
      // SMD: A signal or variable is set but never read
      // SJ: Based on component configuration, this(these) signal(s) or parts of it will not be used to compute the final result.
      priority_vec[i1*REAL_INDEX_WIDTH+j1] = (j1 == INDEX_WIDTH) ?
                                             1'b0 : prior[i1*INDEX_WIDTH+j1];
      // spyglass enable_block W528
      muxed_pri_vec[i1*REAL_INDEX_WIDTH+j1] = (masked_req[i1]) ?
                                              ((j1 == INDEX_WIDTH) ? 1'b0 : prior[i1*INDEX_WIDTH+j1]) : MAXP1_PRIORITY[j1];
      // spyglass enable_block SelfDeterminedExpr-ML
    end
  end
end

// Find the index of the client with the highest priority active request
DW_ahb_dmac_bcm01
  #(REAL_INDEX_WIDTH, N, INDEX_WIDTH) U_minmax (
      .a(muxed_pri_vec),
      .tc(1'b0),
      .min_max(1'b0),
      // spyglass disable_block W528
      // SMD: A signal or variable is set but never read
      // SJ: Based on component configuration, this(these) signal(s) or parts of it will not be used to compute the final result.
      .value(priority_value),
      // spyglass enable_block W528
      .index(current_index) );

// Decode the index determined by minmax into one-hot select line
function automatic [N-1:0] func_decode;
  input [INDEX_WIDTH-1:0] f_a;  // input
  reg   [(1 << INDEX_WIDTH)-1:0] f_z;
  begin
    f_z = {1 << INDEX_WIDTH{1'b0}};
    f_z[f_a] = 1'b1;
    func_decode = f_z[N-1:0];
  end
endfunction

assign temp_gnt = func_decode( current_index );

always @(next_parked or next_locked or grant_int or temp_gnt) begin : mk_nxt_gr_PROC
  case ({next_parked, next_locked})
    2'b00: next_grant = temp_gnt;
    2'b01: next_grant = grant_int;
    2'b10: next_grant = INITIAL_GRANT;
    default: next_grant = grant_int;
  endcase
end

// spyglass disable_block W415a
// SMD: Signal may be multiply assigned (beside initialization) in the same scope
// SJ: The design checked and verified that not any one of a single bit of the bus is assigned more than once beside initialization or the multiple assignments are intentional.
// Encode the selects grant into grant_index for output
localparam [INDEX_WIDTH-1:0] INDEX_WIDTH_SIZED_ONE = 1;

always @( next_grant ) begin : mk_grant_index_PROC
  integer i;
  reg [INDEX_WIDTH-1:0] tmp_enc;

  next_grant_index = {INDEX_WIDTH{1'b1}};
  tmp_enc = {INDEX_WIDTH{1'b0}};

  for (i=0 ; i < N ; i=i+1) begin
    if (next_grant[i] == 1'b1) begin
      next_grant_index = next_grant_index & tmp_enc;
    end
    tmp_enc = tmp_enc + INDEX_WIDTH_SIZED_ONE;
  end
end
// spyglass enable_block W415a

always @(posedge clk or negedge rst_n) begin : regs_PROC
  if (rst_n == 1'b0) begin
    granted_int          <= 1'b0;
    grant_index_int      <= INITIAL_GRANT_INDEX;
    grant_int            <= INITIAL_GRANT;
  end else if (init_n == 1'b0) begin
    granted_int          <= 1'b0;
    grant_index_int      <= INITIAL_GRANT_INDEX;
    grant_int            <= INITIAL_GRANT;
  end else if (enable) begin
    grant_index_int      <= next_grant_index;
    granted_int          <= next_granted;
    grant_int            <= next_grant;
  end
end

generate if ((OUTPUT_MODE == 0) && (PARK_MODE == 0))
  begin : GEN_OM_EQ_0_PM_EQ_0
    assign grant      = ((next_locked==1'b0)? next_grant : grant_int) & 
                        {N{init_n}};
    assign grant_index = ((next_locked==1'b0)? next_grant_index : grant_index_int) |
                         {INDEX_WIDTH{~init_n}};
    assign granted    = ((next_locked==1'b0)? next_granted : granted_int) & init_n;
    assign locked     = next_locked & init_n;
  end else if ((OUTPUT_MODE == 0) && (PARK_MODE != 0)) begin : GEN_OM_EQ_0_PM_NE_0
    assign grant      = (init_n == 1'b1)? ((next_locked==1'b0)? next_grant : grant_int) :
                        INITIAL_GRANT;
    assign grant_index = (init_n == 1'b1)? ((next_locked==1'b0)? next_grant_index : grant_index_int) :
                        INITIAL_GRANT_INDEX;
    assign granted    = ((next_locked==1'b0)? next_granted : granted_int) & init_n;
    assign locked     = next_locked & init_n;
  end else begin : GEN_OM_NE_0
    reg  locked_int;

    always @(posedge clk or negedge rst_n) begin : locked_int_PROC
      if (rst_n == 1'b0) begin
        locked_int <= 1'b0;
      end else if (init_n == 1'b0) begin
        locked_int <= 1'b0;
      end else if (enable) begin
        locked_int <= next_locked;
      end
    end

    assign grant       = grant_int;
    assign grant_index = grant_index_int;
    assign granted     = granted_int;
    assign locked      = locked_int;
  end
endgenerate

generate
  if (PARK_MODE == 0) begin : GEN_PM_EQ_0
    assign parked = 1'b0;
  end else if (OUTPUT_MODE == 0) begin : GEN_PM_NE_0_OM_EQ_0
    reg  parked_int;

    always @(posedge clk or negedge rst_n) begin : parked_int_PROC
      if (rst_n == 1'b0) begin
        parked_int <= 1'b1;
      end else if (init_n == 1'b0) begin
        parked_int <= 1'b1;
      end else if (enable) begin
        parked_int <= next_parked;
      end
    end

    assign parked = ((next_locked==1'b0)? next_parked : parked_int) | (~init_n);
  end else begin : GEN_PM_NE_0_OM_NE_0
    reg  parked_int;

    always @(posedge clk or negedge rst_n) begin : parked_int_reg_PROC
      if (rst_n == 1'b0) begin
        parked_int <= 1'b1;
      end else if (init_n == 1'b0) begin
        parked_int <= 1'b1;
      end else if (enable) begin
        parked_int <= next_parked;
      end
    end

    assign parked = parked_int;
  end
endgenerate

endmodule