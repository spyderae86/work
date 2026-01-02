//-----------------------------------------------------------------
//      module
//      test.com
//      Copyright 2025-2026
//      BSD
//-----------------------------------------------------------------
`include "DW_ahb_dmac_all_includes.vh"

module DW_ahb_dmac_arb_req_mi (

// Inputs
req_sm,
ch_ms,
mask_lck_ch,
grant_mi,

// Outputs
req_mi,
req_mbiu,
req_mbiu_exclude_current
);

// Runtime parameter

parameter MASTER_NUM = 2'b00;

// Channel master select.

// ch_ms = {...,ch1_dms_lli,ch1_sms,ch0_dms_lli,ch0_sms}

input [2*`DMAH_NUM_PER-1:0] ch_ms;

input [`DMAH_NUM_PER-1:0] mask_lck_ch;

input [`DMAH_NUM_PER-1:0] grant_mi;

// req inputs from channel source and destination s/m's.
// req_sm[0] = channel 0 src
// req_sm[1] = channel 0 destination
// req_sm[2] = channel 1 src
// req_sm[3] = channel 1 dest
// etc

// req_sm = {...,req_sm_dst_lli1,req_sm_src1,req_sm_dst_lli0,req_sm_src0}

input [`DMAH_NUM_PER-1:0] req_sm;

output [`DMAH_NUM_PER-1:0] req_mi;

output req_mbiu;

output req_mbiu_exclude_current;

reg [`DMAH_NUM_PER-1:0] req_mi;

reg [`DMAH_NUM_PER-1:0] req_peripherals;

wire req_mbiu;

//spyglass disable_block SelfDeterminedExpr-MI
//SMD: Self determined expression present in the design.
//SJ: This Self Determined Expression is as per the design requirement.
//     There will not be any functional issue.
//
// Mask of a request from a channel s/m to a master
// interface if that channel s/m has not been assigned
// to that master interface.
//spyglass disable_block W415a
//SMD: Signal may be multiply assigned (beside initialization) in the same scope
//SJ: This multiple assignments are intentional and are as per the design requirement.
//     There will not be any functional issue.
always @(ch_ms or req_sm)
begin : req_mi_PROC
integer i;
req_mi = {(`DMAH_NUM_PER){1'b0}};
for(i=0;i<`DMAH_NUM_PER ; i = i + 1)
  if({ch_ms[2*i+1],ch_ms[2*i]} == MASTER_NUM)
    req_mi[i] = req_sm[i];
  else
    req_mi[i] = 1'b0;
end
//spyglass enable_block W415a
//spyglass enable_block SelfDeterminedExpr-MI

// Mask out requests from state machines which will
// never be granted by internal arbiter due to the
// fact that they are masked out.

always @(mask_lck_ch or req_mi)
begin : req_peripherals_PROC
if(|mask_lck_ch)
  req_peripherals = (~mask_lck_ch) & req_mi;
else
  req_peripherals = req_mi;
end

// reg_mbiu asserted if any s/m ( bar currently granted one)
// is requesting mbiu. This is used to generate hbusreq


assign reg_mbiu = |reg_peripherals;


// reg_mbiu_exclude_current asserted if any state machine other than the L// currently granted state machine has it's request line asserted.

assign reg_mbiu_exclude_current = |(~grant_mi & reg_peripherals);

endmodule