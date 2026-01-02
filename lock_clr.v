//-----------------------------------------------------------------
//      module
//      test.com
//      Copyright 2025-2026
//      BSD
//-----------------------------------------------------------------

module DW_ahb_dmac_lock_clr (

// Outputs
clr_mask_lck,
hlock_clr,
lock_ch_int_comb,
lock_ch_l_int_comb,
clr_mask_lck_on_can_dfc,
hlock_clr_on_can_dfc,

// Inputs
hclk,
hresetn,
trans_comp_src,
trans_comp_dst,
bcomp_red_src,
block_comp_dst,
tfr_comp_src,
tfr_comp_dst,
same_layer_m,
ch_sms,
ch_dms,
lock_ch_l_m,
lock_b_l_m,
hc_lock_b_m,
hc_lock_ch_m,
in_src_tran_m,
in_dst_tran_m,
tfr_req,
clr_lock_error,
lock_ch_all,
lock_b_all,
ch_disabled_mask,
mask_lck_ch,
//split_retry,
can_goto_amba_m
);

// Runtime parameter.
parameter MASTER_NUM = 2'b00;
parameter DMAH_LOCK_EN = 1'b0;

output clr_mask_lck;         // Clear masking of channel request lines to arbiter.
output hlock_clr;            // Clear hlock signal.
output lock_ch_int_comb;     // command to lock channel arbiter on current
                             // transfer request tfr_req

output lock_ch_l_int_comb;

output clr_mask_lck_on_can_dfc;
output hlock_clr_on_can_dfc;

input hclk;
input hresetn;
input in_src_tran_m;          // Currently in middle of src transaction. From src s/m
                              // via channel to master mux.
input in_dst_tran_m;          // Currently in middle of dst transaction. From dst s/m
                              // via channel to master mux.

input [`DMAH_NUM_CHANNELS-1:0] trans_comp_src;
input [`DMAH_NUM_CHANNELS-1:0] trans_comp_dst;
input [`DMAH_NUM_CHANNELS-1:0] bcomp_red_src;
input [`DMAH_NUM_CHANNELS-1:0] block_comp_dst;
input [`DMAH_NUM_CHANNELS-1:0] tfr_comp_src;
input [`DMAH_NUM_CHANNELS-1:0] tfr_comp_dst;

input same_layer_m;           //src and dst on same layer, from channel to
                              //master mux.

input [2*`DMAH_NUM_CHANNELS-1:0] ch_sms;
input [2*`DMAH_NUM_CHANNELS-1:0] ch_dms;

input [1:0] lock_ch_l_m;      //channel lock level from channel to master mux.
input [1:0] lock_b_l_m;       //bus lock level from channel to master mux.

input hc_lock_b_m;            //bus lock enable from channel to master mux.
input hc_lock_ch_m;           //channel lock enable from channel to master mux.

input tfr_req;                // Single pulse transfer request. All control
                              // inputs pertinent to the requested transfer are
                              // latched on this pulse i.e. length, s_addr,
                              // addr_ctrl, write, size, prot and lock. Asserted
                              // when hready is high, i.e. on same cycle
                              // as data phase completion of last beat of
                              // previous transfer. st_addr will be driven onto
                              // haddr bus on the cycle after tfr_req is pulsed.
                              // Note that tfr_req will only be pulsed when
                              // the master interface is granted control of
                              // AHB bus when hready is high.

input clr_lock_error;          // From mbiu.v block. Always clear
                              // the locking of the bus and channel arbiter
                              // for all transfer levels when an error
                              // response is received.

input [`DMAH_NUM_CHANNELS-1:0] lock_ch_all;
input [`DMAH_NUM_CHANNELS-1:0] lock_b_all;

// Asserted when channel is disabled while locking active.
input ch_disabled_mask;
input [`DMAH_NUM_PER-1:0] mask_lck_ch;
//input split_retry;

input can_goto_amba_m;


reg lock_ch_int;
reg [1:0] lock_ch_l_int;
wire lock_ch_l_int_comb;

reg [`DMAH_NUM_CHANNELS-1:0] trans_c_src_int;
reg [`DMAH_NUM_CHANNELS-1:0] trans_c_dst_int;
reg [`DMAH_NUM_CHANNELS-1:0] bc_src_int;
reg [`DMAH_NUM_CHANNELS-1:0] bc_dst_int;
reg [`DMAH_NUM_CHANNELS-1:0] tfrc_src_int;
reg [`DMAH_NUM_CHANNELS-1:0] tfrc_dst_int;

reg [`DMAH_NUM_CHANNELS-1:0] trans_c_src_int_b;
reg [`DMAH_NUM_CHANNELS-1:0] trans_c_dst_int_b;
reg [`DMAH_NUM_CHANNELS-1:0] bc_src_int_b;
reg [`DMAH_NUM_CHANNELS-1:0] bc_dst_int_b;
reg [`DMAH_NUM_CHANNELS-1:0] tfrc_src_int_b;
reg [`DMAH_NUM_CHANNELS-1:0] tfrc_dst_int_b;

reg hlock_clr;
reg clr_mask_lck;
reg same_layer_m_reg;
reg [1:0] hc_lock_b_l_m_reg;
reg hc_lock_b_m_reg;
reg [1:0] hc_lock_ch_l_m_reg;
reg hc_lock_ch_m_reg;
// reg in_src_tran_int;
// reg in_dst_tran_int;
reg lock_ch_int_comb;

reg [`DMAH_NUM_CHANNELS-1:0] bcomp_red_src_msk;
reg [`DMAH_NUM_CHANNELS-1:0] tfr_comp_src_msk;
reg [`DMAH_NUM_CHANNELS-1:0] mask_lck_ch_src;

reg [`DMAH_NUM_CHANNELS-1:0] trans_comp_src_msk;

reg tfrc_src_int_ro_b_reg;

wire same_layer_m_int;
wire trans_c_src_ro;
wire trans_c_dst_ro;
wire bc_src_int_ro;
wire bc_dst_int_ro;
wire tfrc_src_int_ro;
wire tfrc_dst_int_ro;

wire [1:0] lock_b_l_m_reg;
wire [1:0] lock_ch_l_m_reg;

wire trans_c_src_ro_b;
wire trans_c_dst_ro_b;
wire bc_src_int_ro_b;
wire bc_dst_int_ro_b;
wire tfrc_src_int_ro_b;
wire tfrc_dst_int_ro_b;

wire clr_mask_lck_on_can_dfc;
wire hlock_clr_on_can_dfc;

wire lock_b_m;
wire lock_ch_m;
wire lock_b_m_reg;
wire lock_ch_m_reg;
wire lock_en;

///////////////////////////////////////////////////////////////

assign lock_en = DMAH_LOCK_EN;
assign lock_b_m  = (lock_en) ? hc_lock_b_m  : 1'b0;
assign lock_ch_m = (lock_en) ? hc_lock_ch_m : 1'b0;
assign same_layer_m_int = 1'b1;

//SJ: same layer m reg gets read only when DMAH_MASTER_INT = 1, which is as per design requirement
always @(posedge hclk or negedge hresetn)
begin
    if (~hresetn) begin
        same_layer_m_reg <= 1'b0;
    else
        if(tfr_req)
            same_layer_m_reg <= same_layer_m;
    end
end
//spylass enable block W528
always @(posedge hclk or negedge hresetn)
begin
    if (~hresetn) begin
        hc_lock_b_l_m_reg <= 2'b00;
    else
        if(tfr_req)
            hc_lock_b_l_m_reg <= lock_b_l_m;
        else
            hc_lock_b_l_m_reg <= lock_b_l_m_reg;
    end
end
assign lock_b_l_m_reg = (lock_en) ? hc_lock_b_l_m_reg : 2'b00;

always @(posedge hclk or negedge hresetn)
begin
    if (~hresetn) begin
        hc_lock_ch_l_m_reg <= 2'b00;
    else
        if(tfr_req)
            hc_lock_ch_l_m_reg <= lock_ch_l_m;
        else
            hc_lock_ch_l_m_reg <= lock_ch_l_m_reg;
    end
end
assign lock_ch_l_m_reg = (lock_en) ? hc_lock_ch_l_m_reg : 2'b00;

always @(posedge hclk or negedge hresetn)
begin
    if (~hresetn) begin
        hc_lock_b_m_reg <= 1'b0;
    else
        if(tfr_req)
            hc_lock_b_m_reg <= lock_b_m;
        else
            hc_lock_b_m_reg <= lock_b_m_reg;
    end
end
assign lock_b_m_reg = (lock_en) ? hc_lock_b_m_reg : 0;

always @(posedge hclk or negedge hresetn)
begin
    if (~hresetn) begin
        hc_lock_ch_m_reg <= 1'b0;
    else
        if(tfr_req)
            hc_lock_ch_m_reg <= lock_ch_m;
        else
            hc_lock_ch_m_reg <= lock_ch_m_reg;
    end
end
assign lock_ch_m_reg = (lock_en) ? hc_lock_ch_m_reg : 0;


always @(posedge hclk or negedge hresetn)
begin
    if (~hresetn) begin
        tfrc_src_int_ro_b_reg <= 1'b0;
    else
        tfrc_src_int_ro_b_reg <= tfrc_src_int_ro_b;
    end
end

// has completed it's DMA transfer. A tfrc_src_int from a different
// channel will not occur and therefore it is OK to generate
// a signal from the reduction OR of tfrc_src_int to clear the master
// interface locking. The same is true for block level locking.

// When the dst is assigned as flow control peripheral then a
// bc_src_int or tfrc_src_int from a different channel than the
// one presently locked can occur when fcmode = 0 (data prefetching enabled)
// for that channel. If the reduction OR signal is used to clear the locking then
// this will result in a locking error.


/////spylass disable block SelfDeterminedXpr-ML design.
//SM: Self determined expression present in the design.
//SJ: There Self Determined Expression is as per the design requirement.
always @(*)
begin
    integer i;
    for(i=0; i < DMAH_NUM_CHANNELS; i=i+1)
        mask_lck_ch_src[i] = mask_lck_ch[2*i];
end
//spylass enable block SelfDeterminedXpr-ML
always @(tfr_comp_src or mask_lck_ch_src)
begin
    tfr_comp_src_msk = tfr_comp_src & (~mask_lck_ch_src);
end

always @(bcomp_red_src or mask_lck_ch_src)
begin
    bcomp_red_src_msk = bcomp_red_src & (~mask_lck_ch_src);
end

always @(trans_comp_src or mask_lck_ch_src)
begin
    trans_comp_src_msk = trans_comp_src & (~mask_lck_ch_src);
end
///bcomp_red_src_msk PROC
///ML


//spylass disable block SelfDeterminedXpr-ML
//SM: Self determined block Expression present in the design.
//SJ: This Self Determined Expression is as per the design requirement.
/*
There will not be any functional issue.
*/
always @(ch_sms or trans_comp_src_msk or lock_ch_all)
begin
    integer i;
    for(i=0; i < `DMAH_NUM_CHANNELS; i=i+1)
        trans_c_src_int[i] = ({ch_sms[2*i+1],ch_sms[2*i]} == MASTER_NUM)
                           && trans_comp_src_msk[i] && lock_ch_all[i];
end
//spylass enable block SelfDeterminedXpr-ML
// Reduction OR of trans_c_src_int
assign trans_c_src_ro = trans_c_src_int;

//spylass disable block SelfDeterminedXpr-ML
//SM: Self disable block SelfDeterminedXpr-ML
//SJ: This Self Determined Expression is as per the design requirement.
/*
There will not be any functional issue.
*/
always @(ch_dms or trans_comp_dst or lock_ch_all)
begin
    integer i;
    for(i=0; i < `DMAH_NUM_CHANNELS; i=i+1)
        trans_c_dst_int[i] = ({ch_dms[2*i+1],ch_dms[2*i]} == MASTER_NUM)
                           && trans_comp_dst[i] && lock_ch_all[i];
end
//spylass enable block SelfDeterminedXpr-ML
// Reduction OR of trans_c_dst_int

assign trans_c_dst_ro = trans_c_dst_int;

//spylass disable block SelfDeterminedXpr-ML
//SM: Self determined block Expression present in the design.
//SJ: This Self Determined Expression is as per the design requirement.
/*
There will not be any functional issue.
*/
always @(ch_sms or bcomp_red_src_msk or lock_ch_all)
begin
    integer i;
    for(i=0; i < `DMAH_NUM_CHANNELS; i=i+1)
        bc_src_int[i] = ({ch_sms[2*i+1],ch_sms[2*i]} == MASTER_NUM)
                        && bcomp_red_src_msk[i] && lock_ch_all[i];
end
//spylass enable block SelfDeterminedXpr-ML
// Reduction OR of bc_src_int
assign bc_src_int_ro = bc_src_int;

//spylass disable block SelfDeterminedXpr-ML
//SM: Self determined block Expression present in the design.
//SJ: This Self Determined Expression is as per the design requirement.
/*
There will not be any functional issue.
*/
always @(ch_dms or block_comp_dst or lock_ch_all)
begin
    integer i;
    for(i=0; i < `DMAH_NUM_CHANNELS; i=i+1)
        bc_dst_int[i] = ({ch_dms[2*i+1],ch_dms[2*i]} == MASTER_NUM)
                        && block_comp_dst[i] && lock_ch_all[i];
end
//spylass enable block SelfDeterminedXpr-ML
// Reduction OR of bc_dst_int
assign bc_dst_int_ro = bc_dst_int;

//spylass disable block SelfDeterminedXpr-ML
//SM: Self determined expression present in the design.
//SJ: There Self Determined Expression is as per the design requirement.
always @(ch_dms or tfr_comp_dst or lock_ch_all)
begin
    integer i;
    for(i=0; i < `DMAH_NUM_CHANNELS; i=i+1)
        tfrc_dst_int[i] = ({ch_dms[2*i+1],ch_dms[2*i]} == MASTER_NUM)
                         && tfr_comp_dst[i] && lock_ch_all[i];
end
//spylass enable block SelfDeterminedXpr-ML
// Reduction OR of bc_src_int
assign tfrc_dst_int_ro = tfrc_dst_int;

//spylass disable block SelfDeterminedXpr-ML
//SM: Self determined block Expression present in the design.
//SJ: This Self Determined Expression is as per the design requirement.
/*
There will not be any functional issue.
*/
always @(ch_sms or tfr_comp_src_msk or lock_ch_all)
begin
    integer i;
    for(i=0; i < `DMAH_NUM_CHANNELS; i=i+1)
        tfrc_src_int[i] = ({ch_sms[2*i+1],ch_sms[2*i]} == MASTER_NUM)
                         && tfr_comp_src_msk[i] && lock_ch_all[i];
end
//spylass enable block SelfDeterminedXpr-ML
// Reduction OR of tfrc_src_int
assign tfrc_src_int_ro = tfrc_src_int;

/*****************************/

//spylass disable block SelfDeterminedXpr-ML
//SM: Self disable block SelfDeterminedXpr-ML
//SJ: This Self Determined Expression is as per the design requirement.
/*
There will not be any functional issue.
*/
always @(ch_sms or trans_comp_src_msk or lock_b_all)
begin
    integer i;
    for(i=0; i < `DMAH_NUM_CHANNELS; i=i+1)
        trans_c_src_int_b[i] = ({ch_sms[2*i+1],ch_sms[2*i]} == MASTER_NUM)
                               && trans_comp_src_msk[i] && lock_b_all[i];
end
//spylass enable block SelfDeterminedXpr-ML
// Reduction OR of trans_c_src_int_b
assign trans_c_src_ro_b = trans_c_src_int_b;

//spylass disable block SelfDeterminedXpr-ML
//SM: Self determined block Expression present in the design.
//SJ: This Self Determined Expression is as per the design requirement.
/*
There will not be any functional issue.
*/
always @(ch_dms or trans_comp_dst or lock_b_all)
begin
    integer i;
    for(i=0; i < `DMAH_NUM_CHANNELS; i=i+1)
        trans_c_dst_int_b[i] = ({ch_dms[2*i+1],ch_dms[2*i]} == MASTER_NUM)
                               && trans_comp_dst[i] && lock_b_all[i];
end
//spylass enable block SelfDeterminedXpr-ML
// Reduction OR of trans_c_dst_int_b
assign trans_c_dst_ro_b = trans_c_dst_int_b;

//spylass disable block SelfDeterminedXpr-ML
//SM: Self determined block Expression present in the design.
//SJ: This Self Determined Expression is as per the design requirement.
/*
There will not be any functional issue.
*/
always @(ch_sms or bcomp_red_src_msk or lock_b_all)
begin
    integer i;
    for(i=0; i < `DMAH_NUM_CHANNELS; i=i+1)
        bc_src_int_b[i] = ({ch_sms[2*i+1],ch_sms[2*i]} == MASTER_NUM)
                          && bcomp_red_src_msk[i] && lock_b_all[i];
end
//spylass enable block SelfDeterminedXpr-ML
// Reduction OR of bc_src_int_b
assign bc_src_int_ro_b = bc_src_int_b;

//spylass disable block SelfDeterminedXpr-ML
//SM: Self determined block Expression present in the design.
//SJ: This Self Determined Expression is as per the design requirement.
/*
There will not be any functional issue.
*/
always @(ch_dms or block_comp_dst or lock_b_all)
begin
    integer i;
    for(i=0; i < `DMAH_NUM_CHANNELS; i=i+1)
        bc_dst_int_b[i] = ({ch_dms[2*i+1],ch_dms[2*i]} == MASTER_NUM)
                          && block_comp_dst[i] && lock_b_all[i];
end
//spylass enable block SelfDeterminedXpr-ML
// Reduction OR of bc_dst_int_b
assign bc_dst_int_ro_b = bc_dst_int_b;

//spylass disable block SelfDeterminedXpr-ML
//SM: Self determined block Expression present in the design.
//SJ: This Self Determined Expression is as per the design requirement.
/*
There will not be any functional issue.
*/
always @(ch_dms or tfr_comp_dst or lock_b_all)
begin
    integer i;
    for(i=0; i < `DMAH_NUM_CHANNELS; i=i+1)
        tfrc_dst_int_b[i] = ({ch_dms[2*i+1],ch_dms[2*i]} == MASTER_NUM)
                           && tfr_comp_dst[i] && lock_b_all[i];
end
//spylass enable block SelfDeterminedXpr-ML
// Reduction OR of tfrc_dst_int_b
assign tfrc_dst_int_ro_b = tfrc_dst_int_b;

//spylass disable block SelfDeterminedXpr-ML
//SM: Self determined block Expression present in the design.
//SJ: This Self Determined Expression is as per the design requirement.
/*
There will not be any functional issue.
*/
always @(ch_sms or tfr_comp_src_msk or lock_b_all)
begin
    integer i;
    for(i=0; i < `DMAH_NUM_CHANNELS; i=i+1)
        tfrc_src_int_b[i] = ({ch_sms[2*i+1],ch_sms[2*i]} == MASTER_NUM)
                           && tfr_comp_src_msk[i] && lock_b_all[i];
end
//spylass enable block SelfDeterminedXpr-ML
// Reduction OR of tfrc_src_int_b
assign tfrc_src_int_ro_b = tfrc_src_int_b;

// Since for all levels except the AMBA transfer level (Not supported)
// then will lock address phase of same cycle data phase
// will cause a phase of AH B bus for one extra cycle.
// This will always be a IDLE cycle with 0K. response so
// since lock for single req masking cycle. It de-asset at
// tfr dst int.ro for example and takes another 2 cycles
// for any channel to get onto AHB bus.
// Actually need to register block_clr to remove a very
// long timing path. Now at the AMBA transfer level the
// bus will be locked for one extra cycle and at the
// Register levels in the mbii will be locked for an extra 2 cycles.

always @(trans_c_src_ro_b or trans_c_dst_ro_b or 
         bc_dst_int_ro_b or bc_src_int_ro_b or tfrc_dst_int_ro_b
		 or tfrc_src_int_ro_b or lock_b_l_m_reg or same_layer_m_int
         or in_src_tran_m or in_dst_tran_m or clr_lock_error
         or ch_disabled_mask or can_goto_amba_m or lock_b_l_m_reg)
begin
    if(ch_disabled_mask || (can_goto_amba_m && (lock_b_l_m_reg != 2'b00)
       && (!same_layer_m_int)))
        hlock_clr = 1'b1;
    else
		if(lock_b_l_m_reg == 2'b10) // DMA transaction level
			if(!same_layer_m_int)
				hlock_clr = (trans_c_src_ro_b | trans_c_dst_ro_b) || clr_lock_error;
            else
                hlock_clr = ((trans_c_dst_ro_b & (!in_src_tran_m))
                           || (trans_c_src_ro_b & (!in_dst_tran_m))) || clr_lock_error;
        else if(lock_b_l_m_reg == 2'b01) // DMA block level
            if(same_layer_m_int)
                hlock_clr = bc_dst_int_ro_b || clr_lock_error;
            else
                hlock_clr = (bc_dst_int_ro_b | bc_src_int_ro_b) || clr_lock_error;
        else if( /* DMA transfer */ level)
				if (same_layer_m_int)
					hlock_clr = tfrc_dst_int_ro_b || clr_lock_error;
				else
					hlock_clr = (tfrc_dst_int_ro_b | tfrc_src_int_ro_b) || clr_lock_error;
end

// Lock ch1 int must be higher of lock_ch1 and lock_b1 if
// bus locking is enabled.
// If bus locking is enabled at a Layer and then bus locking
// level is higher than channel locking must be enabled at least up to that level.
// Lock ch1 decoding
// 00 = DMA transfer
// 01 = > Block
always @(lock_ch_m_reg)
begin: lock_ch_int_PROC
    lock_ch_int = lock_ch_m_reg;
end

always @(lock_l_m_reg)
begin: lock_ch_l_int_PROC
    lock_ch_l_int = lock_ch_l_m_reg;
end

always @(lock_ch_l_m_reg)
begin
    lock_ch_int_comb = lock_ch_1_m;
end

assign lock_ch_l_int_comb = lock_ch_l_m[1];

// Transaction level channel locking is different
// to block due to dma transfer channel locking. This difference
// arises due to as src blocks and dst blocks they always occur one after the
// other. The number of source and dst transactions may be
// unequal and can occur blocking in any order. Like block (and dma
// starts on a layer and channel locking is enabled at the transaction
// level then all requests bar the source and dst s/m requests of the
// channel in question masking are masked. When the source and dst end occurs
// when not in the middle of a dst transaction or when a dst end occurs
// when not in the middle of a src transaction.
// Block level masking is cleared at the end of the dst block if
// src and dst are on the same layer.
// When masking occur then end of transaction, block or dma transfer
// signals can only come from the offending channel. as all other channel
// s/m's are masked out.

// Why (can_goto_amba_m && lock_ch1_int == 2'b00) ?
// 1. can goto amba m can occur when
// 2. error response on src transfer
// 3. dst is flow controller. fmode = 0 and src block completes on same cycle
// as goto_amba state received by src s/m.
// For 3. then do not want to pulse clr mask_lck if transfer level channel
// locking enabled. If get error response and transfer level locking is been used
// then pulsing off ch disable mask will release locking ( since can_goto_amba_m
// tfr_dst_int ro will clear if src and dst are on the same layer and
// tfr_src_int ro if on different layers.
// 20-2003 Added (can_goto_amba_m && (lock_ch_l_int != 2'b00) && !same_layer_m_int))
// If on same layer and have condition 3 above then clr_mask_lck cleared
// before dst block completes. If on same layer then bc_dst_int_ro will
// clear the locking.

always @(lock_ch_l_int or trans_c_src_ro or trans_c_dst_ro
         or same_layer_m_int or bc_dst_int_ro or bc_src_int_ro
         or tfrc_src_int_ro or tfrc_dst_int_ro
         or in_src_tran_m or in_dst_tran_m or clr_lock_error
		 or ch_disabled_mask or can_goto_amba_m or lock_ch_l_int)
begin
    if(ch_disabled_mask || (can_goto_amba_m && (lock_ch_l_int != 2'b00)
       && (!same_layer_m_int)))
        clr_mask_lck = 1'b1;
    else if(lock_ch_l_int[1]) // transaction level
			if(!same_layer_m_int)
				clr_mask_lck = (trans_c_src_ro | trans_c_dst_ro) || clr_lock_error;
			else
				clr_mask_lck = ((trans_c_dst_ro & (!in_src_tran_m))
                           || (trans_c_src_ro & (!in_dst_tran_m))) || clr_lock_error;
    else if(lock_ch_l_int == 2'b01) // block level
        if(same_layer_m_int)
            clr_mask_lck = bc_dst_int_ro || clr_lock_error;
        else
            clr_mask_lck = (bc_dst_int_ro | bc_src_int_ro) || clr_lock_error;
    else // DMA transfer level
		if(same_layer_m_int)
			clr_mask_lck = tfrc_dst_int_ro || clr_lock_error;
		else
			clr_mask_lck = (tfrc_dst_int_ro | tfrc_src_int_ro) || clr_lock_error;
end

// Corner case: Dst is flow controller and pre-fetching enabled (fmode = 0). Src
// is requesting side. Already granted on same cycle as dma last FIFO asserted to
// the block to the destination. The previous tfr_req pulse is cancelled.
// can goto amba m is pulsed one the previous tfr_req. For DMS != SMS and a single
// cycles: 1st cycle before tfr_req and 2nd cycle on same cycle as tfr_req.
// hlock_clr follows this. However since this new tfr_req re-asserts block and this
// so also does then locking. The "tfr_src_int_ro_b_reg" in
// (lock_ch1_int != 2'b00 || tfr_src_int_ro_b_reg) & same_layer_m_int)
// detects this.
assign clr_mask_lck_on_can_dfc = can_goto_amba_m && tfrc_src_int_ro_b_reg && lock_ch_int && 
								 (lock_ch_l_int == 2'b00) && (!same_layer_m_int);

endmodule