//-----------------------------------------------------------------
//      module
//      test.com
//      Copyright 2025-2026
//      BSD
//-----------------------------------------------------------------

module DW_ahb_dmac_arb_mask (
    // Inputs
    hclk,
    hresetn,
    hready,
    ch_prior,
    lock_ch_int_comb,
    lock_ch_l_int_comb,
    clr_mask_lck,
    clr_mask_lck_on_can_dfc,
    grant_mi,
    src_is_mem,
    dst_is_mem,
    dma_data_req,
    //lock_b_m,
    tfr_req,
    dp_grt_align_m,
    split_retry,
    ch_enable,
    suspend,
    fifo_empty,
    can_goto_amba_m,
    //GH 9000047152
    // incomp_trans_beats,
    last_tfr,
    clr_lock_error,
    //---

    // Outputs
    mask_prior0_mi,
    mask_prior1_mi,
    mask_prior2_mi,
    mask_prior3_mi,
    mask_prior4_mi,
    mask_prior5_mi,
    mask_prior6_mi,
    mask_prior7_mi,
    mask_lck_ch,
    mask_lck_ch_en,
    ch_disabled_mask,
    // GH 9000047152
    lock_split_retry,
    //---
    can_goto_amba_m_no_susp
);


parameter DMAH_LOCK_EN = 0;
parameter DMAH_NON_OK_EN_M = 0;
//GH 9000047152
parameter DMAH_MAX_BURST_LENGTH = 4;
//---

input                             hclk;
input                             hresetn;
input  [3*`DMAH_NUM_CHANNELS-1:0]  ch_prior;

input                             hready;

input                             lock_ch_int_comb; // Internal lock channel enable from lock_clr block.
input                             clr_mask_lck; // From lock_clr block to clear arbiter masking.
input                             clr_mask_lck_on_can_dfc; // Special case of above.
input  [`DMAH_NUM_PER-1:0]        grant_mi; // from arbiter

input                             lock_ch_l_int_comb;

input  [`DMAH_NUM_CHANNELS-1:0]   src_is_mem;
input  [`DMAH_NUM_CHANNELS-1:0]   dst_is_mem;
input  [`DMAH_NUM_PER-1:0]        dma_data_req;

//input                             lock_b_m;
input                             tfr_req;

input  [`DMAH_NUM_PER-1:0]        dp_grt_align_m;

input                             split_retry;
input  [`DMAH_NUM_CHANNELS-1:0]   ch_enable;
input  [`DMAH_NUM_CHANNELS-1:0]   suspend;
input  [`DMAH_NUM_CHANNELS-1:0]   fifo_empty;
//GH 9000047152
// input [DMAH_MAX_BURST_LENGTH:0] incomp_trans_beats;
input                             last_tfr;
input                             clr_lock_error;
//---

input                             can_goto_amba_m;

// Mask input bus's to each arbiter. Each
// priority level has it's own arbiter.

output [`DMAH_NUM_PER-1:0]        mask_lck_ch;
output [`DMAH_NUM_PER-1:0]        mask_prior0_mi;
output [`DMAH_NUM_PER-1:0]        mask_prior1_mi;
output [`DMAH_NUM_PER-1:0]        mask_prior2_mi;
output [`DMAH_NUM_PER-1:0]        mask_prior3_mi;
output [`DMAH_NUM_PER-1:0]        mask_prior4_mi;
output [`DMAH_NUM_PER-1:0]        mask_prior5_mi;
output [`DMAH_NUM_PER-1:0]        mask_prior6_mi;
output [`DMAH_NUM_PER-1:0]        mask_prior7_mi;

output                            mask_lck_ch_en;

// GH 9000047152
output                            lock_split_retry;
//---

output                            ch_disabled_mask;

output                            can_goto_amba_m_no_susp;

// mask_prior0_mi[0] = channel 0 src, asserted if ch0 priority = 0
// mask_prior0_mi[1] = channel 0 destination, asserted if ch0 priority = 0
// mask_prior0_mi[2] = channel 1 src, asserted if ch1 priority = 0
// mask_prior0_mi[3] = channel 1 dest, asserted if ch1 priority = 0
// --
// mask_prior5_mi[14] = channel 7 source, asserted if ch7 priority = 5

reg [`DMAH_NUM_PER-1:0]           hc_mask_lck_ch;
wire                              lock_split_retry;

reg [`DMAH_NUM_PER-1:0]           hc_mask_lck_ch_d;
reg [`DMAH_NUM_PER-1:0]           mask_p0_mi_int;
reg [`DMAH_NUM_PER-1:0]           mask_p1_mi_int;
reg [`DMAH_NUM_PER-1:0]           mask_p2_mi_int;
reg [`DMAH_NUM_PER-1:0]           mask_p3_mi_int;
reg [`DMAH_NUM_PER-1:0]           mask_p4_mi_int;
reg [`DMAH_NUM_PER-1:0]           mask_p5_mi_int;
reg [`DMAH_NUM_PER-1:0]           mask_p6_mi_int;
reg [`DMAH_NUM_PER-1:0]           mask_p7_mi_int;

reg [`DMAH_NUM_CHANNELS-1:0]      ch_enable_reg;

reg                               hc_lock_split_retry;
//reg [`DMAH_NUM_PER-1:0]         ch_enable_int_fed;
reg  [`DMAH_NUM_PER-1:0]          ch_enable_int_reg;
reg  [`DMAH_NUM_PER-1:0]          suspend_int;
reg  [`DMAH_NUM_PER-1:0]          fifo_empty_int;

reg                               hc_mask_clr_hr;
reg                               hc_mask_clr_hreg_reg;
reg                               hc_mask_lck_ch_en_lock_reg;

wire                              mask_lck_ch_en_lock;
wire                              mask_lck_ch_en_lock_reg;
wire                              mask_clr_hreg_reg;
wire                              mask_clr_hr;
wire [`DMAH_NUM_PER-1:0]          mask_lck_ch;
wire [`DMAH_NUM_PER-1:0]          mask_lck_ch_d;
wire                              mask_clr_hreg_pre;
wire                              mask_clr_hreg;
wire                              ch_disabled_mask;

wire [`DMAH_NUM_PER-1:0]          mask_lck_ch_pre_s;
wire [`DMAH_NUM_PER-1:0]          mask_lck_ch_pre_d;

wire [`DMAH_NUM_CHANNELS-1:0]     ch_enable_fed;

wire                              mask_clr_pre;
wire                              mask_lck_ch_en;

//GH 9000047152
//wire [DMAH_MAX_BURST_LENGTH:0]    incomp_trans_beats;
wire                              incomp_trans;

reg [`DMAH_NUM_PER-1:0]           per_is_mem;

integer                           k;
//spyglass disable_block SelfDeterminedExpr-ML
//SMD: Self determined expression present in the design.
//SJ: This Self Determined Expression is as per the design requirement.
//    There will not be any functional issue.
//spyglass disable_block W528
//SMD : A signal or variable is set but never read.
//SJ : The DW_ahb_dmac is a highly configurable IP, due to this in certain
//    configuration few signals are driven, but may not be read.
//    But there will not be any functional issue.
// For the three tier arbitration scheme instantiate
// one instance of a fcfs arbiter for each priority level
//=> associated with each fcfs instance is a priority
// level. If a req is not assigned a priority level then
// mask off the request to the corresponding fcfs instance
// associated with that priority level.



always @(ch_prior)
begin : mask_p0_mi_int_PROC
    integer i;
    mask_p0_mi_int[0] = !(ch_prior[2:0] == 3'b000);
    mask_p0_mi_int[1] = !(ch_prior[2:0] == 3'b000);
    for (i = 3; i < `DMAH_NUM_PER; i = i + 2)
    begin
        mask_p0_mi_int[i] = !((`DMAH_NUM_CHANNELS > ((i-1)/2)) &&
                              ({ch_prior[3*((i-1)/2) + 2],
                               ch_prior[3*((i-1)/2) + 1],
                               ch_prior[3*((i-1)/2)]} == 3'b000));
    end
    for (i = 2; i < `DMAH_NUM_PER; i = i + 2)
    begin
        mask_p0_mi_int[i] = !((`DMAH_NUM_CHANNELS > (i/2)) &&
                              ({ch_prior[3*(i/2) + 2],
                               ch_prior[3*(i/2) + 1],
                               ch_prior[3*(i/2)]} == 3'b000));
    end
end

always @(ch_prior)
begin : mask_p1_mi_int_PROC
    integer i;
    mask_p1_mi_int[0] = !(ch_prior[2:0] == 3'b001);
    mask_p1_mi_int[1] = !(ch_prior[2:0] == 3'b001);
    for (i = 3; i < `DMAH_NUM_PER; i = i + 2)
    begin
        mask_p1_mi_int[i] = !((`DMAH_NUM_CHANNELS > ((i-1)/2)) &&
                              ({ch_prior[3*((i-1)/2) + 2],
                               ch_prior[3*((i-1)/2) + 1],
                               ch_prior[3*((i-1)/2)]} == 3'b001));
    end
    for (i = 2; i < `DMAH_NUM_PER; i = i + 2)
    begin
        mask_p1_mi_int[i] = !((`DMAH_NUM_CHANNELS > (i/2)) &&
                              ({ch_prior[3*(i/2) + 2],
                               ch_prior[3*(i/2) + 1],
                               ch_prior[3*(i/2)]} == 3'b001));
    end
end

always @(ch_prior)
begin : mask_p2_mi_int_PROC
    integer i;
    mask_p2_mi_int[0] = !(ch_prior[2:0] == 3'b010);
    mask_p2_mi_int[1] = !(ch_prior[2:0] == 3'b010);
    for (i = 3; i < `DMAH_NUM_PER; i = i + 2)
    begin
        mask_p2_mi_int[i] = !((`DMAH_NUM_CHANNELS > ((i-1)/2)) &&
                              ({ch_prior[3*((i-1)/2) + 2],
                               ch_prior[3*((i-1)/2) + 1],
                               ch_prior[3*((i-1)/2)]} == 3'b010));
    end
    for (i = 2; i < `DMAH_NUM_PER; i = i + 2)
    begin
        mask_p2_mi_int[i] = !((`DMAH_NUM_CHANNELS > (i/2)) &&
                              ({ch_prior[3*(i/2) + 2],
                               ch_prior[3*(i/2) + 1],
                               ch_prior[3*(i/2)]} == 3'b010));
    end
end

always @(ch_prior)
begin : mask_p3_mi_int_PROC
    integer i;
    mask_p3_mi_int[0] = !(ch_prior[2:0] == 3'b011);
    mask_p3_mi_int[1] = !(ch_prior[2:0] == 3'b011);
    for (i = 3; i < `DMAH_NUM_PER; i = i + 2)
    begin
        mask_p3_mi_int[i] = !((`DMAH_NUM_CHANNELS > ((i-1)/2)) &&
                              ({ch_prior[3*((i-1)/2) + 2],
                               ch_prior[3*((i-1)/2) + 1],
                               ch_prior[3*((i-1)/2)]} == 3'b011));
    end
    for (i = 2; i < `DMAH_NUM_PER; i = i + 2)
    begin
        mask_p3_mi_int[i] = !((`DMAH_NUM_CHANNELS > (i/2)) &&
                              ({ch_prior[3*(i/2) + 2],
                               ch_prior[3*(i/2) + 1],
                               ch_prior[3*(i/2)]} == 3'b011));
    end
end

always @(ch_prior)
begin : mask_p4_mi_int_PROC
    integer i;
    mask_p4_mi_int[0] = !(ch_prior[2:0] == 3'b100);
    mask_p4_mi_int[1] = !(ch_prior[2:0] == 3'b100);
    for (i = 3; i < `DMAH_NUM_PER; i = i + 2)
    begin
        mask_p4_mi_int[i] = !((`DMAH_NUM_CHANNELS > ((i-1)/2)) &&
                              ({ch_prior[3*((i-1)/2) + 2],
                               ch_prior[3*((i-1)/2) + 1],
                               ch_prior[3*((i-1)/2)]} == 3'b100));
    end
    for (i = 2; i < `DMAH_NUM_PER; i = i + 2)
    begin
        mask_p4_mi_int[i] = !((`DMAH_NUM_CHANNELS > (i/2)) &&
                              ({ch_prior[3*(i/2) + 2],
                               ch_prior[3*(i/2) + 1],
                               ch_prior[3*(i/2)]} == 3'b100));
    end
end

always @(ch_prior)
begin : mask_p5_mi_int_PROC
    integer i;
    mask_p5_mi_int[0] = !(ch_prior[2:0] == 3'b101);
    mask_p5_mi_int[1] = !(ch_prior[2:0] == 3'b101);
    for (i = 3; i < `DMAH_NUM_PER; i = i + 2)
    begin
        mask_p5_mi_int[i] = !((`DMAH_NUM_CHANNELS > ((i-1)/2)) &&
                              ({ch_prior[3*((i-1)/2) + 2],
                               ch_prior[3*((i-1)/2) + 1],
                               ch_prior[3*((i-1)/2)]} == 3'b101));
    end
    for (i = 2; i < `DMAH_NUM_PER; i = i + 2)
    begin
        mask_p5_mi_int[i] = !((`DMAH_NUM_CHANNELS > (i/2)) &&
                              ({ch_prior[3*(i/2) + 2],
                               ch_prior[3*(i/2) + 1],
                               ch_prior[3*(i/2)]} == 3'b101));
    end
end

always @(ch_prior)
begin : mask_p6_mi_int_PROC
    integer i;
    mask_p6_mi_int[0] = !(ch_prior[2:0] == 3'b110);
    mask_p6_mi_int[1] = !(ch_prior[2:0] == 3'b110);
    for (i = 3; i < `DMAH_NUM_PER; i = i + 2)
    begin
        mask_p6_mi_int[i] = !((`DMAH_NUM_CHANNELS > ((i-1)/2)) &&
                              ({ch_prior[3*((i-1)/2) + 2],
                               ch_prior[3*((i-1)/2) + 1],
                               ch_prior[3*((i-1)/2)]} == 3'b110));
    end
    for (i = 2; i < `DMAH_NUM_PER; i = i + 2)
    begin
        mask_p6_mi_int[i] = !((`DMAH_NUM_CHANNELS > (i/2)) &&
                              ({ch_prior[3*(i/2) + 2],
                               ch_prior[3*(i/2) + 1],
                               ch_prior[3*(i/2)]} == 3'b110));
    end
end

always @(ch_prior)
begin : mask_p7_mi_int_PROC
    integer i;
    mask_p7_mi_int[0] = !(ch_prior[2:0] == 3'b111);
    mask_p7_mi_int[1] = !(ch_prior[2:0] == 3'b111);
    for (i = 3; i < `DMAH_NUM_PER; i = i + 2)
    begin
        mask_p7_mi_int[i] = !((`DMAH_NUM_CHANNELS > ((i-1)/2)) &&
                              ({ch_prior[3*((i-1)/2) + 2],
                               ch_prior[3*((i-1)/2) + 1],
                               ch_prior[3*((i-1)/2)]} == 3'b111));
    end
    for (i = 2; i < `DMAH_NUM_PER; i = i + 2)
    begin
        mask_p7_mi_int[i] = !((`DMAH_NUM_CHANNELS > (i/2)) &&
                              ({ch_prior[3*(i/2) + 2],
                               ch_prior[3*(i/2) + 1],
                               ch_prior[3*(i/2)]} == 3'b111));
    end
end

//spyglass enable_block W528
//spyglass enable_block SelfDeterminedExpr-ML

assign mask_prior0_mi = mask_p0_mi_int[`DMAH_NUM_PER-1:0] & mask_lck_ch;
assign mask_prior1_mi = mask_p1_mi_int[`DMAH_NUM_PER-1:0] & mask_lck_ch ;
assign mask_prior2_mi = {(`DMAH_NUM_PER){1'b0}};
assign mask_prior3_mi = {(`DMAH_NUM_PER){1'b0}};
assign mask_prior4_mi = {(`DMAH_NUM_PER){1'b0}};
assign mask_prior5_mi = {(`DMAH_NUM_PER){1'b0}};
assign mask_prior6_mi = {(`DMAH_NUM_PER){1'b0}};
assign mask_prior7_mi = {(`DMAH_NUM_PER){1'b0}};



// If bus locking is enabled on a layer and the bus locking
// level is higher than the AMBA transfer level then channel
// locking must be enabled at least up do that level.
// i.e. channel reg value of lock_ch may be overwritten.

// ch_lck_lev decoding
// 00 => AMBA transfer level
// 01 => transaction level
// 10 => block level
// 11 => dma transfer level

// Mask out all channel requests ( except req of currently
// granted s/m and it's corresponding channel s/m ) when
// lock_ch_l_m is asserted. lock_ch_int is generated from
// lock_ch_l_m ( from ch to master mux) which is the registered
// version of lock_ch, registered on tfr_req when s/m is granted.
// Once a s/m which requests channel arbiter locking is granted
// the master interface then all other requests are masked out
// ( bar the current and opposing s/m if src and dst of channel on same layer)
// until the clr_mask_lck signal is pulsed, which will occur at the
// end of a transaction,block or dma transfer of the channel in question.

// If peripheral is memory then locking at the transaction
// level is ignored.

// For AMBA and Transaction level locking then locking only
// asserted while transferring DMA data and not during
// status writeback or LLI fetch. dma_data_req asserted when
// transfer DMA data.

// Align per_is_mem the same as grant_mi.
// i.e. (dst channel 7 src channel 7 ...... 
//      dst channel 1 src channel 1 dst channel 0 src channel 0 )

always @(src_is_mem or dst_is_mem)
begin : per_is_mem_PROC
    integer i;
    for (i=0; i < `DMAH_NUM_CHANNELS ; i = i +1)
        {per_is_mem[2*i + 1],per_is_mem[2*i]} = {dst_is_mem[i],src_is_mem[i]};
end

// Corner case Known issue
// If Block level locking is enabled and the block complete signal
// asserts at the same time as a tfr_req, then hlock_clr is masked out to
// prevent a protocol violation that states hlock must be asserted
// 1 cycle before the address phase.
// The result is that the lock is maintained past the end of the block
// until either the next block completes or the transaction completes.
// This will prevent another master getting access between blocks and will
// reduce performance but is not a protocol bug.

assign mask_clr_pre = (!((|(grant_mi & per_is_mem)) && (lock_ch_l_int_comb == 1'b1)))
                     && (|(grant_mi & dma_data_req));

assign mask_lck_ch_en = tfr_req && mask_clr_pre;

// Note AMBA bus level locking was removed 1/12/2002. Left
// code in as line :
// if(mask_lck_ch_en && lock_b_m) // Only bus level AMBA locking
// will never be executed. Will effect coverage figures
// but allows easy modification of code to re-enable
// AMBA bus level locking feature

// If get split/retry during transaction/block or transfer locking
// then still need to mask out channel's other peripheral.

// mask_clr_hreg is pulsed for a single cycle on the first
// data phase after a tfr_req when hready high. i.e. first data phase
// belonging to the tfr_req. clr_mask_lck can be co-incident with this
// pulse only for transaction locking or the following corner case: If get
// error response then channel is disabled. The falling edge of channel disable
// generates a pulse used to clear mask_lck_ch_d. In this case don't mask
// out clr_mask_lck with mask_clr_hreg.

//spyglass disable_block FlopEConst
//SMD: Enable bit tied to 1/0
//SJ: In configurations where locking is not enabled lock_ch_int_comb is tied to 0
//spyglass disable_block W415a
//SMD: Signal may be multiply assigned (beside initialization) in the same scope
//SJ: This multiple assignments are intentional and are as per the design requirement.
//    There will not be any functional issue.
//spyglass disable_block W528
//SMD : A signal or variable is set but never read.
//SJ : The DW_ahb_dmac is a highly configurable IP, due to this in certain
//    configuration few signals are driven, but may not be read.
//    But there will not be any functional issue.

always @(posedge hclk or negedge hresetn)
begin : mask_lck_ch_PROC
  if(hresetn == 1'b0)
  begin
    hc_mask_lck_ch_d <= {(`DMAH_NUM_PER){1'b0}};
    hc_mask_lck_ch   <= {(`DMAH_NUM_PER){1'b0}};
    hc_lock_split_retry <= 1'b0;
  end
  else if(split_retry && (!lock_split_retry) && (!clr_lock_error))
  begin
    hc_mask_lck_ch_d <= mask_lck_ch;
    hc_mask_lck_ch   <= ~dp_grt_align_m;
    hc_lock_split_retry <= 1'b1;
  end
  else if(lock_split_retry && (!tfr_req) && (!clr_lock_error))
  begin
    hc_mask_lck_ch_d <= mask_lck_ch_d;
    hc_mask_lck_ch   <= mask_lck_ch;
    hc_lock_split_retry <= lock_split_retry;
  end

  // GH 9000047152
  // For defined length burst we must keep the channel locked
  // until the interrupted transfer is complete
  // else if(lock_split_retry && (incomp_trans_beats > 1))
  else if(lock_split_retry && (!last_tfr) && (!clr_lock_error))
  begin
    hc_mask_lck_ch_d <= mask_lck_ch_d;
    hc_mask_lck_ch   <= mask_lck_ch;
    hc_lock_split_retry <= lock_split_retry;
  end

  //---
  else if(lock_split_retry && (!clr_lock_error))
  begin
    hc_mask_lck_ch   <= mask_lck_ch_d;
    hc_mask_lck_ch_d <= {(`DMAH_NUM_PER){1'b0}};
    hc_lock_split_retry <= 1'b0;
  end
  else if((clr_mask_lck && (!mask_lck_ch_en_lock) && (!mask_lck_ch_en_lock_reg) &&
           (!(mask_clr_hreg && (!ch_disabled_mask)))) ||
            clr_mask_lck_on_can_dfc)
  begin
    hc_mask_lck_ch   <= {(`DMAH_NUM_PER){1'b0}};
    hc_mask_lck_ch_d <= {(`DMAH_NUM_PER){1'b0}};
    hc_lock_split_retry <= 1'b0;
  end
  else if(mask_lck_ch != {(`DMAH_NUM_PER){1'b0}})
  begin
    hc_mask_lck_ch   <= mask_lck_ch;
    hc_mask_lck_ch_d <= mask_lck_ch;
    hc_lock_split_retry <= lock_split_retry;
  end
  else if(mask_lck_ch_en && lock_ch_int_comb)
  begin
    hc_lock_split_retry <= 1'b0;
    hc_mask_lck_ch_d <= mask_lck_ch;
    // spyglass disable_block STARC05-2.1.4.5
    // SMD: Use bit-wise operator instead of logical operator
    // SJ: The DW_ahb_dmac design is high configurable. In order
    //     to support such configurability logical operator is used.
    //     But there is no functionality issue. Hence it can be waived.
    // spyglass disable_block STARC05-2.10.2.3
    // SMD: Do not perform logical negation on vectors.
    // SJ: The DW_ahb_dmac design is high configurable. In order
    //     to support such configurability logical negation on vectors is done.
    //     But there is no functionality issue. Hence it can be waived.
    //     signal the assignment value will not be stable. Because the order of
    //     assignment does not take care.
    for(k=0;k<`DMAH_NUM_PER;k=k+1)
    begin
      if(grant_mi[k] && ((k%2)==0))   // src granted
        hc_mask_lck_ch <= (~((grant_mi << 1) | grant_mi))
                           & {`DMAH_NUM_PER{lock_ch_int_comb}};
      else if(grant_mi[k])            // dst granted
        hc_mask_lck_ch <= (~((grant_mi >> 1) | grant_mi))
                           & {`DMAH_NUM_PER{lock_ch_int_comb}};
    end
    // spyglass enable_block STARC05-2.10.2.3
    // spyglass enable_block STARC05-2.1.4.5
  end
  else
  begin
    hc_mask_lck_ch   <= mask_lck_ch;
    hc_mask_lck_ch_d <= mask_lck_ch_d;
    hc_lock_split_retry <= lock_split_retry;
  end
end

// spyglass enable_block W528
// spyglass enable_block W415a
// spyglass enable_block FlopEConst


generate
    if (((DMAH_LOCK_EN == 0) && (DMAH_NON_OK_EN_M == 0)) && (`DMAH_INCR_BURSTS == 1))
    begin : am1
        assign mask_lck_ch       = {(`DMAH_NUM_PER){1'b0}};
        assign lock_split_retry  = 1'b0;
        assign mask_lck_ch_d     = {(`DMAH_NUM_PER){1'b0}};
    end
    else
    begin : am2
        assign mask_lck_ch       = hc_mask_lck_ch;
        assign lock_split_retry  = hc_lock_split_retry;
        assign mask_lck_ch_d     = hc_mask_lck_ch_d;
    end
endgenerate

//************************************************************//

// Clear arbiter and bus locking when a channel is disabled
// The masking will not be cleared when
// 1. Channel is disabled over slave interface ( After suspending )
// 2. An error response is received.

always @(posedge hclk or negedge hresetn)
begin : ch_enable_reg_PROC
    if(hresetn == 1'b0)
        ch_enable_reg <= {(`DMAH_NUM_CHANNELS){1'b0}};
    else
        ch_enable_reg <= ch_enable;
end

always @(ch_enable_reg)
begin : ch_enable_int_reg_PROC
    integer i;
    for(i=0; i < `DMAH_NUM_CHANNELS ; i = i +1)
        {ch_enable_int_reg[2*i + 1],ch_enable_int_reg[2*i]} = {ch_enable_reg[i],ch_enable_reg[i]};
end

always @(suspend)
begin : suspend_int_PROC
    integer i;
    for(i=0; i < `DMAH_NUM_CHANNELS ; i = i +1)
        {suspend_int[2*i + 1],suspend_int[2*i]} = {suspend[i],suspend[i]};
end

//spyglass disable_block W528
//SMD : A signal or variable is set but never read
//SJ : The DW_ahb_dmac is a highly configurable IP, due to this in certain
//     configuration few signals are driven, but may not be read.
//     But there will not be any functional issue.

always @(fifo_empty)
begin : fifo_empty_PROC
    integer i;
    for(i=0; i < `DMAH_NUM_CHANNELS ; i = i +1)
        {fifo_empty_int[2*i + 1],fifo_empty_int[2*i]} = {fifo_empty[i],fifo_empty[i]};
end
//spyglass enable_block W528

// Special case when DMAH_NUM_CHANNELS == 1.
// If 3 channel device and
//     a. Channel 1 locks arbiter => mask_lck_ch = 110011
//     b. No channel locks arbiter => mask_lck_ch = 000000
// For single channel devices then mask_lck_ch = 00 if
// channel 0 locks the arbiter or not.

// Bug if remove locking when FIFO empty and suspended if the
// suspended channel is re-enabled. Wait for the channel to be
// disabled before removing the arbiter locking.

//assign ch_disabled_mask = ((|mask_lck_ch) || (`DMAH_NUM_CHANNELS == 1)) &&  ((|((ch_enable_int_fed) & (~mask_lck_ch))) ||
//                           (|(suspend_int & fifo_empty_int & (~mask_lck_ch))));
						  
assign ch_disabled_mask = ((|mask_Lck_ch) || (`DMAH_NUM_CHANNELS == 1)) && ((|((~ch_enable_int_reg) & (~mask_lck_ch))));
						   

//************************************************************//

// For transaction level locking then transaction complete
// may occur after a new transaction has already started.
// i.e. src transaction completes then dst transaction starts.
// In this case don't clear mask_lck_ch. Generate mask_clr_hreg
// to mask off clearing of mask_lck_ch.

//spyglass disable_block W528
//SMD : A signal or variable is set but never read
//SJ : The DW_ahb_dmac is a highly configurable IP, due to this in certain
//     configuration few signals are driven, but may not be read.
//     But there will not be any functional issue.

always @(posedge hclk or negedge hresetn)
begin : hc_mask_clr_hr_PROC
    if(hresetn == 1'b0)
        hc_mask_clr_hr <= 1'b0;
    else
        if(hready)
            hc_mask_clr_hr <= mask_lck_ch_en && lock_ch_int_comb;
        else
            hc_mask_clr_hr <= mask_clr_hr;
end

generate
    if ( (DMAH_LOCK_EN == 0) && (DMAH_NON_OK_EN_M == 0) ) begin : am3
        assign mask_clr_hr = 1'b0;
    end
    else begin : am4
        assign mask_clr_hr = hc_mask_clr_hr;
    end
endgenerate

assign mask_clr_hreg_pre = mask_clr_hr && hready;

always @(posedge hclk or negedge hresetn)
begin : hc_mask_clr_hreg_reg_PROC
    if(hresetn == 1'b0)
        hc_mask_clr_hreg_reg <= 1'b0;
    else
        hc_mask_clr_hreg_reg <= mask_clr_hreg_pre;
end

assign mask_lck_ch_en_lock = mask_lck_ch_en && lock_ch_int_comb;

// STAR 184318 Fix Do not clear masking when mask_lck_ch_en_lock_reg asserted.

always @(posedge hclk or negedge hresetn)
begin : hc_mask_lck_ch_en_lock_reg_PROC
  if(hresetn == 1'b0)
    hc_mask_lck_ch_en_lock_reg <= 1'b0;
  else
    hc_mask_lck_ch_en_lock_reg <= mask_lck_ch_en_lock;
end

//spyglass enable_block W528

//spyglass disable_block W528
//SMD : A signal or variable is set but never read
//SJ  : The DW_ahb_dmac is a highly configurable IP, due to this in certain
//      configuration few signals are driven, but may not be read.
//      But there will not be any functional issue.
generate
  if ((DMAH_LOCK_EN == 0) && (DMAH_NON_OK_EN_M == 0))
  begin : am5
    assign mask_lck_ch_en_lock_reg = 1'b0;
    assign mask_clr_hreg_reg       = 1'b0;
  end
  else
  begin : am6
    assign mask_lck_ch_en_lock_reg = hc_mask_lck_ch_en_lock_reg;
    assign mask_clr_hreg_reg       = hc_mask_clr_hreg_reg;
  end
endgenerate

//spyglass enable_block W528

assign mask_clr_hreg = mask_clr_hreg_reg;


/**************************************************************/
// 1-09-2003
// Need to cancel goto_amba_state if req_sm is deasserted on same
// cycle as goto_amba_state asserted when req_sm_pre is
// registered. This can cause corner case.
//
// Consider following case:
//
// Channel 1 sms = Master 1
// Channel 1 dms = Master 2
// Channel 1 block level locking
//
// Channel 2 sms = Master 1
// Channel 2 dms = Master 2
// Channel 2 block level locking
//
// Say channel 1's source and destination block transfer has started => channel 1
// has locked master 1 and master 2.
// Now say that channel 1 is suspended the cycle before goto_amba_state. The timing
// is shown below.
//
//
// req_sm              _________|‾‾‾|________
//
//
// suspend_cfg         _________|‾‾‾‾‾‾‾‾‾‾‾‾‾
//
//
// goto_amba_state     _____________|‾‾|______
//
//
// cancel_goto_amba_state ____________|‾‾|______
//
// Then can goto_amba_m is pulsed which will cause pulse of clr_mask_lck in DW_ahb_dmac_lock_clr
// block. This will clear the locking of Master 1 by the source of channel 1. Now say channel 2 starts
// it's block transfer and locks master 1. After this channel 1 is re-enabled. Now channel 1 src
// cannot proceed because master interface locked by channel 2. Channel 2 dst cannot proceed because
// Master 2 locked by channel 1 dst. Deadlock.
//
// Need to mask can_goto_amba_m to DW_ahb_dmac_lock_clr block when caused by above timing.

assign can_goto_amba_m_no_susp = can_goto_amba_m && (!((|(suspend_int & 
                                   (~mask_lck_ch))) && (|mask_lck_ch)));
/**************************************************************/

endmodule
