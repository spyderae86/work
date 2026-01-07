//-----------------------------------------------------------------
//      module
//      test.com
//      Copyright 2025-2026
//      BSD
//-----------------------------------------------------------------
module DW_ahb_dmac_master_top
(
    // Outputs
    pop,
    push,
    pop_hld,
    pop_data_valid,
    update_state,
    dp_complete,
    granted_mi,
    grant_mi,
    grant_index_mi,
    hresp_int,
    hwrite,
    hprot,
    hsize,
    hburst,
    haddr,
    haddr_reg,
    hbusreq,
    hlock,
    htrans,
    hwdata,
    hgrant_int,
	hrdata_m,
    end_addr_phase1,
    end_addr_phase2,
    req_mi,
    mask_lck_ch,
//GH 9000047152
    ebt_event,
    lock_split_retry,
//--
    split_retry_reg,
    tfr_req,
    mask_ch_disable_hlock,

    // Inputs
    hclk,
    hresetn,
    req_sm,
    hready,
    hgrant,
    hresp,
    ch_prior,
    length,
    tfr_req_pre,
    st_addr,
    addr_ctrl,
    write,
    size,

    prot,
    data_in,
    dou_addr_inc_mi,
    hrdata,
    big_endian,
    lock_ch_l_m,
    lock_b_l_m,
    lock_b_m,
    lock_ch_m,
    in_src_tran_m,
    in_dst_tran_m,
    same_layer_m,
    trans_comp_src,
    trans_comp_dst,
    bcomp_red_src,
    block_comp_dst,
    tfr_comp_src,
    tfr_comp_dst,
    ch_sms,
    ch_dms,
    ch_ms,
    cancel_amba_req_m,
    can_goto_amba_m,
    src_is_mem,
    dst_is_mem,
    dma_data_req,
    dp_grt_align_m,
    lock_ch_all,
    lock_b_all,
    ch_enable,
    suspend,
    fifo_empty
    );

    // runtime parameters
    parameter MASTER_NUM = 0;
    parameter AHB_LITE = 0;
    parameter DMAH_HRESP_WIDTH = 2;
    parameter HDATA_WIDTH = 32;
    parameter DMAH_RELOAD_EN = 0;
    parameter DMAH_LOCK_EN = 0;
    parameter DMAH_NON_OK_EN_M = 0;
    //parameter DMAH_CANCEL_M = 0;
    parameter DMAH_MAX_BURST_LENGTH = 4;

    // Local parameters
    parameter AW = `DMAH_HADDR_WIDTH;
    parameter NP = `DMAH_NUM_PER;
    parameter L2_NP = `LOG2_DMAH_NUM_PER;


    // Outputs to Channel FIFO's

    output push;                  // asserted on data phase of AMBA read transfer
                                  // when hready is high to push hrdata onto the
                                  // channel FIFO

    output pop;                   // asserted on address phase of AMBA write transfer
                                  // when hready is high (previous transfer
                                  // completed) to pop data from the channel FIFO

    output pop_hld;               // asserted with pop and keep asserted till
                                  // pop data_valid asserted.

    output pop_data_valid;        // pop data valid asserted on same cycle as
                                  // successful completion of data phase of pop'ed
                                  // data. i.e data phase when hready is asserted
                                  // and hresp = o.k.


    // Outputs to Channel source and destination F.S.M.'s

    output update_state;          // allows transition into AMBA transfer
                                  // state) to allow new AMBA transfer request.

    output dp_complete;           // Pulsed on data phase of last beat of requested
                                  // transfer when hready is asserted.


    // AMBA Bus Outputs

    output hwrite; 
    output [3:0] hprot;
    output [2:0] hsize;
    output [2:0] hburst;
    output [AW-1:0] haddr;
    output [AW-1:0] haddr_reg;    // hready delayed version of haddr.
    output hbusreq;               // If 'DMAH_CONT_INCR = True' (default = False),
                                  // hbusreq de-asserted on the address phase
                                  // of the penultimate beat of the requested
                                  // transfer. Requested burst completes if data
                                  // phase of penultimate transfer not waited.
                                  // If not, the last beat of the requested transfer
                                  // is not transferred. Setting 'DMAH_CONT_INCR = True
                                  // removes IDLE cycle on bus handover after INCR burst
                                  // but causes ACT violation.

	output [1:0] hresp_int;
	output       hlock;
    output [1:0] htrans;          // Will never drive to 'Busy'
    output [HDATA_WIDTH-1:0] hwdata;


 //   output from Arbiter

    output granted_mi;              // Asserted when any requesting peripheral is
                                  // granted the master bus interface.

    output [NP-1:0] grant_mi;     // Currently granted request.

    output [L2_NP-1:0] grant_index_mi; // Index to currently granted request.

    output hgrant_int;            // hgrant driven continuously high for AMBA Lite
                                  // Master.

    output [HDATA_WIDTH-1:0] hrdata_m; // hrdata after endian mapping.

    output end_addr_phase1;       // Asserted on last address phase when
                                  // hready is high.

    output end_addr_phase2;       // Asserted on last address phase when
                                  // hready is high.

    output [`DMAH_NUM_PER-1:0] req_mi;

    output [`DMAH_NUM_PER-1:0] mask_lck_ch;

//GH 9000047152
    output ebt_event;
    output lock_split_retry;
//--
    output split_retry_reg;

    output tfr_req;

    output mask_ch_disable_hlock;


    // AMBA Bus Inputs

    input hclk;
    input hresetn;
    input hready;
    input hgrant;
    input [DMAH_HRESP_WIDTH-1:0] hresp;
	
	//inputs from dma_central_tfr_ctrl block


    input tfr_req_pre;            // Single pulse transfer request. All control
                                  // inputs pertinent to the requested transfer are
                                  // latched on this pulse i.e. length st_addr
                                  // addr_ctrl write size prot and lock. Asserted
                                  // when hready is high. i.e. on same cycle
                                  // as data phase completion of last beat of
                                  // previous transfer. st_addr will be driven onto
                                  // haddr bus on the cycle after tfr_req is pulsed.
                                  // Note that tfr_req will only be pulsed if
                                  // the master interface is granted control of
                                  // AHB bus when hready is high.

    input [`LENGTH_BW-1:0] length; // Indicates number of beats of requested
                                  // transfer. Valid on same cycle as tfr_req.

    input [AW-1:0] st_addr;        // Start address of requested transfer. Valid on
                                  // the same cycle as tfr_req.

    input [1:0] addr_ctrl;        // address increment, decrement or unchanged
                                  // 00 => Increment
                                  // 01 => Decrement
                                  // 1x => No change

    input write;                  // Valid on same cycle as tfr_req.
    input [2:0] size;             // Size of requested transfer. Valid on same cycle
                                  // as tfr_req.
    input [3:1] prot;             // Directly drives hprot bus. Valid on same cycle
                                  // as tfr_req.

    // Channel FIFO input

    input [HDATA_WIDTH-1:0] data_in; // data in from channel FIFO.

    // Channel priorities from channel memory block.

    input [3*`DMAH_NUM_CHANNELS-1:0] ch_prior;

    // Master select
    // ch_ms = {... ch1_dms_lli,ch1_sms,ch0_dmslli,ch0_sms}

    input [2*`DMAH_NUM_PER-1:0] ch_ms;

    // req inputs from channel source and destination s/m's.
    // req_sm[0] = channel 0 src
    // req_sm[1] = channel 0 destination
    // req_sm[2] = channel 1 src
    // req_sm[3] = channel 1 dest
    // etc.

// req_sm = {...,req_sm_dst_lli1,req_sm_src1,req_sm_dst_lli0,req_sm_src0}

input [NP-1:0] req_sm;

input dou_addr_inc_mi;        // Special case where address increment is
                              // twice hsize. (Normally address incremented
                              // according to hsize )

input [HDATA_WIDTH-1:0] hrdata; // From external hrdata bus.

input [1:0] lock_ch_l_m;      // from channel to master interface mux
input [1:0] lock_b_l_m;       // from channel to master interface mux
input lock_b_m;               // from channel to master interface mux
input lock_ch_m;              // from channel to master interface mux
input in_src_tran_m;          // from channel to master interface mux
input in_dst_tran_m;          // from channel to master interface mux
input same_layer_m;           // from channel to master interface mux
input [`DMAH_NUM_CHANNELS-1:0] trans_comp_src;  // from ch_tfr_ctrl
input [`DMAH_NUM_CHANNELS-1:0] trans_comp_dst;  // from ch_tfr_ctrl
input [`DMAH_NUM_CHANNELS-1:0] bcomp_red_src;   // from ch_tfr_ctrl
input [`DMAH_NUM_CHANNELS-1:0] block_comp_dst;  // from ch_tfr_ctrl
input [`DMAH_NUM_CHANNELS-1:0] tfr_comp_src;    // from ch_tfr_ctrl
input [`DMAH_NUM_CHANNELS-1:0] tfr_comp_dst;    // from ch_tfr_ctrl
input [2*`DMAH_NUM_CHANNELS-1:0] ch_sms;
input [2*`DMAH_NUM_CHANNELS-1:0] ch_dms;

input cancel_amba_req_m;      // Cancel requested AMBA transfer of requested
                              // length. Only occurs on source AMBA transfer
                              // when dst is flow controller.

// Instead of masking tfr_req ( not done directly due to critical path
// timing issues )
//   1) Mask out generation of a new tfr_req on the cycle
//      after the original tfr_req ( the one we wish to cancel).
//      This is done in the central tfr control block.
//   2) Cancel the tfr_req in the mbiu unit that was
//      started on the previous cycle.

input can_goto_amba_m;

// Big endian pin.

input big_endian;

input [`DMAH_NUM_CHANNELS-1:0] src_is_mem;
input [`DMAH_NUM_CHANNELS-1:0] dst_is_mem;

input [`DMAH_NUM_PER-1:0] dma_data_req;
input [`DMAH_NUM_PER-1:0] dp_grt_align_m;

input [`DMAH_NUM_CHANNELS-1:0] lock_ch_all;
input [`DMAH_NUM_CHANNELS-1:0] lock_b_all;

input [`DMAH_NUM_CHANNELS-1:0] ch_enable;

input [`DMAH_NUM_CHANNELS-1:0] suspend;
input [`DMAH_NUM_CHANNELS-1:0] fifo_empty;

wire [`DMAH_NUM_CHANNELS-1:0] suspend;
wire [`DMAH_NUM_CHANNELS-1:0] fifo_empty;
wire [`DMAH_NUM_CHANNELS-1:0] ch_enable;
wire [`DMAH_NUM_PER-1:0] dp_grt_align_m;
wire [HDATA_WIDTH-1:0] data_in_m; // data in from channel FIFO.
wire end_addr_phase1;         
wire end_addr_phase2;
wire hlock_clr;
wire lock_ch_int_comb;
wire clr_mask_lck;
wire clr_lock_error;

wire lock_ch_l_int_comb;

wire mask_lck_ch_en;
//wire first_cycle_non_ok;

wire [`DMAH_NUM_PER-1:0] req_mi;

wire [`DMAH_NUM_PER-1:0] mask_lck_ch;

wire split_retry;
wire split_retry_reg;

wire [`DMAH_NUM_CHANNELS-1:0] lock_ch_all;
wire [`DMAH_NUM_CHANNELS-1:0] lock_b_all;

wire ch_disabled_mask;
wire can_goto_amba_m;
wire req_mbiu;
wire clr_mask_lck_on_can_dfc;
wire hlock_clr_on_can_dfc;
wire req_mbiu_exclude_current;
wire can_goto_amba_m_no_susp;
wire tfr_req;
wire mask_ch_disable_hlock;

//GH 9000047152
//wire [DMAH_MAX_BURST_LENGTH:0] incomp_trans_beats;
wire ebt_event;
wire last_tfr;
wire lock_split_retry;
//---

// req_sm used in the generation of hbusreq. Peripheral's
// request bit is masked off
// if not assigned to this layer.

DW_ahb_dmac_mbiu
#(.AHB_LITE(AHB_LITE),.DMAH_HRESP_WIDTH(DMAH_HRESP_WIDTH),.HDATA_WIDTH(HDATA_WIDTH),
  .DMAH_RELOAD_EN(DMAH_RELOAD_EN),.DMAH_NON_OK_EN_M(DMAH_NON_OK_EN_M),
  .DMAH_LOCK_EN(DMAH_LOCK_EN),.DMAH_MAX_BURST_LENGTH(DMAH_MAX_BURST_LENGTH))
U_mbiu(

    // Outputs
    .push(push),
    .pop(pop),
    .pop_hld(pop_hld),
    .pop_data_valid(pop_data_valid),
    .update_state(update_state),
    .dp_complete(dp_complete),
    .hwrite(hwrite),
    .hprot(hprot),
    .hsize(hsize),
    .hburst(hburst),
    .haddr(haddr),
    .haddr_reg(haddr_reg),
    .hbusreq(hbusreq),
    .hresp_int(hresp_int),
    .hlock(hlock),
    .htrans(htrans),
    .hwdata(hwdata),
    .hgrant_int(hgrant_int),
    .end_addr_phase1(end_addr_phase1),
    .end_addr_phase2(end_addr_phase2),
    .clr_lock_error(clr_lock_error),
    //.first_cycle_non_ok(first_cycle_non_ok),
    .split_retry(split_retry),
    .split_retry_reg(split_retry_reg),
    .tfr_req(tfr_req),
    .mask_ch_disable_hlock(mask_ch_disable_hlock),
//GH 9000047152
    //.incomp_trans_beats(incomp_trans_beats),
    .last_tfr(last_tfr),
	.ebt_event(ebt_event),
    //---

    // Inputs
    .hclk(hclk),
    .hresetn(hresetn),
    .hready(hready),
    .hgrant(hgrant),
    .hresp(hresp),
    .tfr_req_pre(tfr_req_pre),
    .length_sm(length[DMAH_MAX_BURST_LENGTH:0]),
    .st_addr(st_addr),
    .addr_ctrl(addr_ctrl),
    .write(write),
    .size(size),
    .prot(prot),
    .lock_b_m(lock_b_m),
	.granted_mi (granted_mi),
	.data_in(data_in_m),
    .dou_addr_inc_mi(dou_addr_inc_mi),
    .hlock_clr(hlock_clr),
    .req_sm(req_sm),
    .cancel_amba_req_m(cancel_amba_req_m),
    .can_goto_amba_m(can_goto_amba_m),
    .ch_ms(ch_ms),
    .mask_lck_ch_en(mask_lck_ch_en),
    .ch_disabled_mask(ch_disabled_mask),
    .req_mbiu(req_mbiu),
    .hlock_clr_on_can_dfc(hlock_clr_on_can_dfc),
    .req_mbiu_exclude_current(req_mbiu_exclude_current)
);

//GH9000047152 : add parameter DMAH_MAX_BURST_LENGTH
DW_ahb_dmac_arb_top
#(.MASTER_NUM(MASTER_NUM),.DMAH_LOCK_EN(DMAH_LOCK_EN),.DMAH_NON_OK_EN_M(DMAH_NON_OK_EN_M),
  .DMAH_MAX_BURST_LENGTH(DMAH_MAX_BURST_LENGTH))
U_arb_top(

    // Outputs
    .granted_mi(granted_mi),
    .grant_mi(grant_mi),
    .grant_index_mi(grant_index_mi),
    .mask_lck_ch_en(mask_lck_ch_en),
    .req_mi(req_mi),
    .mask_lck_ch(mask_lck_ch),
    .ch_disabled_mask(ch_disabled_mask),
//GH 9000047152
    .lock_split_retry(lock_split_retry),
//---
    .req_mbiu(req_mbiu),
    .req_mbiu_exclude_current(req_mbiu_exclude_current),
    .can_goto_amba_m_no_susp(can_goto_amba_m_no_susp),

    // Inputs
    .hclk(hclk),
    .hresetn(hresetn),
    .hready(hready),
    .ch_ms(ch_ms),
    .req_sm(req_sm),
    .ch_prior(ch_prior),
    .lock_ch_int_comb(lock_ch_int_comb),
    .lock_ch_l_int_comb(lock_ch_l_int_comb),
    .clr_mask_lck(clr_mask_lck),
    .clr_mask_lck_on_can_dfc(clr_mask_lck_on_can_dfc),
    .tfr_req(tfr_req),
    .src_is_mem(src_is_mem),
    .dst_is_mem(dst_is_mem),
    .dma_data_req(dma_data_req),
// .lock_b_m(lock_b_m),
    .dp_grt_align_m(dp_grt_align_m),
    .split_retry(split_retry),
    .ch_enable(ch_enable),
    .suspend(suspend),
    .fifo_empty(fifo_empty),
//GH 9000047152
    .last_tfr(last_tfr),
// .incomp_trans_beats(incomp_trans_beats),
    .clr_lock_error(clr_lock_error),
    .can_goto_amba_m(can_goto_amba_m)
);

DW_ahb_dmac_mst_endian
#(.HDATA_WIDTH(HDATA_WIDTH))
U_mst_endian(

    // Outputs
    .data_in_endian(data_in_m),
    .hrdata_to_ch(hrdata_m),

    // Inputs
    .hclk(hclk),
    .hresetn(hresetn),
    .hsize(hsize),
    .hready(hready),
    .haddr_lob(haddr[4:0]),
    .big_endian(big_endian),
    .hrdata(hrdata),
    .data_in(data_in)
);

DW_ahb_dmac_lock_clr
#(.MASTER_NUM(MASTER_NUM),.DMAH_LOCK_EN(DMAH_LOCK_EN))
U_lock_clr(

    // Outputs
    .clr_mask_lck(clr_mask_lck),
    .hlock_clr(hlock_clr),
    .lock_ch_int_comb(lock_ch_int_comb),
    .lock_ch_l_int_comb(lock_ch_l_int_comb),
    .clr_mask_lck_on_can_dfc(clr_mask_lck_on_can_dfc),
    .hlock_clr_on_can_dfc(hlock_clr_on_can_dfc),

    // Inputs
    .hclk(hclk),
    .hresetn(hresetn),
    .trans_comp_src(trans_comp_src),
    .trans_comp_dst(trans_comp_dst),
    .bcomp_red_src(bcomp_red_src),
    .block_comp_dst(block_comp_dst),
    .tfr_comp_src(tfr_comp_src),
    .tfr_comp_dst(tfr_comp_dst),
    .same_layer_m(same_layer_m),
    .ch_sms(ch_sms),
    .ch_dms(ch_dms),
    .lock_ch_l_m(lock_ch_l_m),
    .lock_b_l_m(lock_b_l_m),
	.hc_lock_b_m(lock_b_m),
    .hc_lock_ch_m(lock_ch_m),
    .in_src_tran_m(in_src_tran_m),
    .in_dst_tran_m(in_dst_tran_m),
    .tfr_req(tfr_req),
    .clr_lock_error(clr_lock_error),
    .lock_ch_all(lock_ch_all),
    .lock_b_all(lock_b_all),
    .ch_disabled_mask(ch_disabled_mask),
    .mask_lck_ch(mask_lck_ch),
// .split_retry(split_retry),
    .can_goto_amba_m(can_goto_amba_m_no_susp)
);

endmodule

