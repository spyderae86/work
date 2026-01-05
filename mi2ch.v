//-----------------------------------------------------------------
//      module
//      test.com
//      Copyright 2025-2026
//      BSD
//-----------------------------------------------------------------
module DW_ahb_dmac_mi_to_ch_mux (

// Inputs
hclk,
hresetn,
grant_m1,
grant_m2,
grant_m3,
grant_m4,
tfr_req_pre,
hready,
end_addr_phase1,
end_addr_phase2,
haddr_reg,
hgrant_int,
hresp_int,
dp_complete,
hrdata_m1,
hrdata_m2,
hrdata_m3,
hrdata_m4,
pop,
pop_data_vld,
push,
ch_sms,
ch_dms_lms,
src_tfr_on_dst_sm,
mask_ch_disable_hlock,
// GH 9000047152
lock_split_retry,
ebt_event,

// Outputs
hgrant_src,
hgrant_dst,
hresp_int_src,
hresp_int_dst,
dp_complete_src,
dp_complete_dst,
hready_src,
hready_dst,
end_addr_ph1_src,
end_addr_ph1_dst,
end_addr_ph2_src,
end_addr_ph2_dst,
pop_ch,
pop_data_vld_ch,

push_ch,
hrdata_ch_ss,
hrdata_ll_ds,
haddr_src,
haddr_dst,
grant_align,
dp_grt_align,
dp_grt_align_m1,
dp_grt_align_m2,
dp_grt_align_m3,
dp_grt_align_m4,
// GH 9000047152
lock_split_retry_src,
lock_split_retry_dst,
ebt_event_src,
ebt_event_dst,
//----
mask_ch_disable_hlock_ch
);

// Local parameters
parameter HRDATA_CH_BW = (`DMAH_NUM_CHANNELS * `MAX_AHB_HDATA_WIDTH);
parameter HADDR_CH_DW = (`DMAH_HADDR_WIDTH * `DMAH_NUM_CHANNELS);

// Spyglass disable_block W240
//SMD: An input has been declared but is not read
//SJ: The DW_ahb_dmac is a highly configurable IP, due to this in certain
//    configuration this input port may not be used. But there will not be
//    any functional issue.
input [`DMAH_NUM_PER-1:0] grant_m1; // From master interface arbiter.
input [`DMAH_NUM_PER-1:0] grant_m2;
input [`DMAH_NUM_PER-1:0] grant_m3;
input [`DMAH_NUM_PER-1:0] grant_m4;
// Spyglass enable_block W240

// From central transfer control.
input [`DMAH_NUM_MASTER_INT-1:0] tfr_req_pre;

input [`DMAH_NUM_MASTER_INT-1:0] pop_data_vld;
input [`DMAH_NUM_MASTER_INT-1:0] push;
input [`DMAH_NUM_MASTER_INT-1:0] pop;
input [`DMAH_M1_HDATA_WIDTH-1:0] hrdata_m1;
input [`DMAH_M2_HDATA_WIDTH-1:0] hrdata_m2;
input [`DMAH_M3_HDATA_WIDTH-1:0] hrdata_m3;
input [`DMAH_M4_HDATA_WIDTH-1:0] hrdata_m4;


// From mbiu. Always asserted for AMBA Lite.
input [`DMAH_NUM_MASTER_INT-1:0] hgrant_int;
input [(2*`DMAH_NUM_MASTER_INT)-1:0] hresp_int;
input [`DMAH_NUM_MASTER_INT-1:0] dp_complete;
input [`DMAH_NUM_MASTER_INT-1:0] hready;
input [`DMAH_NUM_MASTER_INT-1:0] end_addr_phase1;
input [`DMAH_NUM_MASTER_INT-1:0] end_addr_phase2;
input [(`DMAH_NUM_MASTER_INT*`DMAH_HADDR_WIDTH)-1:0] haddr_reg;

// asserted when dst s/m is performing a src transfer.
// On LLI fetch.

input [`DMAH_NUM_CHANNELS-1:0] src_tfr_on_dst_sm;

// dst s/m ch_dms_lms

// Write Status and ctl -> Pop  -> external write -> dst s/m -> llpx.lms
// Dst DMA Data         -> Pop  -> external write -> dst s/m -> ctlx.dms
// Fetch LLI            -> Push -> external read  -> dst s/m -> llpx.lms
// Fetch DST Status     -> Push -> external read  -> dst s/m -> ctlx.dms

// src s/m ch_sms
// Src DMA data         -> Push -> external Read  -> src s/m -> ctlx.sms
// Fetch Src Status     -> Push -> external Read  -> src s/m -> ctlx.sms

// ch_sms is a concatenation of all channel ms bits ( master select )
// 2 bit bus's.
// ch_sms[1:0] = ctl0.sms[1:0]
// ch_sms[3:2] = ctl1.sms[1:0]
// ch_sms[5:4] = ctl2.sms[1:0]

// ch_sms comes directly from the memory mapped value.

input [(2*`DMAH_NUM_CHANNELS)-1:0] ch_sms;

// ch_dms_lms is a concatenation of all channel ms ( master select )
// 2 bit bus's.
// ch_dms_lms[1:0] = ch0_dms_lms[1:0]
// ch_dms_lms[3:2] = ch1_dms_lms[1:0]
// ch_dms_lms[5:4] = ch2_dms_lms[1:0]

// ch_dms_lms comes from the dst s/m and switches between ctlx.dms and
// llpx.lms.

input [(2*`DMAH_NUM_CHANNELS)-1:0] ch_dms_lms;

input [3:0] mask_ch_disable_hlock;

input hclk;
input hresetn;
//GH 9000047152
input [`DMAH_NUM_MASTER_INT-1:0] lock_split_retry;
input [`DMAH_NUM_MASTER_INT-1:0] ebt_event;

//----
output [`DMAH_NUM_CHANNELS-1:0] lock_split_retry_src;
output [`DMAH_NUM_CHANNELS-1:0] lock_split_retry_dst;
output [`DMAH_NUM_CHANNELS-1:0] ebt_event_src;
output [`DMAH_NUM_CHANNELS-1:0] ebt_event_dst;
//----
output [`DMAH_NUM_CHANNELS-1:0] hgrant_src;
output [`DMAH_NUM_CHANNELS-1:0] hgrant_dst;
output [(2*`DMAH_NUM_CHANNELS)-1:0] hresp_int_src;
output [(2*`DMAH_NUM_CHANNELS)-1:0] hresp_int_dst;
output [`DMAH_NUM_CHANNELS-1:0] dp_complete_src;
output [`DMAH_NUM_CHANNELS-1:0] dp_complete_dst;
output [`DMAH_NUM_CHANNELS-1:0] hready_src;
output [`DMAH_NUM_CHANNELS-1:0] hready_dst;
output [`DMAH_NUM_CHANNELS-1:0] end_addr_ph1_src;
output [`DMAH_NUM_CHANNELS-1:0] end_addr_ph1_dst;
output [`DMAH_NUM_CHANNELS-1:0] end_addr_ph2_src;
output [`DMAH_NUM_CHANNELS-1:0] end_addr_ph2_dst;

// hrdata_ch_ss goes to channel fifo and should be used
// to update sstat register in the channel memory block
// when sstat_upd is pulsed. Concatenated externally.

output [HRDATA_CH_BW-1:0] hrdata_ch_ss;

// hrdata_ll_ds is used to update sar,dar,llp,ctl
// registers when a lli is updated. Registers are updated on following pulses
// sar_lw_upd, sar_uw_upd, dar_lw_upd,
// dar_uw_upd,llp_lw_upd,llp_uw_upd,ctl_lw_upd,
// hrdata_ll_ds is also used to update the dstat register when dstat_upd is
// pulsed. Concatenated externally.

output [`HRDATA_CH_BW-1:0] hrdata_ll_ds;

output [`DMAH_NUM_CHANNELS-1:0] pop_ch;
output [`DMAH_NUM_CHANNELS-1:0] pop_data_vld_ch;
output [`DMAH_NUM_CHANNELS-1:0] push_ch;
output [HADDR_CH_DW-1:0] haddr_src; // concatenated externally
output [HADDR_CH_DW-1:0] haddr_dst; // concatenated externally

//To channel to master mux

output [(`DMAH_NUM_MASTER_INT*`DMAH_NUM_PER)-1:0] grant_align;
output [(`DMAH_NUM_MASTER_INT*`DMAH_NUM_PER)-1:0] dp_grt_align;
output [`DMAH_NUM_PER-1:0] dp_grt_align_m1;
output [`DMAH_NUM_PER-1:0] dp_grt_align_m2;
output [`DMAH_NUM_PER-1:0] dp_grt_align_m3;
output [`DMAH_NUM_PER-1:0] dp_grt_align_m4;

output [7:0] mask_ch_disable_hlock_ch;

wire [(4*`DMAH_NUM_PER)-1:0] grant_align_int;
wire [(`DMAH_NUM_MASTER_INT*`DMAH_NUM_PER)-1:0] grant_align;
wire [(`DMAH_NUM_MASTER_INT*`DMAH_NUM_PER)-1:0] dp_grt_align;

reg [`DMAH_NUM_CHANNELS-1:0] hgrant_src;
reg [`DMAH_NUM_CHANNELS-1:0] hgrant_dst;
reg [(2*`DMAH_NUM_CHANNELS)-1:0] hresp_int_src;
reg [(2*`DMAH_NUM_CHANNELS)-1:0] hresp_int_dst;
reg [`DMAH_NUM_CHANNELS-1:0] dp_complete_src;
reg [`DMAH_NUM_CHANNELS-1:0] dp_complete_dst;
reg [`DMAH_NUM_CHANNELS-1:0] hready_src;
reg [`DMAH_NUM_CHANNELS-1:0] hready_dst;

reg [7:0] mask_ch_disable_hlock_ch_src;
reg [7:0] mask_ch_disable_hlock_ch_dst;
wire [7:0] mask_ch_disable_hlock_ch;

reg [`DMAH_NUM_CHANNELS-1:0] pop_ch;
reg [`DMAH_NUM_CHANNELS-1:0] pop_data_vld_ch;
reg [`DMAH_NUM_CHANNELS-1:0] push_ch;

reg [HADDR_CH_DW-1:0] haddr_src;
reg [HADDR_CH_DW-1:0] haddr_dst;

reg [HRDATA_CH_BW-1:0] hrdata_ch_ss;
reg [HRDATA_CH_BW-1:0] hrdata_ll_ds;

reg [`MAX_AHB_HDATA_WIDTH-1:0] hrdata_m1_int;
reg [`MAX_AHB_HDATA_WIDTH-1:0] hrdata_m2_int;
reg [`MAX_AHB_HDATA_WIDTH-1:0] hrdata_m3_int;
reg [`MAX_AHB_HDATA_WIDTH-1:0] hrdata_m4_int;

reg [`DMAH_NUM_PER-1:0] grant_align_m1;
reg [`DMAH_NUM_PER-1:0] dp_grt_align_m1;
reg [`DMAH_NUM_PER-1:0] grant_align_m2;
reg [`DMAH_NUM_PER-1:0] dp_grt_align_m2;
reg [`DMAH_NUM_PER-1:0] grant_align_m3;
reg [`DMAH_NUM_PER-1:0] dp_grt_align_m3;
reg [`DMAH_NUM_PER-1:0] grant_align_m4;
reg [`DMAH_NUM_PER-1:0] dp_grt_align_m4;


reg [`DMAH_NUM_CHANNELS-1:0] end_addr_ph1_src;
reg [`DMAH_NUM_CHANNELS-1:0] end_addr_ph1_dst;
reg [`DMAH_NUM_CHANNELS-1:0] end_addr_ph2_src;
reg [`DMAH_NUM_CHANNELS-1:0] end_addr_ph2_dst;

wire [(4*`MAX_AHB_HDATA_WIDTH)-1:0] hrdata_int;

reg [3:0] tfr_req_int;
reg [3:0] hready_int;

wire [(4*`DMAH_NUM_PER)-1:0] dp_grt_align_all;
wire [(4*`DMAH_NUM_PER)-1:0] grt_align_all ;

wire [`DMAH_NUM_MASTER_INT-1:0] tfr_req;

// GH 9000047152
reg [`DMAH_NUM_CHANNELS-1:0] lock_split_retry_src;
reg [`DMAH_NUM_CHANNELS-1:0] lock_split_retry_dst;
reg [`DMAH_NUM_CHANNELS-1:0] ebt_event_src;
reg [`DMAH_NUM_CHANNELS-1:0] ebt_event_dst;

//---
// To improve critical timing gating of tfr_req with hready is has been moved from central_tfr_ctl
// to here.

assign tfr_req = tfr_req_pre & hready;

// Steer control signals from each master interface
// to all channel src and destination s/m's depending
// on which master interface the source or destination
// channel s/m's are assigned to as indicated by ch_sms.

// hgrant_src is a bus with a bit assigned to each src
// state machine.
// hgrant_src[0] -> channel 0 source s/m
// |
// |
// hgrant_src[7] -> channel 7 source s/m

// Note that ch_sms is a concatenation of each channel's
// source master select.
// ch_sms = {push7_ms[1:0],push6_ms[1:0]....push0_ms[1:0]}

// Note that similar steering is done for other control signals
// as done for hgrant_src.

//spyglass disable_block SelfDeterminedExpr-ML
//SMD: Self determined expression present in the design.
//SJ: This Self Determined Expression is as per the design requirement.
//    There will not be any functional issue.
//spyglass disable_block W415a
//SMD: Signal may be multiply assigned (beside initialization) in the same scope
//SJ: This multiple assignments are intentional and are as per the design requirement.

// There will not be any functional issue.
//spyglass enable_block SelfDeterminedExpr-ML

always @( *)
begin : hgrant_src_PROC
  integer i;
  integer j;
  hgrant_src = {(`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      hgrant_src[i] = hgrant_src[i] | ( hgrant_int[j] &
                                        ({ch_sms[2*i+1],ch_sms[2*i]} == j) );
end

// hgrant_dst is a bus with a bit assigned to each destination
// state machine.
// hgrant_dst[0] -> channel 0 source s/m
// |
// hgrant_dst[7] -> channel 7 source s/m

always @( *)
begin : hgrant_dst_PROC
  integer i;
  integer j;
  hgrant_dst = {(`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      hgrant_dst[i] = hgrant_dst[i] | ( hgrant_int[j] &
                                        ({ch_dms_lms[2*i+1],ch_dms_lms[2*i]} == j) );
end

always @( *)
begin : hresp_int_src_PROC
  integer i;
  integer j;
  integer k;
  hresp_int_src = {(2*`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      for(k=0; k < 2; k = k + 1)
        hresp_int_src[2*i+k] = hresp_int_src[2*i+k] | ( hresp_int[2*j+k] &
                                                       ({ch_sms[2*i+1],ch_sms[2*i]} == j) );
end

always @( *)
begin : hresp_int_dst_PROC
  integer i;
  integer j;
  integer k;
  hresp_int_dst = {(2*`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      for(k=0; k < 2; k = k + 1)
        hresp_int_dst[2*i+k] = hresp_int_dst[2*i+k] | ( hresp_int[2*j+k] &
                                                       ({ch_dms_lms[2*i+1],ch_dms_lms[2*i]} == j) );
end

// dp_complete asserted for single cycle on same cycle as
// last data phase of requested transfer when hready is high.

always @( *)
begin : dp_complete_src_PROC
  integer i;
  integer j;
  dp_complete_src = {(`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      dp_complete_src[i] = dp_complete_src[i] | ( dp_complete[j] &
                                                 ({ch_sms[2*i+1],ch_sms[2*i]} == j) );
end

always @( *)
begin : dp_complete_dst_PROC
  integer i;
  integer j;
  dp_complete_dst = {(`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      dp_complete_dst[i] = dp_complete_dst[i] | ( dp_complete[j] &
                                                 ({ch_dms_lms[2*i+1],ch_dms_lms[2*i]} == j) );
end

always @( *)
begin : end_addr_ph1_src_PROC
  integer i;
  integer j;
  end_addr_ph1_src = {(`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      end_addr_ph1_src[i] = end_addr_ph1_src[i] | ( end_addr_phase1[j] &
                                                   ({ch_sms[2*i+1],ch_sms[2*i]} == j ));
end

always @( *)
begin : end_addr_ph1_dst_PROC
  integer i;
  integer j;
  end_addr_ph1_dst = {(`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      end_addr_ph1_dst[i] = end_addr_ph1_dst[i] | ( end_addr_phase1[j] &
                                                   ({ch_dms_lms[2*i+1],ch_dms_lms[2*i]} == j) );
end

always @( *)
begin : end_addr_ph2_src_PROC
  integer i;
  integer j;
  end_addr_ph2_src = {(`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      end_addr_ph2_src[i] = end_addr_ph2_src[i] | ( end_addr_phase2[j] &
                                                   ({ch_sms[2*i+1],ch_sms[2*i]} == j) );
end

always @( *)
begin : end_addr_ph2_dst_PROC
  integer i;
  integer j;
  end_addr_ph2_dst = {(`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      end_addr_ph2_dst[i] = end_addr_ph2_dst[i] | ( end_addr_phase2[j] &
                                                   ({ch_dms_lms[2*i+1],ch_dms_lms[2*i]} == j ));
end

always @( *)
begin : hready_src_PROC
  integer i;
  integer j;
  hready_src = {(`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      hready_src[i] = hready_src[i] | ( hready[j] &
                                        ({ch_sms[2*i+1],ch_sms[2*i]} == j) );
end

always @( *)
begin : hready_dst_PROC
  integer i;
  integer j;
  hready_dst = {(`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      hready_dst[i] = hready_dst[i] | ( hready[j] &
                                        ({ch_dms_lms[2*i+1],ch_dms_lms[2*i]} == j) );
end

// GH 9000047152
always @( *)
begin : lock_split_retry_src_PROC
  integer i;
  integer j;
  lock_split_retry_src = {(`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      lock_split_retry_src[i] = lock_split_retry_src[i] | ( lock_split_retry[j] &
                                                           ({ch_sms[2*i+1],ch_sms[2*i]} == j) );
end

always @(*)
begin : lock_split_retry_dst_PROC
  integer i;
  integer j;
  lock_split_retry_dst = {(`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      lock_split_retry_dst[i] = lock_split_retry_dst[i] | ( lock_split_retry[j] &
                                                           ({ch_dms_lms[2*i+1],ch_dms_lms[2*i]} == j) );
end

always @(*)
begin : ebt_event_src_PROC
  integer i;
  integer j;
  ebt_event_src = {(`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      ebt_event_src[i] = ebt_event_src[i] | ( ebt_event[j] &
                                              ({ch_sms[2*i+1],ch_sms[2*i]} == j) );
end

always @(*)
begin : ebt_event_dst_PROC
  integer i;
  integer j;
  ebt_event_dst = {(`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      ebt_event_dst[i] = ebt_event_dst[i] | ( ebt_event[j] &
                                              ({ch_dms_lms[2*i+1],ch_dms_lms[2*i]} == j) );
end

//spyglass enable_block W415a
//spyglass enable_block SelfDeterminedExpr-ML

//-----

//spyglass disable_block W415a
//SMD: Signal may be multiply assigned (beside initialization) in the same scope
//SJ: This multiple assignments are intentional and are as per the design requirement.
//    There will not be any functional issue.

always @(*)
begin : hrdata_m1_int_PROC
  hrdata_m1_int = {(`MAX_AHB_HDATA_WIDTH){1'b0}};
  hrdata_m1_int[`DMAH_M1_HDATA_WIDTH-1:0] = hrdata_m1;
end

always @(*)
begin : hrdata_m2_int_PROC
  hrdata_m2_int = {(`MAX_AHB_HDATA_WIDTH){1'b0}};
  hrdata_m2_int[`DMAH_M2_HDATA_WIDTH-1:0] = hrdata_m2;
end

always @(*)
begin : hrdata_m3_int_PROC
  hrdata_m3_int = {(`MAX_AHB_HDATA_WIDTH){1'b0}};
  hrdata_m3_int[`DMAH_M3_HDATA_WIDTH-1:0] = hrdata_m3;
end

always @(*)
begin : hrdata_m4_int_PROC
  hrdata_m4_int = {(`MAX_AHB_HDATA_WIDTH){1'b0}};
  hrdata_m4_int[`DMAH_M4_HDATA_WIDTH-1:0] = hrdata_m4;
end

//spyglass enable_block W415a

assign hrdata_int = {hrdata_m4_int,hrdata_m3_int,hrdata_m2_int,hrdata_m1_int};

//spyglass disable_block SelfDeterminedExpr-ML
//SMD: Self determined expression present in the design.
//SJ: This Self Determined Expression is as per the design requirement.
//    There will not be any functional issue.
//spyglass disable_block W415a
//SMD: Signal may be multiply assigned (beside initialization) in the same scope
//SJ: This multiple assignments are intentional and are as per the design requirement.
//    There will not be any functional issue.
// Channel DMA read data and source status read returned on this
// bus.

always @(*)
begin : hrdata_ch_ss_PROC
  integer i;
  integer j;
  integer k;
  hrdata_ch_ss = {(`MAX_AHB_HDATA_WIDTH*`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      for(k=0; k < `MAX_AHB_HDATA_WIDTH; k = k + 1)
        hrdata_ch_ss[`MAX_AHB_HDATA_WIDTH*i+k] =
          hrdata_ch_ss[`MAX_AHB_HDATA_WIDTH*i+k] |
          ( hrdata_int[`MAX_AHB_HDATA_WIDTH*j+k] &
            ({ch_sms[2*i+1],ch_sms[2*i]} == j) );
end

//----------------------------------------------------------
// Linked list item read and destination status read returned on this
// bus. May be on a different AMBA layer to channel DMA data
// and source status and hence different read back bus to hrdata_ch_ss

always @(*)
begin : hrdata_ll_ds_PROC
  integer i;
  integer j;
  integer k;
  hrdata_ll_ds = {(`MAX_AHB_HDATA_WIDTH*`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      for(k=0; k < `MAX_AHB_HDATA_WIDTH; k = k + 1)
        hrdata_ll_ds[`MAX_AHB_HDATA_WIDTH*i+k] =
          hrdata_ll_ds[`MAX_AHB_HDATA_WIDTH*i+k] |
          ( hrdata_int[`MAX_AHB_HDATA_WIDTH*j+k] &
            ({ch_dms_lms[2*i+1],ch_dms_lms[2*i]} == j) );
end

//----------------------------------------------------------
// haddr goes to channel reg block to update the sar and dar registers
// with the current address for that channel DMA transfer. Channel reg
// block sar updated on a push_ch command on the dar register
// is updated on a pop_data_vld_ch command. (i.e. when the data phase
// completes with an O.K. hresp )

always @(*)
begin : haddr_src_PROC
  integer i;
  integer j;
  integer k;
  haddr_src = {(`DMAH_HADDR_WIDTH*`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      for(k=0; k < `DMAH_HADDR_WIDTH; k = k + 1)
        haddr_src[`DMAH_HADDR_WIDTH*i+k] =
          haddr_src[`DMAH_HADDR_WIDTH*i+k] |
          ( haddr_reg[`DMAH_HADDR_WIDTH*j+k] &
            ({ch_sms[2*i+1],ch_sms[2*i]} == j) );
end

always @(*)
begin : haddr_dst_PROC
  integer i;
  integer j;
  integer k;
  haddr_dst = {(`DMAH_HADDR_WIDTH*`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      for(k=0; k < `DMAH_HADDR_WIDTH; k = k + 1)
        haddr_dst[`DMAH_HADDR_WIDTH*i+k] =
          haddr_dst[`DMAH_HADDR_WIDTH*i+k] |
          ( haddr_reg[`DMAH_HADDR_WIDTH*j+k] &
            ({ch_dms_lms[2*i+1],ch_dms_lms[2*i]} == j) );
end

// The arbiter updates ( after been externally registered, external to
// DW_arbiter_fcfs), on the same cycle as the first address phase of
// the current transfer. It then indicates the granted request after
// the current transfer has completed.

// Aligned versions of the grant,granted and grant_index are
// generated in the arbiter which are aligned to the current transfer.

// grant_align_m4 is aligned to the address phase of the current transfer.
// dp_grant_align_m4 is aligned to the data phase of the current transfer.

// Pop data from a channel on the address phase of a transfer when
// hready is high ( previous data phase complete) and when the
// channel is currently granted the master bus interface.

assign grt_align_all = {grant_align_m4,grant_align_m3,grant_align_m2,grant_align_m1};

always @(*)
begin : pop_ch_PROC
  integer i;
  integer j;
  pop_ch = {(`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      pop_ch[i] = (pop_ch[i] | ( (pop[j] &
                                 ({ch_dms_lms[2*i+1],ch_dms_lms[2*i]} == j))) & grt_align_all[(j*`DMAH_NUM_PER)+2*i + 1] );
end

// pop_data_vld_n_ch is valid on the data phase of a transfer. Steer
// to a channel s/m when the data phase of a transfer is
// currently granted to that channel.

assign dp_grt_align_all = {dp_grt_align_m4,dp_grt_align_m3,dp_grt_align_m2,dp_grt_align_m1};
assign dp_grt_align = dp_grt_align_all[(`DMAH_NUM_MASTER_INT*`DMAH_NUM_PER)-1:0];

always @(*)
begin : pop_data_vld_ch_PROC
  integer i;
  integer j;
  pop_data_vld_ch = {(`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      pop_data_vld_ch[i] = pop_data_vld_ch[i] | ( ((pop_data_vld[j] &
                                                   ({ch_dms_lms[2*i+1],ch_dms_lms[2*i]} == j))) & dp_grt_align_all[(j*`DMAH_NUM_PER)+2*i + 1] );
end

// Push data onto a channel on the data phase of a transfer when
// hready is high ( data phase complete) and when the
// channel is currently granted the master bus interface.

// Dst also used to do source transfers when fetching next LLI. It such
// a case the dst is granted while pushing the next LLI.

always @(*)
begin : push_ch_PROC
  integer i;
  integer j;
  push_ch = {(`DMAH_NUM_CHANNELS){1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      if(src_tfr_on_dst_sm[i])
        push_ch[i] = (push_ch[i] | ( (push[j] &
                                     ({ch_sms[2*i+1],ch_sms[2*i]} == j))) & dp_grt_align_all[(j*`DMAH_NUM_PER) + 2*i + 1] );
      else
        push_ch[i] = (push_ch[i] | ( (push[j] &
                                     ({ch_sms[2*i+1],ch_sms[2*i]} == j))) & dp_grt_align_all[(j*`DMAH_NUM_PER) + 2*i] );
end

//spyglass enable_block W415a
//spyglass enable_block SelfDeterminedExpr-ML

// Arbiter updates grant_m on cycle after tfr_req_int goes low ( tfr_req_int is
// a single pulse)
// Align grant_m to address phase of current transfer on AHB bus
// Align grant_m to data phase of current transfer on AHB bus

//spyglass disable_block W415a
//SMD: Signal may be multiply assigned (beside initialization) in the same scope
//SJ: This multiple assignments are intentional and are as per the design requirement.
//    There will not be any functional issue.

always @(*)
begin : tfr_req_int_PROC
  tfr_req_int = 4'h0;
  tfr_req_int[`DMAH_NUM_MASTER_INT-1:0] = tfr_req;
end

always @(*)
begin : hready_int_PROC
  hready_int = 4'h0;
  hready_int[`DMAH_NUM_MASTER_INT-1:0] = hready;
end

//spyglass enable_block W415a

always @(posedge hclk or negedge hresetn)
begin : grant_align_m1_PROC
  if(hresetn == 1'b0)
    grant_align_m1 <= { (`DMAH_NUM_PER){1'b0} };
  else
    if(tfr_req_int[0])
      grant_align_m1 <= grant_m1;
end

always @(posedge hclk or negedge hresetn)
begin : dp_grant_m1_PROC
  if(hresetn == 1'b0)
    dp_grt_align_m1 <= { (`DMAH_NUM_PER){1'b0} };
  else
    if(hready_int[0])
      dp_grt_align_m1 <= grant_align_m1;
end

always @(posedge hclk or negedge hresetn)
begin : grant_align_m2_PROC
  if(hresetn == 1'b0)
    grant_align_m2 <= { (`DMAH_NUM_PER){1'b0} };
  else
      grant_align_m2 <= grant_m2;
end

always @(posedge hclk or negedge hresetn)
begin : dp_grant_m2_PROC
  if(hresetn == 1'b0)
    dp_grt_align_m2 <= { (`DMAH_NUM_PER){1'b0} };
  else
    if(hready_int[1])
      dp_grt_align_m2 <= grant_align_m2;
end

always @(posedge hclk or negedge hresetn)
begin : grant_align_m3_PROC
  if(hresetn == 1'b0)
    grant_align_m3 <= { (`DMAH_NUM_PER){1'b0} };
  else
    grant_align_m3 <= { (`DMAH_NUM_PER){1'b0} };
end

always @(posedge hclk or negedge hresetn)
begin : dp_grant_m3_PROC
  if(hresetn == 1'b0)
    dp_grt_align_m3 <= { (`DMAH_NUM_PER){1'b0} };
  else
    dp_grt_align_m3 <= { (`DMAH_NUM_PER){1'b0} };
end

always @(posedge hclk or negedge hresetn)
begin : grant_align_m4_PROC
  if(hresetn == 1'b0)
    grant_align_m4 <= { (`DMAH_NUM_PER){1'b0} };
  else
    grant_align_m4 <= { (`DMAH_NUM_PER){1'b0} };
end

always @(posedge hclk or negedge hresetn)
begin : dp_grant_m4_PROC
  if(hresetn == 1'b0)
    dp_grt_align_m4 <= { (`DMAH_NUM_PER){1'b0} };
  else
    dp_grt_align_m4 <= { (`DMAH_NUM_PER){1'b0} };
end

assign grant_align_int = {grant_align_m4,grant_align_m3,grant_align_m2,grant_align_m1};
assign grant_align = grant_align_int[`DMAH_NUM_MASTER_INT*`DMAH_NUM_PER-1:0];

// What if no s/m is requesting master interface. Then grt_align_all equals the
// last granted state machine and is NOT = 0. This is O.K. as if no state
// machine is granted ( because none is requesting ) then the master interface
// is idle and a mask_ch_disable_hlock pulse cannot occur.

//spyglass disable_block SelfDeterminedExpr-ML
//SMD: Self determined expression present in the design.
//SJ: This Self Determined Expression is as per the design requirement.
//    There will not be any functional issue.
//spyglass disable_block W415a
//SMD: Signal may be multiply assigned (beside initialization) in the same scope
//SJ: This multiple assignments are intentional and are as per the design requirement.
//    There will not be any functional issue.

always @(*)
begin : mask_ch_disable_hlock_ch_dst_PROC
  integer i;
  integer j;
  mask_ch_disable_hlock_ch_dst = {8{1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      mask_ch_disable_hlock_ch_dst[i] = mask_ch_disable_hlock_ch_dst[i] |
                                        (mask_ch_disable_hlock[j] &
                                         grt_align_all[(j*`DMAH_NUM_PER)+2*i + 1]);
end

always @(*)
begin : mask_ch_disable_hlock_ch_src_PROC
  integer i;
  integer j;
  mask_ch_disable_hlock_ch_src = {8{1'b0}};
  for(i=0; i < `DMAH_NUM_CHANNELS; i = i + 1)
    for(j=0; j < `DMAH_NUM_MASTER_INT; j = j + 1)
      mask_ch_disable_hlock_ch_src[i] = mask_ch_disable_hlock_ch_src[i] |
                                        (mask_ch_disable_hlock[j] &
                                         grt_align_all[(j*`DMAH_NUM_PER)+2*i]);
end

//spyglass enable_block W415a
//spyglass enable_block SelfDeterminedExpr-ML

assign mask_ch_disable_hlock_ch = mask_ch_disable_hlock_ch_src | mask_ch_disable_hlock_ch_dst;

endmodule

