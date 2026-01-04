//-----------------------------------------------------------------
//      module
//      test.com
//      Copyright 2025-2026
//      BSD
//-----------------------------------------------------------------
module DW_ahb_dmac_mbiu
  (

// Outputs
push,
pop,
pop_hld,
pop_data_valid,
update_state,
dp_complete,
hwrite,
hprot,
hsize,
hburst,
haddr,
haddr_reg,
hbusreq,
hresp_int,
hlock,
htrans,
hwdata,
hgrant_int,
end_addr_phase1,
end_addr_phase2,
clr_lock_error,
//first_cycle_non_ok,
split_retry,
split_retry_reg,
tfr_req,
mask_ch_disable_hlock,
//GH 9000047152
//incomp_trans_beats,
last_tfr,
ebt_event,
//---

// Inputs
hclk,
hresetn,
hready,
hgrant,
hresp,
tfr_req_pre,
length_sm,
st_addr,
addr_ctrl,
write,
size,
prot,
lock_b_m,
granted_mi,
data_in,
dou_addr_inc_mi,
hlock_clr,
req_sm,
cancel_amba_req_m,
can_goto_amba_m,
ch_ms,
mask_lck_ch_en,
ch_disabled_mask,
req_mbiu,
hlock_clr_on_can_dfc,
req_mbiu_exclude_current
);
// runtime parameters

parameter AHB_LITE = 0; // CC parameter, DMAH_Mx_AHB_LITE, for that master
// instance.

parameter DMAH_HRESP_WIDTH = 2; // CC parameter, DMAH_Mx_HRESP_WIDTH, for that master

// DMAH_Mx_HDATA_WIDTH for instantiated master.
parameter HDATA_WIDTH = 32;

//parameter MASTER_NUM = 0;

// Can any channel that can be assigned this master i/f enable reloading. Auto-align function
// only required when reloading enabled.

parameter DMAH_RELOAD_EN = 0;

// Can any channel that can be assigned this master i/f have non-ok responses enabled.

parameter DMAH_NON_OK_EN_M = 0;

// Can any channel that can be assigned this master i/f have locking enabled.

parameter DMAH_LOCK_EN = 0;

// Can any channel that can be assigned this master i/f cancel an already started AMBA burst.

//parameter DMAH_CANCEL_M = 0;

parameter DMAH_MAX_BURST_LENGTH = 4;

// Local parameters

parameter AW = `DMAH_HADDR_WIDTH;

// Outputs to Channel FIFO's

output               push; // asserted on data phase of AMBA read transfer
// when hready is high to push hrdata onto the
// channel FIFO

output               pop; // asserted on address phase of AMBA write transfer
// when hready is high ( previous transfer
// completed) to pop data from the channel FIFO.
// pop'ed data is registered ( asynchronous read from FIFO
// assumed ) to form hwdata.


output pop_hld; // asserted with pop and keep asserted till
// pop_data_valid asserted.

output               pop_data_valid; // pop_data_valid asserted on same cycle as
// successful completion of data phase of pop'ed
// data i.e. data phase when hready is asserted
// and hresp = O.K.


// Outputs to Channel source and destination F.S.M's

output               update_state; // Allows transition into S3 ( AMBA transfer
// state) to allow new AMBA transfer request.

output               dp_complete; // Pulsed on data phase of last beat of requested
// transfer when hready is asserted.


// AMBA Bus Outputs

output               hwrite;
output [3:0]         hprot;
output [2:0]         hsize;
output [2:0]         hburst;
output [AW-1:0]      haddr;
output [AW-1:0]      haddr_reg; // hready delayed version of haddr.
output               hbusreq; // If `DMAH_CONT_INCR = True hbusreq_int de-asserted on the address phase
// of the penultimate beat of the requested
// transfer. Requested burst completes if data
// phase of penultimate transfer not waited.
// If not, the last beat of the requested transfer
// is not transferred.

output [1:0]         hresp_int;
output               hlock;
output [1:0]         htrans; // Will never drive to 'Busy'
output [HDATA_WIDTH-1:0] hwdata;

output               hgrant_int; // Always asserted for AMBA LITE Master.


// end_addr_phase is a single pulse, pulsed on the last address phase
// of the requested transfer when hready is high

output               end_addr_phase1;
output               end_addr_phase2;

output               clr_lock_error;
// To DW_ahb_dmac_lock_clr block. Always clear the locking of the bus and channel arbiter
// for all transfer levels when an error response is received.


//output               first_cycle_non_ok;
output               split_retry;
output               split_retry_reg;
output               tfr_req;
output               mask_ch_disable_hlock;
// GH 9000047152
//output [DMAH_MAX_BURST_LENGTH:0] incomp_trans_beats;
// To arb_mask to lock channel until transfer completes
output               ebt_event; //To central_tfr_ctl to gate tfr_reg during ebt arb locking
output               last_tfr;   //To arb_mask to unlock the channel
//----


// AMBA Bus Inputs

input                hclk;
input                hresetn;
input                hready;
// spyglass disable block W240
// SMD: An input has been declared but is not read
// SC: The DW_ahb_dmac is a highly configurable IP, due to this in certain
// configuration this input port may not be used. But there will not be
// any functional issue.
input                hgrant;
// spyglass enable block W240
input [DMAH_HRESP_WIDTH-1:0] hresp;


// Inputs from dma_central_tfr_ctrl block


input tfr_req_pre; // Single pulse transfer request. All control
// inputs pertinent to the requested transfer are
// latched on tfr_req pulse i.e. length_int,st_addr,
// addr_ctrl,write,size,prot and lock. tfr_req is asserted
// when hready is high, i.e. on same cycle
// as data phase completion of last beat of
// previous transfer. st_addr will be driven onto
// haddr bus on the cycle after tfr_req is pulsed.
// Note that tfr_req will only be pulsed if
// the master interface is granted control of
// AHB bus when hready is high.


input [DMAH_MAX_BURST_LENGTH:0] length_sm; // Indicates number of beats of requested
// transfer. Valid on same cycle as tfr_req.


input [AW-1:0] st_addr; // Start address of requested transfer. Valid on
// the same cycle as tfr_req.


input [1:0] addr_ctrl; // address increment,decrement or unchanged
// 00 => Increment
// 01 => Decrement
// 1x => No change


input write; // Valid on same cycle as tfr_req.
input [2:0] size; // Size of requested transfer. Valid on same cycle
// as tfr_req.
input [3:1] prot; // Directly drives hprot bus. Valid on same cycle
// as tfr_req.
input lock_b_m; // Requested transfer is to be locked on the
// AMBA bus. Valid on same cycle as tfr_req.


// Input from Arbiter


//spyglass disable_block W240
//SMD: An input has been declared but is not read
//SJ: The DW_ahb_dmac is a highly configurable IP, due to this in certain
// configuration this input port may not be used. But there will not be
// any functional issue.
//
input granted_mi; // Asserted when any requesting peripheral is
// granted the master bus interface.
//spyglass enable_block W240


// Channel FIFO input


input [HDATA_WIDTH-1:0] data_in; // data in from channel FIFO.


input dou_addr_inc_mi; // Special case where address increment is
// twice hsize ( Normally address incremented
// according to hsize ). Only occurs when control and destination status
// are been written back to system memory and the source status is not been
// written back.


//spyglass disable_block W240
//SMD: An input has been declared but is not read
//SJ: The DW_ahb_dmac is a highly configurable IP, due to this in certain
// configuration this input port may not be used. But there will not be
// any functional issue.
//
input hlock_clr; // Clear hlock. Once hlock is set then
// it remains set until hlock_clr is asserted to clear it.
//spyglass enable_block W240


//spyglass disable_block W240
//SMD: An input has been declared but is not read
//SJ: The DW_ahb_dmac is a highly configurable IP, due to this in certain
// configuration this input port may not be used. But there will not be
// any functional issue.
//
input [DMAH_NUM_PER-1:0] req_sm; // S/M request for mbiu. Used to generate hbusreq
//spyglass enable_block W240


input cancel_amba_req_m; // Cancel requested AMBA transfer of requested
// length_int. Only occurs on source AMBA transfer
// when dst is flow controller or when error response received by
// source/destination peripheral (on different layer) when destination/source active on this layer.


    //spyglass disable_block W240
    //SMD: An input has been declared but is not read
    //SJ: The DW_ahb_dmac is a highly configurable IP, due to this in certain
    //    configuration this input port may not be used. But there will not be
    //    any functional issue.
    input [2*DMAH_NUM_PER-1:0]    ch_ms;
    //spyglass enable_block W240

    input                            mask_lck_ch_en;

    // Instead of masking tfr_req ( not done directly due to critical path
    // timing issues )
    //
    //   1) Mask out generation of a new tfr_req on the cycle
    //      after the original tfr_req (the one we wish to cancel).
    //      This is done in the central tfr control block.
    //
    //   2) Cancel the tfr_req in the mbiu unit that was
    //      started on the previous cycle.
    //

    //spyglass disable_block W240
    //SMD: An input has been declared but is not read
    //SJ: The DW_ahb_dmac is a highly configurable IP, due to this in certain
    //    configuration this input port may not be used. But there will not be
    //    any functional issue.
    input                            can_goto_amba_m;
    input                            ch_disabled_mask;
    //spyglass enable_block W240

    input                            req_mbiu;
    input                            hlock_clr_on_can_dfc;

    // req_mbiu_exclude_current asserted if any state machine other than the
    // currently granted state machine has it's request line asserted. hbusreq is kept asserted
    // after current INCR transfer if this signal is asserted.
    input                            req_mbiu_exclude_current;


    wire                             end_addr_phase_int;
    wire                             update_state;
    wire                             dp_complete;
    wire                             pop;
    reg                              pop_hld;
    wire                             pop_data_valid;
    wire                             push;
    wire [AW-1:0]                    haddr_pre;
    wire [1:0]                       hresp_int;
    wire                             end_addr_3;
    wire                             end_addr_2;
    wire [AW-1:0]                    st_addr_used;
    wire [2:0]                       size_int;
    wire                             num_adr_to_comp_eq_0;
    wire                             num_adr_to_comp_eq_1;
    wire                             num_adr_to_comp_eq_2;
    wire                             num_adr_to_comp_eq_3;
    wire [1:0]                       addr_ctrl_pre;
    wire                             clr_lock_error;
    wire                             hlock_clr_int;
    wire                             split_retry;
    wire                             insert_idle_hreg;
    wire                             insert_idle;
    wire                             mask_lck_ch_en_hreg_pre;
    wire                             mask_lck_ch_en_hreg;
    wire                             haddr_1k_pre;
    wire                             tfr_req;
    wire [DMAH_MAX_BURST_LENGTH:0]   length_int;
    wire                             htrans_hreg_ni;
    wire                             deassert_on_tfr_req;
    wire                             hbusreq_clr;
    wire                             can_goto_amba_m_h;
    wire                             can_goto_amba_m_int;
    wire                             cancel_amba_req_m_h;
    wire                             not_aligned;
    wire                             split_retry_reg;
    wire                             non_ok_mask_reg;
    wire                             mask_lck_ch_en_hreg_reg;
    wire                             mask_lck_ch_en_hr;
    wire                             hlock;
    wire                             insert_idle_hr;
    wire                             hlock_hready_reg;
    wire                             sec_cycle_non_ok;
    wire                             incr_bursts;
    wire                             end_addr_phase1;
    wire                             end_addr_phase2;
    wire                             mask_ch_disable_hlock;

    //GH 9000047152
    //----- added for ebt event-----
    wire [DMAH_MAX_BURST_LENGTH:0]   length_used;
    //GH 9000047152
    //----- added for defined length burst-----

    //----- added for defined length burst-----
    wire                             last_tfr;
    wire [2:0]                       hsize_pre;
    wire                             first_cycle_non_ok;
    wire [8:0]                       hdata_w;

    reg  [10:0]                      beats_to_1k_boundary;
    reg                              last_tfr_i;
    reg  [2:0]                       hc_hburst_prev;
    reg                              dp_last;
    //----------------------------------------

    reg                              end_addr_phase;
    reg                              hc_mask_lck_ch_en_hreg_reg;
    reg                              hc_insert_idle_hr;
    reg                              hc_non_ok_mask_reg;
    reg                              hwrite;
    reg  [3:0]                       hprot;
    reg  [2:0]                       hsize;
    reg  [1:0]                       addr_ctrl_req;
    reg  [DMAH_MAX_BURST_LENGTH:0]   num_adr_to_comp;

    //GH 9000047152
    //----- added for ebt event-----
    reg  [DMAH_MAX_BURST_LENGTH:0]   num_adr_to_comp_reg;
    reg  [DMAH_MAX_BURST_LENGTH:0]   incomp_trans_beats;
    reg                              ebt_event;
    reg                              ebt_event_reg;
    reg                              hgrant_int_reg;
    //----------------------------------------

    reg  [AW-1:0]                    next_addr;
    reg  [1:0]                       htrans;
    reg                              tfr_req_reg;
    reg                              sgl_no_wait;
    reg                              dp_complete_pre;
    reg  [HDATA_WIDTH-1:0]           hwdata;
    reg                              pop_dat_vld_pre ;
    reg                              data_complete;
    reg                              hwrite_delay;
    reg  [AW-1:0]                    haddr;
    reg  [AW-1:0]                    haddr_reg;
    reg                              hc_hlock;
    reg                              hbusreq_int;
    reg                              dou_add_inc_reg;
    reg                              hc_not_aligned;
    reg  [AW-1:0]                    st_addr_align;
    reg                              hc_hlock_hready_reg;
    reg                              hc_split_retry_reg;
    reg                              hc_mask_lck_ch_en_hr;
    reg                              htrans_hr_ni;
    reg                              hc_sec_cycle_non_ok;
    reg                              addr_complete;
    reg                              deassert_on_tfr_req_d;
    reg  [2:0]                       burst_type;
    reg  [DMAH_MAX_BURST_LENGTH:0]   length;
    reg  [2:0]                       hc_hburst;

reg    hc_mask_ch_disable_hlock;



parameter HOK = 2'b00;
parameter HERROR    = 2'b01;
parameter HRETRY    = 2'b10;
parameter HSPLIT    = 2'b11;



parameter HS_BYTE    = 3'b000;
parameter HS_HALFWORD    = 3'b001;
parameter HS_WORD    = 3'b010;
parameter HS_DOUBLE_WORD    = 3'b011;
parameter HS_WORD_LINE_4    = 3'b100;
parameter HS_WORD_LINE_8    = 3'b101;

parameter UNDEFINED_LEN_BURST    = 3'b001;
parameter DEFINED_LEN_16    = 3'b111;
parameter DEFINED_LEN_8    = 3'b101;
parameter DEFINED_LEN_4    = 3'b011;
parameter DEFINED_SINGLE    = 3'b000;

parameter IDLE    = 2'b00;
parameter NONSEQ    = 2'b10;
parameter SEQ    = 2'b11;

assign hdata_w = HDATA_WIDTH;

// To improve timing gating of tfr_req with hready has been moved from the
// central_tfr_ctl block to here.
assign tfr_req = tfr_req_pre && hready;

// Generate hburst. If 'DMAH_INCR_BURSTS == 1 then only INCR undefined length
// bursts are supported. If 'DMAH_INCR_BURSTS == 0 then only defined length
// bursts are supported.
// GH 9000047152
// For defined length bursts we need to decide where the 1k boundary is
// and select the maximum defined length burst that doesn't cross the
// boundary
// the algorithm will calculate the number of beats remaining before
// the 1k boundary.
assign incr_bursts = 1'b1;

//---gh start modification for defined length burst---
assign hsize_pre = { tfr_req } ? size_int : hsize;

//spyglass disable_block SelfDeterminedExpr-ML
//SMD: Self determined expression present in the design.
//SJ: This Self Determined Expression is as per the design requirement.
// There will not be any functional issue.
// Calculate shift to implement (8/HSIZE)
// shift right by log2(HSIZE) - log2(8)
// (1k boundary - HADDR) * (8/HSIZE) = Beats to 1k boundary
always @(*) begin
    case(hsize_pre)
        HS_BYTE        : beats_to_1k_boundary = (11'h400 - {1'b0, haddr_pre[9:0]});
        HS_HALFWORD    : beats_to_1k_boundary = (11'h400 - {1'b0, haddr_pre[9:0]}) >> 1;
        HS_WORD        : beats_to_1k_boundary = (11'h400 - {1'b0, haddr_pre[9:0]}) >> 2;
        HS_DOUBLE_WORD : beats_to_1k_boundary = (11'h400 - {1'b0, haddr_pre[9:0]}) >> 3;
        HS_WORD_LINE_4 : beats_to_1k_boundary = (11'h400 - {1'b0, haddr_pre[9:0]}) >> 4;
        HS_WORD_LINE_8 : beats_to_1k_boundary = (11'h400 - {1'b0, haddr_pre[9:0]}) >> 5;
        default        : beats_to_1k_boundary = (11'h400 - {1'b0, haddr_pre[9:0]}) >> 5; // Max HDATA_WIDTH is 256
    endcase
end
//spyglass enable_block SelfDeterminedExpr-ML

// (1k boundary - HADDR) * (8/HSIZE) = Beats to 1k boundary
// assign beats_to_1k_boundary = (11'h400 - {1'b0, haddr_pre[9:0]}) >> shift_down;

//--gh Use incomplete trans length in the case of a split/retry or ebt
assign length_used = (incomp_trans_beats >= {{(DMAH_MAX_BURST_LENGTH){1'b0}}, 1'b1}) ? incomp_trans_beats : length_sm;


//spyglass disable_block W163
//SMD: Truncation of bits in constant integer conversion.
//SJ: The assignments are validated for width mismatches and they are as per the requirement. Hence this can be waived.
always @(length_used or incr_bursts or beats_to_1k_boundary or addr_ctrl_pre)
begin : hc_length_PROC
    if(incr_bursts || (|addr_ctrl_pre))
    begin
        length = length_used;
        burst_type = UNDEFINED_LEN_BURST;
    end
    else if(length_used >= 16 && beats_to_1k_boundary >= 16)
    begin
        length = 16;
        burst_type = DEFINED_LEN_16;
    end
    else if(length_used >= 8 && beats_to_1k_boundary >= 8)
    begin
        length = 8;
        burst_type = DEFINED_LEN_8;
    end
    else if(length_used >= 4 && beats_to_1k_boundary >= 4)
    begin
        length = 4;
        burst_type = DEFINED_LEN_4;
    end
    else
    begin
        length = 1;
        burst_type = DEFINED_SINGLE;
    end
end
//spyglass enable_block W163
//---

always @(posedge hclk or negedge hresetn)
begin : hc_hburst_PROC
    if(hresetn == 1'b0)
        hc_hburst <= 3'b000;
    else if(tfr_req)
        hc_hburst <= burst_type;
    else
        hc_hburst <= hburst;
end

assign hburst = UNDEFINED_LEN_BURST;

// Want to hardcode size[2] if (HDATA_WIDTH <= 64)
// to allow for logic optimization.
generate
  if (HDATA_WIDTH <= 64) begin : m1
    assign size_int = {1'b0,size[1:0]};
  end
  else begin : m2
    assign size_int = size;
  end
endgenerate

// Mask off hresp to OK if not a response from a non-idle
// transfer from this master.
generate
  if (DMAH_NON_OK_EN_M) begin : m3
    if (DMAH_HRESP_WIDTH==2) begin : GEN_NO_SCALAR_HRESP
      assign hresp_int = ((data_complete) ? HOK : (AHB_LITE) ? {1'b0,hresp[0]} : hresp);
    end
    else begin : GEN_SCALAR_HRESP
      assign hresp_int = ((data_complete) ? HOK : {1'b0,hresp});
    end
  end
  else begin : m4
    assign hresp_int = HOK;
  end
endgenerate

// The number of beats left to complete a burst is stored in num_adr_to_comp.
// The maximum possible burst size is when hsize = HS_BYTE and the FIFO is been
// completely filled or emptied, i.e. if HDATA_WIDTH = 32
// ( = FIFO width ) and FIFO_Depth is 16, then for hsize = HS_BYTE then
// the maximum possible burst length_int = 32/8 * 16.
// The maximum such value for each channel's source or destination that can be assigned
// this master interface is used to calculate num_adr_to_comp bus width.

// Mask non ok hresp from data phase of AMBA beat which
// is not associated with the CURRENT tfr_req, i.e. last data
// phase from previous transfer ( either different channel, same
// channel different peripheral or external bus master on
// bus handover.

always @(posedge hclk or negedge hresetn)
  begin : num_adr_to_comp_PROC
    if(hresetn == 1'b0)
      num_adr_to_comp <= {(DMAH_MAX_BURST_LENGTH+1){1'b0}};
    else if(!hgrant_int && hready)
      num_adr_to_comp <= {(DMAH_MAX_BURST_LENGTH+1){1'b0}};
    else if(!addr_complete)
      begin
        if(!hready && (hresp_int != HOK))
          num_adr_to_comp <= {{(DMAH_MAX_BURST_LENGTH){1'b0}},1'b1};
        else if(can_goto_amba_m_h)
          //num_adr_to_comp <= 1;
          num_adr_to_comp <= {(DMAH_MAX_BURST_LENGTH+1){1'b0}};
        else if(cancel_amba_req_m_h && (!tfr_req))
          num_adr_to_comp <= {{(DMAH_MAX_BURST_LENGTH){1'b0}},1'b1};
        else if(tfr_req)
          num_adr_to_comp <= length_int;
        else if(hready && (!num_adr_to_comp_eq_0))
          num_adr_to_comp <= num_adr_to_comp -1;
      end
    else if(can_goto_amba_m_h)
      //num_adr_to_comp <= 1;
      num_adr_to_comp <= {(DMAH_MAX_BURST_LENGTH+1){1'b0}};
    else if(cancel_amba_req_m_h && (!tfr_req))
      num_adr_to_comp <= {{(DMAH_MAX_BURST_LENGTH){1'b0}},1'b1};
    else if(tfr_req)
      num_adr_to_comp <= length_int;
    else if(hready && (!num_adr_to_comp_eq_0))
      num_adr_to_comp <= num_adr_to_comp -1;
  end

//spyglass disable_block W528
//SMD : A signal or variable is set but never read
//SJ  : The DW_ahb_dmac is a highly configurable IP, due to this in certain
//    configuration few signals are driven, but may not be read.
//    But there will not be any functional issue.
always @(posedge hclk or negedge hresetn)
  begin : hc_non_ok_mask_reg_PROC
    if(hresetn == 1'b0)
      hc_non_ok_mask_reg <= 1'b0;
    else if((!hready && (hresp_int != HOK)))
      hc_non_ok_mask_reg <= 1'b1;
    else
      hc_non_ok_mask_reg <= 1'b0;
  end
//spyglass enable_block W528

generate
  if (DMAH_NON_OK_EN_M) begin : m5
    assign non_ok_mask_reg = hc_non_ok_mask_reg ;
  end
  else begin : m6
    assign non_ok_mask_reg = 1'b0;
  end
endgenerate

assign num_adr_to_comp_eq_0 = ( num_adr_to_comp == 0 );
assign num_adr_to_comp_eq_1 = ( num_adr_to_comp == 1 );
assign num_adr_to_comp_eq_2 = ( num_adr_to_comp == 2 );
assign num_adr_to_comp_eq_3 = ( num_adr_to_comp == 3 );

// end_addr_phase_int is a single pulse, pulsed on the last address phase
// of the requested transfer when hready is high
assign end_addr_phase_int = (num_adr_to_comp_eq_1 && hready);

always @(num_adr_to_comp_eq_1 or hready or hresp_int or addr_complete)
  begin : end_addr_phase_PROC
    if(num_adr_to_comp_eq_1 && hready)
      end_addr_phase = 1'b1;
    else if(!addr_complete)
      end_addr_phase = ((!hready && (hresp_int != HOK)));
    else
      end_addr_phase = 1'b0;
  end

// For improvements to critical timing I want to gate end_addr_phase with
// hready in the channel blocks. To do this I need to split the end_addr_phase
// signal in two and re-combine in the channel block.

assign end_addr_phase1 = num_adr_to_comp_eq_1;
assign end_addr_phase2 = (!addr_complete) && (hresp_int != HOK);

// end_addr is asserted for all cycles when the last address of the requested
// tranfer is been driven onto the haddr bus.

// addr_complete is asserted when there is no active address phase be driven
// from the master bus interface.

always @(num_adr_to_comp_eq_0 or num_adr_to_comp_eq_1 or
         cancel_amba_req_m_h or tfr_req or non_ok_mask_reg)
  begin : addr_complete_PROC
    if(num_adr_to_comp_eq_0)
      addr_complete = 1'b1;
    else if(num_adr_to_comp_eq_1 && (cancel_amba_req_m_h && (!tfr_req)))
      addr_complete = 1'b1;
    else if(non_ok_mask_reg)
      addr_complete = 1'b1;
    else
      addr_complete = 1'b0;
  end

// end_addr_3 is asserted when the 3rd from last address of the
// requested transfer is been driven onto haddr bus. Not sampled
// when length_int = 1 or length_int = 2.

assign end_addr_3 = ( num_adr_to_comp_eq_3 && hready &&
                     `DMAH_CONTINUE_INCR );

assign end_addr_2 = (num_adr_to_comp_eq_2 && hready &&
                     ( `DMAH_CONTINUE_INCR == 0 ));

// end_addr_3 is used to de-assert the AMBA hbusreq_int if no
// pending AMBA transfers
// are present after the completion of the current transfer
// (req_mbiu = 0, from all other s/m's). For a transfer of length_int = 1 or 2, hbusreq_int is
// de-asserted on the first address phase whether hready is high or
// low. For a requested transfer where length_int > 2,
// then hbusreq_int is deasserted
// when the penultimate address of the requested transfer is driven onto
// haddr bus if `DMAH_CONTINUE_INCR = True. Note that the requested transfer will complete if the
// penultimate data phase is not wait stated. If the
// penultimate data phase is wait stated then the last beat of the burst
// may be complete.

// In DW_ahb_dmac_arb_req_mi block |mask_lck_ch is asserted the
// cycle after tfr_req when a channel/bus is locked. In cases
// where channel is programmed for channel locking
// only ( bus locking not enabled ) then only requests
// from the locking channel should cause hbusreq to be asserted.
// |mask_lck_ch forces req_mbiu exclude current to be
// de-asserted the cycle after tfr_req of the first
// transfer of the programmed locking level when channel locking
// is enabled. This is used to clear hbusreq when length = 1 or
// length = 2 for current transfer.


// Once hbusreq is asserted then it remains asserted until
// the end of an AMBA burst occurs if no other request
// is asserted. So say a state machine has it's request
// line asserted and this causes the assertion of hbusreq.
// Now s/w disables the channel before hgrant is asserted.
// Then hbusreq will remain asserted even though the channel
// has been disabled by software. So need to clear this hbusreq.
// This is how : If  req_mbiu == 0 then this should clear
// hbusreq IF there is no active burst on the bus i.e. If
// htrans == IDLE && !tfr_req && if !(htrans == IDLE && tfr_req_req),
// 1st cycle of locked transfer is IDLE.

// 13-8-2004 changed !insert_idle_hr -> (!insert_idle_hr || can_goto_amba_m)
// Was getting a idle cycle inserted when tfr_req for a locked transfer was
// received and a can_goto_amba_m was also received. The !insert_idle_hr was
// masking off the hbusreq_clr.

assign hbusreq_clr = (((htrans == IDLE) && (!tfr_req)) &&
                     (!insert_idle_hr || can_goto_amba_m_int)) && (!req_mbiu);

always @(posedge hclk or negedge hresetn)
  begin : deassert_on_tfr_req_d_PROC
    if(hresetn == 1'b0)
      deassert_on_tfr_req_d <= 1'b0;
    else
      deassert_on_tfr_req_d <= deassert_on_tfr_req;
  end

assign deassert_on_tfr_req = (tfr_req && ((length_int == 1) ||
                                          ((length_int == 2) && `DMAH_CONTINUE_INCR)));

// If DMAH_CONTINUE_INCR = True (default = False) then :
// hbusreq_int removed on penultimate address phase. If penultimate
// data phase waited then final beat may not complete due
// to loss of bus ownership. This results in ACT violation but saves a cycle on
// bus handover after INCR bursts.

//spyglass disable_block W528
//SMD : A signal or variable is set but never read
//SJ  : The DW_ahb_dmac is a highly configurable IP, due to this in certain
//    configuration few signals are driven, but may not be read.
//    But there will not be any functional issue.
always @(posedge hclk or negedge hresetn)
  begin : hbusreq_int_PROC
    if(hresetn == 1'b0)
      hbusreq_int <= 1'b0;
    else if(split_retry) // First cycle of split response
      hbusreq_int <= 1'b0;
    else if((deassert_on_tfr_req || deassert_on_tfr_req_d) && (!req_mbiu_exclude_current))
      hbusreq_int <= 1'b0;
    else if(req_mbiu)
      hbusreq_int <= 1'b1;
    else if(first_cycle_non_ok && (!split_retry)) // Error response
      hbusreq_int <= 1'b0;
    else if(!hgrant_int && hready)
      hbusreq_int <= 1'b0;
    else if(can_goto_amba_m_h)
      hbusreq_int <= 1'b0;
    else if(cancel_amba_req_m_h && (!tfr_req))
      hbusreq_int <= 1'b0;
    else if(( `DMAH_CONTINUE_INCR == 0 ) && end_addr_2)
      hbusreq_int <= 1'b0;
    else if(( `DMAH_CONTINUE_INCR && end_addr_3))
      hbusreq_int <= 1'b0;
    else if(hbusreq_clr)
      hbusreq_int <= 1'b0;
  end
//spyglass enable_block W528

always @(posedge hclk or negedge hresetn)
  begin : tfr_req_reg_PROC
    if(hresetn == 1'b0)
      tfr_req_reg <= 1'b0;
    else
      tfr_req_reg <= tfr_req;
  end
  
// update_state is a single pulse control single outputted to the
// DW_ahb_dmac_central_tfr_ctrl block.
// update_state must
// be pulsed for a transition into the 'AMBA_STATE' in the source and
// destination s/m's to occur. The master interface
// is performing a AMBA
// transfer on behalf of the peripheral when the peripheral s/m is in it's "AMBA_STATE".
// update_state is also used in the generation of tfr_req. A tfr_req will not
// be generated by another peripheral until update_state is pulsed.

// sgl_no_wait is asserted when the transfer request is for a single transfer and
// when the address phase of that single transfer is not wait stated.
// one cycle of latency inserted.

// Note that when tfr_req_reg and end_addr_phase_int are asserted on the same cycle
// then this cycle is the address phase of a single transfer and hready is high.
// i.e. previous data phase is not wait stated.

always @(posedge hclk or negedge hresetn)
  begin : sgl_no_wait_PROC
    if(hresetn == 1'b0)
      sgl_no_wait <= 1'b0;
    else
      sgl_no_wait <= tfr_req_reg && end_addr_phase_int;
  end

// Move gating of update_state with hready to DW_ahb_central_tfr_ctrl path as
// this will improve critical timing. Why ? As hready is on the critical path then moving all
// gating of control signals with hready closer to a path's timing endpoint will improve the
// critical path timing

// assign update_state = sgl_no_wait || (end_addr_phase_int && !tfr_req_reg);

assign update_state = sgl_no_wait || (num_adr_to_comp_eq_1 && (!tfr_req_reg));

// dp_complete is asserted on the same cycle as the last data phase of
// the requested transfer when hready is high.

always @(posedge hclk or negedge hresetn)
  begin : dp_complete_pre_PROC
    if(hresetn == 1'b0)
      dp_complete_pre <= 1'b0;
    else if(end_addr_phase || (!hgrant_int && hready) || can_goto_amba_m_h)
      dp_complete_pre <= 1'b1;
    else if(dp_complete)
      dp_complete_pre <= 1'b0;
  end

assign dp_complete = dp_complete_pre && hready;

// Align starting address with hsize. This may not be the case
// when using multi-block transfers where the address is contiguous
// and the FIFO is flushed on the end of the previous block.
// e.g. STW = 8, DTW = 16 and BLOCK_TS = 5 and DAR = 2. Then
// last AMBA transfer of 1st block to destination is
// hsize = 0 ( byte ) to flush the FIFO and the stored address
// that will be used as first address of next block ( for contiguous
// transfers ) = 7. This is not aligned to DTW = 16.
// Only occurs when reloaded is enabled.
// What if block 1 has SRC_TR_WIDTH = 8, BLOCK_TS = 5, and Block 2 has
// SRC_TR_WIDTH = 32 when SAR is contiguous ? The address will be misaligned.
// The DMA realigns it.

//spyglass disable_block NoAssignX-ML W443
//SMD: Ensure RHS of the assignment does not contains 'X'
//SJ: Based on the configurations chosen, the unused signals in the current
//    configuration are driven to x, and others are driven with the correct
//    values. There will not be any functional issue. Hence this can be waived.
//spyglass disable_block W528
//SMD : A signal or variable is set but never read
//SJ : The DW_ahb_dmac is a highly configurable IP, due to this in certain
//    configuration few signals are driven, but may not be read.
//    But there will not be any functional issue.
always @(*)
  begin : hc_not_aligned_PROC
    case(size_int)
      HS_BYTE       : hc_not_aligned = 1'b0; // 8
      HS_HALFWORD   : hc_not_aligned = (st_addr[0] != 1'b0); // 16
      HS_WORD       : hc_not_aligned = (st_addr[1:0] != 2'b00); // 32
      HS_DOUBLE_WORD: hc_not_aligned = (hdata_w >= 64) ? (st_addr[2:0] != 3'b000) : 1'bx;
      HS_WORD_LINE_4: hc_not_aligned = (hdata_w >= 128) ? (st_addr[3:0] != 4'b0000) : 1'bx;
      default       : hc_not_aligned = (hdata_w == 256) ? (st_addr[4:0] != 5'b00000) : 1'bx;
    endcase
  end
//spyglass enable_block W528
//spyglass enable_block NoAssignX-ML W443

//spyglass disable_block W528
//SMD : A signal or variable is set but never read
//SJ : The DW_ahb_dmac is a highly configurable IP, due to this in certain
//    configuration few signals are driven, but may not be read.
//    But there will not be any functional issue.

generate
  if (DMAH_RELOAD_EN) begin : m7
    assign not_aligned = hc_not_aligned ;
  end
  else begin : m8
    assign not_aligned = 1'b0;
  end
endgenerate
//spyglass enable_block W528

// This is required to align the address to the transfer size.
// When tfr_req is asserted must use the unregistered
// value, addr_ctrl_pre, as haddr must be valid on the next cycle.

// Could push this alignment phase into channel block. But
// then would have to duplicate this logic for each src/dst of
// each channel.

//spyglass disable_block SelfDeterminedExpr-ML
//SMD: Self determined expression present in the design.
//SJ: This Self Determined Expression is as per the design requirement.
//    There will not be any functional issue.
//spyglass disable_block W528
//SMD : A signal or variable is set but never read
//SJ : The DW_ahb_dmac is a highly configurable IP, due to this in certain
//    configuration few signals are driven, but may not be read.
//    But there will not be any functional issue.
always @(*)
  begin : st_addr_align_PROC
    case({size_int,addr_ctrl_pre[0]})
      4'b0010: st_addr_align = {(st_addr[AW-1:1] + 1),1'b0};
      4'b0100: st_addr_align = {(st_addr[AW-1:2] + 1),2'b00};
      4'b0110: st_addr_align = {(st_addr[AW-1:3] + 1),3'b000};
      4'b1000: st_addr_align = {(st_addr[AW-1:4] + 1),4'b0000};
      4'b1010: st_addr_align = {(st_addr[AW-1:5] + 1),5'b00000};
      4'b0011: st_addr_align = {(st_addr[AW-1:1]),1'b0};
      4'b0101: st_addr_align = {(st_addr[AW-1:2]),2'b00};
      4'b0111: st_addr_align = {(st_addr[AW-1:3]),3'b000};
      4'b1001: st_addr_align = {(st_addr[AW-1:4]),4'b0000};
      default: st_addr_align = {(st_addr[AW-1:5]),5'b00000};
    endcase
  end
//spyglass enable_block W528
//spyglass enable_block SelfDeterminedExpr-ML

//spyglass disable_block W528
//SMD : A signal or variable is set but never read
//SJ : The DW_ahb_dmac is a highly configurable IP, due to this in certain
//    configuration few signals are driven, but may not be read.
//    But there will not be any functional issue.
generate
  if (DMAH_RELOAD_EN) begin : m9
    assign st_addr_used = (not_aligned) ? st_addr_align : st_addr;
  end
  else begin : m10
    assign st_addr_used = st_addr;
  end
endgenerate
//spyglass enable_block W528

endgenerate
//spyglass enable_block W528

// The starting address of the requested transfer is latched from st_addr
// when tfr_req is pulsed. The haddr bus is fixed for the duration of the
// requested transfer if addr_ctrl indicates a fixed address control. Otherwise,
// hsize bus is used to control the amount of incrementation or decrementation.
// The haddr bus is only changed when hready is high.

assign haddr_pre = ( tfr_req ) ? st_addr_used : next_addr;

 // Haddr bus stops toggling when mbiu not used.

always @(posedge hclk or negedge hresetn)
  begin : haddr_PROC
    if(hresetn == 1'b0)
      haddr <= { (AW){1'b0} };
    else if(!addr_complete || tfr_req)
      haddr <= haddr_pre;
  end

// Register dou_addr_inc_mi on tfr_req

always @(posedge hclk or negedge hresetn)
  begin : dou_add_inc_reg_PROC
    if(hresetn == 1'b0)
      dou_add_inc_reg <= 1'b0;
    else if(tfr_req)
      dou_add_inc_reg <= dou_addr_inc_mi;
  end

// Special case when writing back ctrlx and destination status. This
// is always of word transfer size.
// When CC parameter DMAH_CHx_STAT_SRC is set to
// include and ss_upd_en is de-asserted then source
// status register exists in external memory but do not update it. If
// DMAH_CHx_STAT_DST is set to include and ds_upd_en is enabled
// when need to write to ctrlx following by dst
// memory locations. i.e. need two beats of a 32 bit transfer
// where address increment is not aligned to hsize, the normal case,
// but address increment is twice hsize.

// Insert Idle on first transfer of locked transfer.

// CRM 9000410192 - www.joe - Nov 2010
// Going to change this writeback sequence so that the ctrl
// register is the last to be written back to the LLI location.
// Customer was polling the done bit in the LLI.CTRLx register
// then reading the LLI.SSTAT and LLI.DSTAT values (but the STAT
// values had not yet been updated in the LLI location.
// All Changes for this STAR are gaurded by parameter DMAH_REVERSE_WB_ORDER
// New sequence:
// upd_sequence = 0 => ctl
// upd_sequence = 1 => sstat,ctl
// upd_sequence = 2 => dstat,ctl
// upd_sequence = 3 => dstat,sstat,ctl
//

always @(addr_ctrl_req or hready or hsize or haddr or dou_add_inc_reg or insert_idle_hreg)
  begin : next_addr_PROC
    if(!(hready && (addr_ctrl_req[1] != 1'b1) && (!insert_idle_hreg)))
      next_addr = haddr;
    else if(hsize == HS_BYTE)
      if(addr_ctrl_req[0] == 1'b0)
        next_addr = haddr + 1;
      else
        next_addr = haddr - 1;
    else if(hsize == HS_HALFWORD)
      if(addr_ctrl_req[0] == 1'b0)
        next_addr = haddr + 2;
      else
        next_addr = haddr - 2;
    else if(hsize == HS_DOUBLE_WORD && (HDATA_WIDTH >= 64))
      if(addr_ctrl_req[0] == 1'b0)
        next_addr = haddr + 8;
      else
        next_addr = haddr - 8;
    else if(hsize == HS_WORD_LINE_4 && (HDATA_WIDTH >= 128))
      if(addr_ctrl_req[0] == 1'b0)
        next_addr = haddr + 16;
      else
        next_addr = haddr - 16;
    else if(hsize == HS_WORD_LINE_8 && (HDATA_WIDTH ==256))
      if(addr_ctrl_req[0] == 1'b0)
        next_addr = haddr + 32;
      else
        next_addr = haddr - 32;
    else if((addr_ctrl_req[0] == 1'b0) && (!dou_add_inc_reg))
      next_addr = haddr + 4;
    else if(dou_add_inc_reg)
      next_addr = haddr + 8;
    else
      next_addr = haddr - 4;
  end
  
  // asserted one cycle before a 1KB boundary crossing.
assign haddr_1k_pre = (haddr_pre[9:0] == 10'b0000_0000_00) ;

// Latch the control inputs pertinent to the requested transfer on
// the transfer request, tfr_req input.

always @(posedge hclk or negedge hresetn)
  begin : hwrite_PROC
    if(hresetn == 1'b0)
      hwrite <= 1'b0;
    else if(tfr_req)
      hwrite <= write;
  end

always @(posedge hclk or negedge hresetn)
  begin : hsize_PROC
    if(hresetn == 1'b0)
      hsize <= 3'b000;
    else if(tfr_req)
      hsize <= size_int;
  end

always @(posedge hclk or negedge hresetn)
  begin : hprot_PROC
    if(hresetn == 1'b0)
      hprot <= 4'b0;
    else if(tfr_req)
      hprot <= {prot[3:1],1'b1};
  end

generate
  if ( DMAH_DEC_ADDR ) begin : m11
    assign addr_ctrl_pre = addr_ctrl;
  end
  else begin : m12
    assign addr_ctrl_pre = {addr_ctrl[1],1'b0};
  end
endgenerate

always @(posedge hclk or negedge hresetn)
  begin : addr_ctrl_req_PROC
    if(hresetn == 1'b0)
      addr_ctrl_req <= 2'b00;
    else if(tfr_req)
      addr_ctrl_req <= addr_ctrl_pre;
  end
  
// Generation of hlock one cycle before the address phase
// to which it refers. hlock_clr is co-incident with the last data
// phase ( hready high ) of the requested locking level.

// If the requested transfer is the first of the requested locking level,
// ( transfer, block or transaction ) as indicated by the hlock level, then
// insert idle cycle by adding 1 to the requested length and gate htrans
// to idle for this cycle. This allows the registering of hlock at the output.

//spyglass disable_block W528
//SMD : A signal or variable is set but never read
//SJ : The DW_ahb_dmac is a highly configurable IP, due to this in certain
//    configuration few signals are driven, but may not be read.
//    But there will not be any functional issue.
always @(posedge hclk or negedge hresetn)
  begin : hc_hlock_PROC
    if(hresetn == 1'b0)
      hc_hlock <= 1'b0;
    else if(split_retry)
      hc_hlock <= hlock_hready_reg;
    else if(mask_lck_ch_en)
      hc_hlock <= lock_b_m;
    else if(hlock_clr_int || hlock_clr_on_can_dfc)
      hc_hlock <= 1'b0;
    else
      hc_hlock <= hlock;
  end
//spyglass enable_block W528

generate
  if (DMAH_LOCK_EN)
    begin : m13
      assign hlock = hc_hlock ;
      assign hlock_clr_int = (hlock_clr && (!(mask_lck_ch_en_hreg && (!ch_disabled_mask)))) ;
      assign insert_idle = (mask_lck_ch_en && lock_b_m && (!hlock)) ;
    end
  else
    begin : m14
      assign hlock = 1'b0;
      assign hlock_clr_int = 1'b0;
      assign insert_idle = 1'b0;
    end
endgenerate

assign length_int = insert_idle ? length + 1 : length ;

// For transaction level locking then transaction complete
// may occur after a new transaction has already started, (if source and destination on different layers). In
// this case don't clear hlock. Generate mask_lck_ch_en_hreg
// to mask off clearing of hlock.

//spyglass disable_block W528
//SMD : A signal or variable is set but never read
//SJ : The DW_ahb_dmac is a highly configurable IP, due to this in certain
//    configuration few signals are driven, but may not be read.
//    But there will not be any functional issue.
always @(posedge hclk or negedge hresetn)
  begin : hc_mask_lck_ch_en_hr_PROC
    if(hresetn == 1'b0)
      hc_mask_lck_ch_en_hr <= 1'b0;
    else if(hready)
      hc_mask_lck_ch_en_hr <= mask_lck_ch_en && lock_b_m;
    else
      hc_mask_lck_ch_en_hr <= mask_lck_ch_en_hr;
  end
//spyglass enable_block W528

generate
  if (DMAH_LOCK_EN) begin : m15
    assign mask_lck_ch_en_hr = hc_mask_lck_ch_en_hr ;
  end
  else begin : m16
    assign mask_lck_ch_en_hr = 1'b0 ;
  end
endgenerate

assign mask_lck_ch_en_hreg_pre = mask_lck_ch_en_hr && hready;

//spyglass disable_block W528
//SMD : A signal or variable is set but never read
//SJ : The DW_ahb_dmac is a highly configurable IP, due to this in certain
//    configuration few signals are driven, but may not be read.
//    But there will not be any functional issue.
always @(posedge hclk or negedge hresetn)
  begin : hc_mask_lck_ch_en_hreg_reg_PROC
    if(hresetn == 1'b0)
      hc_mask_lck_ch_en_hreg_reg <= 1'b0;
    else
      hc_mask_lck_ch_en_hreg_reg <= mask_lck_ch_en_hreg_pre;
  end
//spyglass enable_block W528

//spyglass disable_block W528
//SMD : A signal or variable is set but never read
//SJ : The DW_ahb_dmac is a highly configurable IP, due to this in certain
//    configuration few signals are driven, but may not be read.
//    But there will not be any functional issue.
generate
  if (DMAH_LOCK_EN) begin : m17
    assign mask_lck_ch_en_hreg_reg = hc_mask_lck_ch_en_hreg_reg ;
  end
  else begin : m18
    assign mask_lck_ch_en_hreg_reg = 1'b0;
  end
endgenerate
//spyglass enable_block W528

//spyglass disable_block W528
//SMD : A signal or variable is set but never read
//SJ : The DW_ahb_dmac is a highly configurable IP, due to this in certain
//    configuration few signals are driven, but may not be read.
//    But there will not be any functional issue.
assign mask_lck_ch_en_hreg = mask_lck_ch_en_hreg_reg ;
//spyglass enable_block W528

// generation of htrans. Always NONSEQ when addr_ctrl indicates
// either a decrementing or fixed address control.
// htrans indicates IDLE on the second cycle of a 2 stage split or
// retry response.
// htrans indicates NONSEQ on a 1KB boundary crossing.
// htrans indicates IDLE when no active address phase been driven onto bus.

// It is an AMBA protocol violation to change htrans from nonseq/seq to idle
// during a waited transfer. can_goto_amba_m_h and cancel_amba_req_m_h
// are only asserted when
// hready is asserted.

always @(posedge hclk or negedge hresetn)
  begin : htrans_PROC
    if(hresetn == 1'b0)
      htrans <= IDLE;
    else if(insert_idle || (!hgrant_int && hready))
      htrans <= IDLE;
    else if(can_goto_amba_m_h)
      htrans <= IDLE;
    else if(cancel_amba_req_m_h && (!tfr_req))
      htrans <= IDLE;
    else if(!hready && ( hresp_int != HOK))
      htrans <= IDLE;
    else if(hready && (!hgrant_int))
      htrans <= IDLE;
    else if(tfr_req || (insert_idle_hreg && (!sec_cycle_non_ok)))
      htrans <= NONSEQ;
    else if(hready) begin
      if(end_addr_phase_int || addr_complete)
        htrans <= IDLE;
      else if((addr_ctrl_req == 2'b 00) && (!haddr_1k_pre) && (!dou_add_inc_reg))
        htrans <= SEQ;
      else
        htrans <= NONSEQ;
    end
  end

//spyglass disable_block W528
//SMD : A signal or variable is set but never read
//SJ : The DW_ahb_dmac is a highly configurable IP, due to this in certain
//    configuration few signals are driven, but may not be read.
//    But there will not be any functional issue.
always @(posedge hclk or negedge hresetn)
  begin : hc_insert_idle_hr_PROC
    if(hresetn == 1'b0)
      hc_insert_idle_hr <= 1'b0;
    else if(hready)
      hc_insert_idle_hr <= insert_idle;
    else
      hc_insert_idle_hr <= insert_idle_hr;
  end
//spyglass enable_block W528

generate
  if (DMAH_LOCK_EN) begin : m19
    assign insert_idle_hr = hc_insert_idle_hr ;
  end
  else begin : m20
    assign insert_idle_hr = 1'b0;
  end
endgenerate

assign insert_idle_hreg = insert_idle_hr && hready;

// command to pop data from the channel FIFO
assign pop = hwrite && (!addr_complete) && hready && (htrans != IDLE) ;

// pop_hld is asserted with pop and waits for pop_data_valid

always @(posedge hclk or negedge hresetn)
  begin : pop_hld_PROC
    if (hresetn == 1'b0)         pop_hld <= 1'b0;
    else if (pop)                pop_hld <= 1'b1;
    else if (pop_data_valid)     pop_hld <= 1'b0;
  end

// Asynchronous FIFO used so data returned on same cycle as pop command.
// Pop command issued on address phase, so register data_in from FIFO
// before driving onto hwdata bus.

// Pop is asserted on the address phase.

always @(posedge hclk or negedge hresetn)
  begin : hwdata_PROC
    if(hresetn == 1'b0)
      hwdata <= {(HDATA_WIDTH){1'b0}};
    else if(pop)
      hwdata <= data_in;
  end

// command to push hrdata onto the channel FIFO.

always @(posedge hclk or negedge hresetn)
  begin : htrans_hr_ni_PROC
    if(hresetn == 1'b0)
      htrans_hr_ni <= 1'b0;
    else if(hready)
      htrans_hr_ni <= (htrans != IDLE);
  end

assign htrans_hreg_ni = htrans_hr_ni && hready;

// htrans_hreg != IDLE only needed when an idle cycle is inserted
// on the first transfer of the requested locking level.

// Push is asserted on data phase of AMBA transfer. Pop is asserted on the address
// phase.

assign push = (!hwrite_delay) && (!data_complete) && ( hresp_int == HOK) && htrans_hreg_ni;

// data_phase complete asserted on the cycle after the last data phase
// of the requested transfer

always @(posedge hclk or negedge hresetn)
  begin : data_complete_PROC
    if(hresetn == 1'b0)
      data_complete <= 1'b0;
    else if(hready)
      data_complete <= addr_complete;
  end

always @(posedge hclk or negedge hresetn)
  begin : hwrite_delay_PROC
    if(hresetn == 1'b0)
      hwrite_delay <= 1'b0;
    else if(hready)
      hwrite_delay <= hwrite;
  end

// pop_data_valid asserted on same cycle as successful completion
// of data phase of pop'ed data.

always @(posedge hclk or negedge hresetn)
  begin : pop_dat_vld_pre_PROC
    if(hresetn == 1'b0)
      pop_dat_vld_pre <= 1'b0;
    else if(hready)
      pop_dat_vld_pre <= pop;
  end

// assign pop_data_valid = pop_dat_vld_pre && hready && ( hresp_int == HOK ) && !data_complete;

// Re-written for conditional code coverage. data_complete will never be asserted when
// pop_dat_vld_pre = hready = ( hresp_int == HOK ) = 1.

assign pop_data_valid = (!data_complete) ?
                        pop_dat_vld_pre && hready && ( hresp_int == HOK ) :
                        1'b0;

//spyglass disable_block W528
//SMD : A signal or variable is set but never read
//SJ : The DW_ahb_dmac is a highly configurable IP, due to this in certain
//    configuration few signals are driven, but may not be read.
//    But there will not be any functional issue.
always @(posedge hclk or negedge hresetn)
  begin : hc_sec_cycle_non_ok_PROC
    if(hresetn == 1'b0)
      hc_sec_cycle_non_ok <= 1'b0;
    else
      hc_sec_cycle_non_ok <= first_cycle_non_ok;
  end
//spyglass enable_block W528

generate
  if (DMAH_NON_OK_EN_M) begin : m21
    assign sec_cycle_non_ok = hc_sec_cycle_non_ok;
  end
  else begin : m22
    assign sec_cycle_non_ok = 1'b0;
  end
endgenerate

assign first_cycle_non_ok = (!hready) && (hresp_int != HOK);

//-----------------------------
// Ch 9000047152
// capture EBT event when we lose bus grant
// generate another split_retry event
always @(posedge hclk or negedge hresetn)
  begin : dp_last_PROC
    if(hresetn == 1'b0)
      begin
        num_adr_to_comp_reg <= {(DMAH_MAX_BURST_LENGTH+1){1'b0}};
        ebt_event_reg <= 1'b0;
        hgrant_int_reg <= 1'b0;
        hc_hburst_prev <= 3'b000;
        dp_last <= 1'b0;
      end
    else
      begin
        num_adr_to_comp_reg <= num_adr_to_comp;
        ebt_event_reg <= ebt_event;
        hgrant_int_reg <= hgrant_int;

        if(hready)
          hc_hburst_prev <= hc_hburst;

        if((htrans != IDLE) && hready && (num_adr_to_comp == 1))
          dp_last <= 1'b1;
        else if (dp_last && dp_complete)
          dp_last <= 1'b0;
      end
  end

 // If we get a split, retry or ebt event on a defined length transfer
 // we will have to complete the transfer using the correct transfer
 // burst type to do this we will store the fact that the
 // incomplete transfer has occured and also store the number of
 // incomp_trans_beats.
 // Each time we start a new transaction we will subtract
 // the transaction length from the remaining beats until
 // the outstanding transaction is complete. At this point
 // we resume standard operation.

 // if we get SPLIT/RETRY/EBT while completing a previously interrupted
 // transfer we must adjust the incomplete beat count by the remaining
 // number of address to complete in the current transaction

//spyglass disable_block FlopConst
//SMD: Enable bit tied to 1/0
//SJ: This is intended by design, warning can be ignored

//spyglass disable_block W484
//SMD: Possible loss of carry or borrow in addition or subtraction (Verilog)
//SJ: This implementation is as per the design requirement. There is no chance
//    of carry/borrow overflow. There will not be any functional issue.
//spyglass disable_block SelfDeterminedExpr-ML
//SMD: Self determined expression present in the design.
//SJ: This Self Determined Expression is as per the design requirement.
//    There will not be any functional issue.
//spyglass disable_block W164a
//SMD: Identifies assignments in which the LHS width is less than the RHS width
//SJ: This implementation is as per the design requirement. There is no chance of carry/borrow overflow. There will not be any functional issue.

always @(posedge hclk or negedge hresetn)
  begin : incomp_trans_PROC
    if(hresetn == 1'b0)
      incomp_trans_beats <= {(DMAH_MAX_BURST_LENGTH+1){1'b0}};
    else if (incr_bursts == 1'b0)
      begin
        if((split_retry && hc_hburst_prev != UNDEFINED_LEN_BURST)
           || (ebt_event && hc_hburst != UNDEFINED_LEN_BURST))
          if(incomp_trans_beats == {(DMAH_MAX_BURST_LENGTH+1){1'b0}})
            if(ebt_event)
              incomp_trans_beats <= num_adr_to_comp_reg - 1;
            else if (dp_last/*htrans == NONSEQ*/) // split/retry on last data phase
              incomp_trans_beats <= {{(DMAH_MAX_BURST_LENGTH){1'b0}},1'b1};
            else if (hc_hburst_prev == UNDEFINED_LEN_BURST)
              incomp_trans_beats <= {(DMAH_MAX_BURST_LENGTH+1){1'b0}};
            else if(num_adr_to_comp == num_adr_to_comp_reg)
              incomp_trans_beats <= num_adr_to_comp_reg + 1;
            else
              incomp_trans_beats <= num_adr_to_comp_reg;
          else if(ebt_event)
            incomp_trans_beats <= (incomp_trans_beats + num_adr_to_comp_reg) - 1;
          else if(ebt_event_reg) //ebt'ed beats dataphase has split/retry
            incomp_trans_beats <= incomp_trans_beats + 1;
          else if(num_adr_to_comp == num_adr_to_comp_reg)
            incomp_trans_beats <= incomp_trans_beats + num_adr_to_comp_reg + 1;
          else
            incomp_trans_beats <= incomp_trans_beats + num_adr_to_comp_reg;
        else if(hresp_int == HERROR) // clear incomp_trans_beats if we get an error
          incomp_trans_beats <= {(DMAH_MAX_BURST_LENGTH+1){1'b0}};
        else
          if(incomp_trans_beats != {(DMAH_MAX_BURST_LENGTH+1){1'b0}} && tfr_req)
            incomp_trans_beats <= incomp_trans_beats - length_int;
      end
  end // block: incomp_trans_PROC
//spyglass enable_block W164a
//spyglass enable_block SelfDeterminedExpr-ML
//spyglass enable_block W484
//spyglass enable_block FlopConst

// flag last transfer to arbiter to remove lock
always @(incomp_trans_beats or length_int or hc_hburst)
  begin : last_tfr_PROC
    if(hc_hburst != 3'b001)
      if(incomp_trans_beats > 0)
        if(incomp_trans_beats == length_int)
          last_tfr_i = 1'b1;
        else
          last_tfr_i = 1'b0;
      else
        last_tfr_i = 1'b1;
    else
      last_tfr_i = 1'b1;
  end

assign last_tfr = (incr_bursts) ? 1'b1 : last_tfr_i;

always @(hc_hburst or num_adr_to_comp or num_adr_to_comp_reg or hresp_int or hgrant_int_reg)
  begin : ebt_event_PROC
    //don't geberate EBT for INCR, SINGLE or SPLIT/RETRY conditions
    if ((hc_hburst >= 3'b011) && (hresp_int == HOK) && (!hgrant_int_reg))
      ebt_event = (num_adr_to_comp == 0) && (num_adr_to_comp_reg > 1);
    else
      ebt_event = 1'b0;
  end

assign split_retry = (!hready && ((hresp_int == HSPLIT) || (hresp_int == HRETRY))) || ebt_event ;

always @(posedge hclk or negedge hresetn)
begin : hc_split_retry_reg_PROC
    if(hresetn == 1'b0)
    hc_split_retry_reg <= 1'b0;
    else
    hc_split_retry_reg <= split_retry;
end

//GH 9000047152
// always pass out split_retry for defined length bursts
generate
  if (DMAH_NON_OK_EN_M) begin : m23
    assign split_retry_reg = hc_split_retry_reg;
  end
  else begin : m24
    assign split_retry_reg = (incr_bursts == 0) ? hc_split_retry_reg : 1'b0;
  end
endgenerate

// Generate hready delayed version of haddr.

always @(posedge hclk or negedge hresetn)
  begin : haddr_reg_PROC
    if(hresetn == 1'b0)
      haddr_reg <= {(AW){1'b0}};
    else
      if(hready)
        haddr_reg <= next_addr;
  end

// hbusreq de-asserted for AMBA LITE master.
generate
  if (AHB_LITE) begin : m25
    assign hbusreq = 1'b0 ;
  end
  else begin : m26
    assign hbusreq = hbusreq_int;
  end
endgenerate

// hgrant asserted for AMBA LITE master.
generate
  if (AHB_LITE) begin : m27
    assign hgrant_int = 1'b1 ;
  end
  else begin : m28
    assign hgrant_int = hgrant;
  end
endgenerate

// Mask out non ok hresp when occurs on last data phase of
// previous transfer.

/*****************************/

// always clear the locking of the bus and channel arbiter
// for all transfer levels when an error response is received.
generate
  if (DMAH_HRESP_WIDTH == 2) begin : CLR_LOCK_ERROR_1
    assign clr_lock_error = (hresp == HERROR) && (!data_complete) ;
  end
  else begin : CLR_LOCK_ERROR_2
    assign clr_lock_error = (hresp == 1'b1) && (!data_complete) ;
  end
endgenerate

//spyglass disable_block W528
//SMD : A signal or variable is set but never read
//SJ : The DW_ahb_dmac is a highly configurable IP, due to this in certain
//    configuration few signals are driven, but may not be read.
//    But there will not be any functional issue.
always @(posedge hclk or negedge hresetn)
  begin : hc_hlock_hready_reg_PROC
    if(hresetn == 1'b0)
      hc_hlock_hready_reg <= 1'b0;
    else
      if(hready)
        hc_hlock_hready_reg <= hlock;
      else
        hc_hlock_hready_reg <= hlock_hready_reg;
  end
//spyglass enable_block W528

generate
  if (DMAH_LOCK_EN) begin : m29
    assign hlock_hready_reg = hc_hlock_hready_reg ;
  end
  else begin : m30
    assign hlock_hready_reg = 1'b0;
  end
endgenerate

/*****************************/

// 4-10-2003. Moved gating of these signals to mbiu from channel blocks
// to reduce critical timing. Gating with hready (critical signal) moved closer to
// timing path endpoint.

// STAR 183951 Fix
// If have two tfr_req pulses separated by a single cycle ( i.e. length of first tfr_req = 1 ) then since
// the can_goto_amba_m_h pulse is 2 cycles long the second cycle will overlap the second tfr_req pulse
// which results in the mbiu going IDLE but the state machine waiting for a response from the mbiu. Will get
// timeout. Soln is to gate can_goto_amba_m_h with !tfr_req.

// In order to allow the master interface to complete started transfer, don't pass can_goto_amba_m_h in defined
// length burst transfer. The scenario is, dst is flow controller and src pre-fetch is enabled. The dst completes the
// transfer and cancels the src prefetch. However, the src is in teh middle of an INCR 4 and cancelling will create
// a bus violation so we won't cancel and we will let the transfer complete.

assign can_goto_amba_m_int = can_goto_amba_m;
assign can_goto_amba_m_h = can_goto_amba_m_int && hready && (!tfr_req);
assign cancel_amba_req_m_h = cancel_amba_req_m && hready;

// Bug fix for "Master deasserts hlock before been granted the bus." This only occurs when
// we are the default master and we only get onto the bus for 1 cycle ( higher priority gets in )
// at the start of a locking phase ( transaction, block or transfer ). insert_idle_hreg only
// asserted for a single cycle at the start of a locking phase. If hgrant is deasserted when this
// pulse occurs then there is a potential for the deassertion of hlock before been granted the bus
// if software disables the locked channel. Generate control signal to mask off disabling of channel
// if this is the case.

//spyglass disable_block W528
//SMD : A signal or variable is set but never read
//SJ : The DW_ahb_dmac is a highly configurable IP, due to this in certain
//    configuration few signals are driven, but may not be read.
//    But there will not be any functional issue.
always @(posedge hclk or negedge hresetn)
  begin : hc_mask_ch_disable_hlock_PROC
    if(hresetn == 1'b0)
      hc_mask_ch_disable_hlock <= 1'b0;
    else
      if(hgrant_int && hready)
        hc_mask_ch_disable_hlock <= 1'b0;
      else
        if(insert_idle_hreg)
          hc_mask_ch_disable_hlock <= 1'b1;
  end
//spyglass enable_block W528

generate
  if (DMAH_LOCK_EN && (AHB_LITE == 0)) begin : m31
    assign mask_ch_disable_hlock = hc_mask_ch_disable_hlock ;
  end
  else begin : m32
    assign mask_ch_disable_hlock = 1'b0;
  end
endgenerate

endmodule  

