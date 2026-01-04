//-----------------------------------------------------------------
//      module
//      test.com
//      Copyright 2025-2026
//      BSD
//-----------------------------------------------------------------
module DW_ahb_dmac_ch_to_mi_mux (
// Inputs
grant,
grant_align,
dp_grt_align,
st_addr_sm,
in_dst_tran_sm,
in_src_tran_sm,
dou_addr_inc_sm,
lock_b_sm,
lock_ch_sm,
lock_b_l_sm,
lock_ch_l_sm,
same_layer_sm,
write_sm,
size_sm,
prot_sm,
addr_ctrl_sm,
data_out_ch,
length_sm,
cancel_amba_req_dst_sm,
cancel_amba_req_src_sm,
can_goto_amba_dst,
can_tr_bc_dfc,
ch_sms,
ch_dms_lms,
wlast,
pop_m,
pop_hld_m,
pop_data_vld_m,
// Outputs
dma_wlast,
st_addr,
lock_b,
lock_ch,
lock_b_l,
lock_ch_l,
same_layer,
write,
size,
prot,
addr_ctrl,
length,
data_in,
dou_addr_inc,
in_src_tran,
in_dst_tran,
cancel_amba_req_m,
can_goto_amba_m
);

// need to concatenate bus's externally. The order is
// channel 0 source
// channel 0 destination
// channel 1 source
// channel 1 destination
// channel 2 source
// channel 2 destination
// etc


// When CC parameter DMAH_CHx_STAT_SRC is set to
// Include and ss_upd_en is de-asserted then source
// status register exists in external memory but do not update it.If
// DMAH_CHx_STAT_DST is set to include and ds_upd_en is enabled
// then need to write to ctrlx following by dst
// memory locations .i.e. need two beats of a 32 bit transfer
// where address increment is not aligned to hsize, the normal case,
// but address increment is twice hsize.


input [`DMAH_NUM_PER-1:0] dou_addr_inc_sm;

input [`DMAH_NUM_CHANNELS-1:0] in_dst_tran_sm;
input [`DMAH_NUM_CHANNELS-1:0] in_src_tran_sm;
input [`DMAH_NUM_CHANNELS-1:0] cancel_amba_req_dst_sm;  // Cancel requested AMBA
                                                        // transfer of requested
                                                        // length. Only occurs on
                                                        // source AMBA transfer when
                                                        // dst is flow controller.

input [`DMAH_NUM_CHANNELS-1:0] can_goto_amba_dst;        // Cancel tfr_req when goto_amba_state
                                                        // pulsed on dst s/m on same cycle as error
                                                        // response received on src s/m.


input [`DMAH_NUM_CHANNELS-1:0] can_tr_bc_dfc;           // Cancel tfr_req when goto_amba_state
                                                        // pulsed on src s/m on same cycle as error
                                                        // response received on dst s/m or when dst is flow
                                                        // controller and dst block completes on same
                                                        // cycle as goto_amba_state is pulsed on source s/m.

input [`DMAH_NUM_CHANNELS-1:0] cancel_amba_req_src_sm;

input [(`DMAH_NUM_MASTER_INT*`DMAH_NUM_PER)-1:0] grant;

// from mi_to_ch mux.
input [(`DMAH_NUM_MASTER_INT*`DMAH_NUM_PER)-1:0] grant_align;

input [(`DMAH_NUM_MASTER_INT*`DMAH_NUM_PER)-1:0] dp_grt_align;

input  [(`DMAH_NUM_PER*`DMAH_HADDR_WIDTH)-1:0] st_addr_sm;
input  [`DMAH_NUM_PER-1:0] lock_b_sm;
input  [`DMAH_NUM_PER-1:0] same_layer_sm;
input  [`DMAH_NUM_PER-1:0] lock_ch_sm;
input  [`DMAH_NUM_PER-1:0] write_sm;
input  [(2*`DMAH_NUM_PER)-1:0] lock_b_l_sm;
input  [(2*`DMAH_NUM_PER)-1:0] lock_ch_l_sm;
input  [(3*`DMAH_NUM_PER)-1:0] size_sm;
input  [(3*`DMAH_NUM_PER)-1:0] prot_sm;
input  [(2*`DMAH_NUM_PER)-1:0] addr_ctrl_sm;
input  [(`DMAH_NUM_PER*`LENGTH_BW)-1:0] length_sm;

// Tied to data_out_ch bus of each channel.

input  [(`DMAH_NUM_CHANNELS*`MAX_AHB_HDATA_WIDTH)-1:0] data_out_ch;

input  [(2*`DMAH_NUM_CHANNELS)-1:0] ch_sms;
input  [(2*`DMAH_NUM_CHANNELS)-1:0] ch_dms_lms;
input  [`DMAH_NUM_CHANNELS-1:0] wlast;
input  [`DMAH_NUM_MASTER_INT-1:0] pop_m;
input  [`DMAH_NUM_MASTER_INT-1:0] pop_hld_m;
input  [`DMAH_NUM_MASTER_INT-1:0] pop_data_vld_m;

output [`DMAH_NUM_MASTER_INT-1:0] dma_wlast;
output [`DMAH_NUM_MASTER_INT-1:0] lock_b;
output [`DMAH_NUM_MASTER_INT-1:0] lock_ch;
output [`DMAH_NUM_MASTER_INT-1:0] same_layer;
output [`DMAH_NUM_MASTER_INT-1:0] write;
output [`DMAH_NUM_MASTER_INT-1:0] dou_addr_inc;
output [`DMAH_NUM_MASTER_INT-1:0] in_src_tran;
output [`DMAH_NUM_MASTER_INT-1:0] in_dst_tran;
output [`DMAH_NUM_MASTER_INT-1:0] cancel_amba_req_m;
output [`DMAH_NUM_MASTER_INT-1:0] can_goto_amba_m;
output [(2*`DMAH_NUM_MASTER_INT)-1:0] lock_b_l;
output [(2*`DMAH_NUM_MASTER_INT)-1:0] lock_ch_l;
output [(2*`DMAH_NUM_MASTER_INT)-1:0] addr_ctrl;
output [(3*`DMAH_NUM_MASTER_INT)-1:0] size;
output [(3*`DMAH_NUM_MASTER_INT)-1:0] prot;
output [(`LENGTH_BW*`DMAH_NUM_MASTER_INT)-1:0] length;
output [(`MAX_AHB_HDATA_WIDTH*`DMAH_NUM_MASTER_INT)-1:0] data_in;
output [(`DMAH_HADDR_WIDTH*`DMAH_NUM_MASTER_INT)-1:0] st_addr;


reg [`DMAH_NUM_MASTER_INT-1:0] dma_wlast;
reg [`DMAH_NUM_MASTER_INT-1:0] lock_b;
reg [`DMAH_NUM_MASTER_INT-1:0] lock_ch;
reg [`DMAH_NUM_MASTER_INT-1:0] same_layer;
reg [`DMAH_NUM_MASTER_INT-1:0] write;
reg [`DMAH_NUM_MASTER_INT-1:0] dou_addr_inc;
reg [`DMAH_NUM_MASTER_INT-1:0] in_src_tran;
reg [`DMAH_NUM_MASTER_INT-1:0] in_dst_tran;
reg [`DMAH_NUM_MASTER_INT-1:0] cancel_amba_req_m_dst;
reg [`DMAH_NUM_MASTER_INT-1:0] cancel_amba_req_m_src;
reg [`DMAH_NUM_MASTER_INT-1:0] can_goto_amba_m_src;
reg [`DMAH_NUM_MASTER_INT-1:0] can_goto_amba_m_dst;
reg [(2*`DMAH_NUM_MASTER_INT)-1:0] lock_b_l;
reg [(2*`DMAH_NUM_MASTER_INT)-1:0] lock_ch_l;
reg [(2*`DMAH_NUM_MASTER_INT)-1:0] addr_ctrl;
reg [(3*`DMAH_NUM_MASTER_INT)-1:0] size;
reg [(3*`DMAH_NUM_MASTER_INT)-1:0] prot;
reg [(`LENGTH_BW*`DMAH_NUM_MASTER_INT)-1:0] length;
reg [(`MAX_AHB_HDATA_WIDTH*`DMAH_NUM_MASTER_INT)-1:0] data_in;
reg [(`DMAH_HADDR_WIDTH*`DMAH_NUM_MASTER_INT)-1:0] st_addr;

wire [`DMAH_NUM_MASTER_INT-1:0] cancel_amba_req_m;


// This module use's a parameterized one-hot mux that will
// multiplex several buses (quantity specified at compile time, and
// controlled by a parameter) of a particular width (which is also
// specified at compile time by a parameter).
// One of the subtleties that might not be obvious that makes this work
// so well is the use of the blocking assignment (=) that allows
// data_out to be built up incrementally. The one-hot select builds up
// into the wide "or" function you`d code by hand.
// Inner loop required because verilog won`t allow non-constant
// range specification for vectors

// grant_mi is a one hot bus.


// Steer's one of the lock signal from the channel's
// source and destination state machine's to each of
// master interfaces depending on which s/m is currently
// granted the master interface. Note that if a state machine
// is not assigned to a particular master interface it will
// not request it and therefore will not be granted that
// master interface.
// No need to used the aligned version of grant_mx as the
// lock and other transfer control signals are latched on the tfr_req
// pulse.


// lock_b_sm is a concatenation of the lock signals from all
// channel s/m's.
// lock_b_sm[0] = channel 0 src lock
// lock_b_sm[1] = channel 0 dst lock
// lock_b_sm[2] = channel 1 src lock
// lock_b_sm[3] = channel 1 dst lock
// etc

// Similar muxing for other control/data from channel
// s/m's to master interface's.


//spyglass disable_block SelfDeterminedExpr-ML
//SMD: Self determined expression present in the design.
//SJ:  This Self Determined Expression is as per the design requirement.
//     There will not be any functional issue.
//spyglass disable_block W415a
//SMD: Signal may be multiply assigned (beside initialization) in the same scope
//SJ:  This multiple assignments are intentional and are as per the design requirement.
//     There will not be any functional issue.

always @(*)
begin:lock_b_PROC
  integer i;
  integer k;
  lock_b = {(`DMAH_NUM_MASTER_INT){1'b0}};
  for(k=0; k < `DMAH_NUM_MASTER_INT ; k = k + 1)
    for(i=0; i < `DMAH_NUM_PER ; i = i + 1)
      lock_b[k] = lock_b[k] | (lock_b_sm[i] & grant[k*`DMAH_NUM_PER + i]);
end


// Channel lock steering

always @(*)
begin:lock_ch_PROC
  integer i;
  integer k;
  lock_ch = {(`DMAH_NUM_MASTER_INT){1'b0}};
  for(k=0; k < `DMAH_NUM_MASTER_INT ; k = k + 1)
    for(i=0; i < `DMAH_NUM_PER ; i = i + 1)
      lock_ch[k] = lock_ch[k] | (lock_ch_sm[i] & grant[k*`DMAH_NUM_PER + i]);
end


// Channel bus level steering

always @(*)
begin:lock_b_l_PROC
  integer i;
  integer j;
  integer k;
  lock_b_l = {(2*`DMAH_NUM_MASTER_INT){1'b0}};
  for(k=0; k < `DMAH_NUM_MASTER_INT ; k = k + 1)
    for(i=0; i < `DMAH_NUM_PER ; i = i + 1)
      for(j=0; j < 2; j = j + 1)
        lock_b_l[k*2 + j] = lock_b_l[k*2 + j] |
                            (lock_b_l_sm[2*i + j] &
                             grant[k*`DMAH_NUM_PER + i]);
end


// Channel channel level steering

always @(*)
begin:lock_ch_l_PROC
  integer i;
  integer j;
  integer k;
  lock_ch_l = {(2*`DMAH_NUM_MASTER_INT){1'b0}};
  for(k=0; k < `DMAH_NUM_MASTER_INT ; k = k + 1)
    for(i=0; i < `DMAH_NUM_PER ; i = i + 1)
      for(j=0; j < 2; j = j + 1)
        lock_ch_l[k*2 + j] = lock_ch_l[k*2 + j] |
                             (lock_ch_l_sm[2*i + j] &
                              grant[k*`DMAH_NUM_PER + i]);
end


// same layer asserted when channel source and destination are
// on the same layer

always @(*)
begin:same_layer_PROC
  integer i;
  integer k;
  same_layer = {(`DMAH_NUM_MASTER_INT){1'b0}};
  for(k=0; k < `DMAH_NUM_MASTER_INT ; k = k + 1)
    for(i=0; i < `DMAH_NUM_PER ; i = i + 1)
      same_layer[k] = same_layer[k] |
                      (same_layer_sm[i] &
                       grant[k*`DMAH_NUM_PER + i]);
end


// Steerls one of the dou_addr_inc signals from a channel's
// destination state machine to each of
// master interfaces depending on which s/m is currently
// granted the master interface.

always @(*)
begin:dou_addr_inc_PROC
    integer i;
    integer k;
    dou_addr_inc = {(`DMAH_NUM_MASTER_INT){1'b0}};
    for(k=0; k < `DMAH_NUM_MASTER_INT ; k = k + 1)
        for(i=0; i < `DMAH_NUM_PER ; i = i + 1)
            dou_addr_inc[k] = dou_addr_inc[k] | (dou_addr_inc_sm[i] &
                                grant[k*`DMAH_NUM_PER + i]);
end


// write indicates whether requested transfer is read
// or write

always @(*)
begin:write_PROC
    integer i;
    integer k;
    write = {(`DMAH_NUM_MASTER_INT){1'b0}};
    for(k=0; k < `DMAH_NUM_MASTER_INT ; k = k + 1)
        for(i=0; i < `DMAH_NUM_PER ; i = i + 1)
            write[k] = write[k] | (write_sm[i] & grant[k*`DMAH_NUM_PER + i]);
end


// address control indicates incrementing, decrementing and
// fixed address control.
// 00 increment
// 01 decrement
// 1x No change

always @(*)
begin:addr_ctrl_PROC
    integer i;
    integer j;
    integer k;
    addr_ctrl = {(2*`DMAH_NUM_MASTER_INT){1'b0}};
    for(k=0; k < `DMAH_NUM_MASTER_INT ; k = k + 1)
        for(i=0; i < `DMAH_NUM_PER ; i = i + 1)
            for(j=0; j < 2; j = j + 1)
                addr_ctrl[k*2 + j] = addr_ctrl[k*2 + j] |
                                    (addr_ctrl_sm[2*i + j] &
                                     grant[k*`DMAH_NUM_PER + i]);
end


// size indicates requested transfer size.

always @(*)
begin:size_PROC
    integer i;
    integer j;
    integer k;
    size = {(3*`DMAH_NUM_MASTER_INT){1'b0}};
    for(k=0; k < `DMAH_NUM_MASTER_INT ; k = k + 1)
        for(i=0; i < `DMAH_NUM_PER ; i = i + 1)
            for(j=0; j < 3; j = j + 1)
                size[k*3 + j] = size[k*3 + j] | (size_sm[3*i + j] &
                                                 grant[k*`DMAH_NUM_PER + i]);
end


// prot indicates how hprot[3:1] should be driven for the requested
// transfer. hprot[0] hardcoded to 0.

always @(*)
begin:prot_PROC
    integer i;
    integer j;
    integer k;
    prot = {(3*`DMAH_NUM_MASTER_INT){1'b0}};
    for(k=0; k < `DMAH_NUM_MASTER_INT ; k = k + 1)
        for(i=0; i < `DMAH_NUM_PER ; i = i + 1)
            for(j=0; j < 3; j = j + 1)
                prot[k*3 + j] = prot[k*3 + j] | (prot_sm[3*i + j] &
                                                 grant[k*`DMAH_NUM_PER + i]);
end


// length indicates the number of beats in the requested transfer.

always @(*)
begin:length_PROC
    integer i;
    integer j;
    integer k;
    length = {(`LENGTH_BW*`DMAH_NUM_MASTER_INT){1'b0}};
    for(k=0; k < `DMAH_NUM_MASTER_INT ; k = k + 1)
        for(i=0; i < `DMAH_NUM_PER ; i = i + 1)
            for(j=0; j < `LENGTH_BW ; j = j + 1)
                length[k*`LENGTH_BW + j] =
                    length[k*`LENGTH_BW + j] |
                    (length_sm[`LENGTH_BW*i + j] &
                     grant[k*`DMAH_NUM_PER + i]);
end


// Poped data from channel FIFO.

always @(*)
begin:data_in_PROC
    integer i;
    integer j;
    integer k;
    data_in = {(`MAX_AHB_HDATA_WIDTH*`DMAH_NUM_MASTER_INT){1'b0}};
    for(k=0; k < `DMAH_NUM_MASTER_INT ; k = k + 1)
        for(i=0; i < `DMAH_NUM_CHANNELS ; i = i + 1)
            for(j=0; j < `MAX_AHB_HDATA_WIDTH ; j = j + 1)
                data_in[k*`MAX_AHB_HDATA_WIDTH + j] =
				            data_in[k*`MAX_AHB_HDATA_WIDTH + j] |
							(data_out_ch[`MAX_AHB_HDATA_WIDTH*i + j] &
							grant_align[k*`DMAH_NUM_PER + 2*i + 1]);
end


// Dma_wlast
// When muxing the WLAST signal out to the master interface, we need to ensure that
// it only get muxed to the master interface that poped data from the channel FIFO.
// To do this we pass WLAST out if the channel has asserted WLAST, the master interface
// has granted the dst_sm in that channel and either pop or pop_data_vld is asserted
// by the master interface.
// We use both pop and pop_data_vld as WLAST is extended by hready low and pop_data_vld
// is asserted from pop when hready is high.

always @(*)
begin:dma_wlast_PROC
    integer i;
    integer k;
    dma_wlast = {(`DMAH_NUM_MASTER_INT){1'b0}};
    for(k=0; k < `DMAH_NUM_MASTER_INT ; k = k + 1)
        for(i=0; i < `DMAH_NUM_CHANNELS ; i = i + 1)
            dma_wlast[k] =
				dma_wlast[k] |
                (wlast[i] & (pop_m[k] | pop_data_vld_m[k] | pop_hld_m[k]) &
                 dp_grt_align[k*`DMAH_NUM_PER + 2*i + 1]);
end


// st_addr indicates the starting address of the requested transfer.

always @(*)
begin:st_addr_PROC
    integer i;
    integer j;
    integer k;
    st_addr = {(`DMAH_HADDR_WIDTH*`DMAH_NUM_MASTER_INT){1'b0}};
    for(k=0; k < `DMAH_NUM_MASTER_INT ; k = k + 1)
        for(i=0; i < `DMAH_NUM_PER ; i = i + 1)
            for(j=0; j < `DMAH_HADDR_WIDTH ; j = j + 1)
                st_addr[k*`DMAH_HADDR_WIDTH + j] = st_addr[k*`DMAH_HADDR_WIDTH + j] |
                                                  (st_addr_sm[`DMAH_HADDR_WIDTH*i + j] &
                                                   grant[k*`DMAH_NUM_PER + i]);
end


// Need to see if currently in middle of src transaction when the corresponding
// dst s/m is granted.

// in_src_tran is registered in master block on tfr req. So when this registered
// signal is sampled ( at the end of a dst transaction ) the last s/m to
// be granted may be the dst s/m or s/m. This is due to the fact that tran_comp signal
// is on the data phase of the last transfer and may have back to back transfers between
// source and destination so when trans_comp_dst is asserted if do NOT have back to back transfers
// then last granted when trans_comp_dst asserted is dst but if have back to back transfers
// than last granted is src.

always @(*)
begin:in_src_tran_PROC
    integer i;
    integer k;
    in_src_tran = {(`DMAH_NUM_MASTER_INT){1'b0}};
    for(k=0; k < `DMAH_NUM_MASTER_INT ; k = k + 1)
        for(i=0; i < `DMAH_NUM_CHANNELS ; i = i + 1)
            in_src_tran[k] = in_src_tran[k] | (in_src_tran_sm[i] &
                                              (grant_align[k*`DMAH_NUM_PER + 2*i + 1] || grant_align[k*`DMAH_NUM_PER + 2*i]));
end

// Need to see if currently in middle of dst transaction when the corresponding
// src s/m is granted.

always @(*)
begin:in_dst_tran_PROC
    integer i;
    integer k;
    in_dst_tran = {(`DMAH_NUM_MASTER_INT){1'b0}};
    for(k=0; k < `DMAH_NUM_MASTER_INT ; k = k + 1)
        for(i=0; i < `DMAH_NUM_CHANNELS ; i = i + 1)
            in_dst_tran[k] = in_dst_tran[k] | (in_dst_tran_sm[i] &
                                              (grant_align[k*`DMAH_NUM_PER + 2*i] || grant_align[k*`DMAH_NUM_PER + 2*i + 1]));
end


// A Source peripheral will only cancel a transfer when dst is flow controller
// A Dst peripheral will never try and cancel a requested AMBA transfer.
// Src will also cancel if dst s/m receives an error response while
// src s/m in amba state. Similarly for dst.

always @(*)
begin:cancel_amba_req_m_dst_PROC
    integer i;
    integer k;
    cancel_amba_req_m_dst = {(`DMAH_NUM_MASTER_INT){1'b0}};
    for(k=0; k < `DMAH_NUM_MASTER_INT ; k = k + 1)
        for(i=0; i < `DMAH_NUM_CHANNELS ; i = i + 1)
            cancel_amba_req_m_dst[k] = cancel_amba_req_m_dst[k] | ((cancel_amba_req_dst_sm[i] &
                                                                   grant_align[k*`DMAH_NUM_PER + 2*i + 1]) && ({ch_dms_lms[2*i+1],ch_dms_lms[2*i]}==k));
end

always @(*)
begin:cancel_amba_req_m_src_PROC
    integer i;
    integer k;
    cancel_amba_req_m_src = {(`DMAH_NUM_MASTER_INT){1'b0}};
    for(k=0; k < `DMAH_NUM_MASTER_INT ; k = k + 1)
        for(i=0; i < `DMAH_NUM_CHANNELS ; i = i + 1)
            cancel_amba_req_m_src[k] = cancel_amba_req_m_src[k] | ((cancel_amba_req_src_sm[i] &
                                      grant_align[k*`DMAH_NUM_PER + 2*i]) && ({ch_sms[2*i+1],ch_sms[2*i]}==k));
end

assign cancel_amba_req_m = cancel_amba_req_m_src | cancel_amba_req_m_dst;


// Mask out can_goto_amba_m when occurs on same cycle as
// tfr_req. This may occur when on the same cycle as tfr_req
// grant_align ( switches one cycle later ) points to
// a peripheral which issues a can_goto_amba_m to a
// different master.

always @(*)
begin:can_goto_amba_m_dst_PROC
    integer i;
    integer k;
    can_goto_amba_m_dst = {(`DMAH_NUM_MASTER_INT){1'b0}};
    for(k=0; k < `DMAH_NUM_MASTER_INT ; k = k + 1)
        for(i=0; i < `DMAH_NUM_CHANNELS ; i = i + 1)
            can_goto_amba_m_dst[k] = can_goto_amba_m_dst[k] | ((can_goto_amba_dst[i] &
                                                              grant_align[k*`DMAH_NUM_PER + 2*i + 1]) && ({ch_dms_lms[2*i+1],ch_dms_lms[2*i]}==k));
end

always @(*)
begin:can_goto_amba_m_src_PROC
    integer i;
    integer k;
    can_goto_amba_m_src = {(`DMAH_NUM_MASTER_INT){1'b0}};
    for(k=0; k < `DMAH_NUM_MASTER_INT ; k = k + 1)
        for(i=0; i < `DMAH_NUM_CHANNELS ; i = i + 1)
            can_goto_amba_m_src[k] = can_goto_amba_m_src[k] | ((can_tr_bc_dfc[i] &
                                                              grant_align[k*`DMAH_NUM_PER + 2*i]) && ({ch_sms[2*i+1],ch_sms[2*i]}==k));
end

assign can_goto_amba_m = can_goto_amba_m_src | can_goto_amba_m_dst;

//spyglass enable_block W415a
//spyglass enable_block SelfDeterminedExpr-ML

endmodule