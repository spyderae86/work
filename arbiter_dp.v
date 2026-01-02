//-----------------------------------------------------------------
//      module
//      test.com
//      Copyright 2025-2026
//      BSD
//-----------------------------------------------------------------
module DW_ahb_dmac_arbiter_dp
(
//Inputs
 hclk,
 hresetn,
 req_mi,
 ch_prior,
 mask_lck_ch,
 //split_retry,

//Outputs
 granted_mi,
 grant_mi,
 grant_index_mi
);

// An arbiter instance is assigned to each master
// interface. The request's from the
// channel source and destination s/m's are
// only passed to a master interface if they are
// assigned to that master interface.

input  [`DMAH_NUM_PER-1:0] req_mi;
input  hclk;
input  hresetn;
input  [3*`DMAH_NUM_CHANNELS-1:0] ch_prior;
input  [`DMAH_NUM_PER-1:0] mask_lck_ch;
//input split_retry;

// Asserted when any request from any priority level is currently granted.
output granted_mi;

// signals currently granted req
output [`DMAH_NUM_PER-1:0] grant_mi;

// index into currently granted request
output [`LOG2_DMAH_NUM_PER-1:0] grant_index_mi;

// Local parameters

// number of request lines
parameter NUM_PER = `DMAH_NUM_PER;

// arbiters contain no logic for parking
parameter PARK_MODE  = 0;
parameter PARK_INDEX = 0;

// DW_arbiter_dp contains output registers
// Fixes, 9/3/2011, STAR 9000451719
// Ability to remove some pipelining stages is being added.
parameter OUTPUT_MODE = `DMAH_REG_ARB;

localparam INDEX_WIDTH =
 ((`DMAH_NUM_PER==2) ? 1 :
  (`DMAH_NUM_PER==4) ? 2 :
  (`DMAH_NUM_PER==6) ? 3 :
  (`DMAH_NUM_PER==8) ? 3 : 4);

wire [(INDEX_WIDTH*`DMAH_NUM_PER)-1:0] priority_int;
wire [(INDEX_WIDTH*`DMAH_NUM_PER)-1:0] prioritywire;
wire [23:0] ch_prior_int;

//reg split_retry_reg;

//always @(posedge hclk or negedge hresetn)
//begin : split_retry_reg_PROC
//  if(hresetn == 1'b0)
//    split_retry_reg <= 1'b0;
//  else
//    split_retry_reg <= split_retry;
//end

//spyglass disable_block W528
//SMD : A signal or variable is set but never read
//SJ  : The DW_ahb_dmac is a highly configurable IP, due to this in certain
//      configuration few signals are driven, but may not be read.
//      But there will not be any functional issue.
assign ch_prior_int = {{(24-(3*`DMAH_NUM_CHANNELS)){1'b0}}, ch_prior};
//spyglass enable_block W528

generate
 if (`DMAH_NUM_CHANNELS==1) begin : ad1
  assign priority_int = {(INDEX_WIDTH*`DMAH_NUM_PER){1'b0}};
 end
 else if (`DMAH_NUM_CHANNELS==2) begin : ad2
  assign priority_int = {1'b0,ch_prior_int[3],1'b0,ch_prior_int[3],
                          1'b0,ch_prior_int[0],1'b0,ch_prior_int[0]};
 end
 else if (`DMAH_NUM_CHANNELS==3) begin : ad3
  assign priority_int = {1'b0,ch_prior_int[7:6],1'b0,ch_prior_int[7:6],
                          1'b0,ch_prior_int[4:3],1'b0,ch_prior_int[4:3],
                          1'b0,ch_prior_int[1:0],1'b0,ch_prior_int[1:0]};
 end
 else if (`DMAH_NUM_CHANNELS==4) begin : ad4
  assign priority_int = {1'b0,ch_prior_int[10:9],1'b0,ch_prior_int[10:9],
                          1'b0,ch_prior_int[7:6],1'b0,ch_prior_int[7:6],
                          1'b0,ch_prior_int[4:3],1'b0,ch_prior_int[4:3],
                          1'b0,ch_prior_int[1:0],1'b0,ch_prior_int[1:0]};
 end
 else if (`DMAH_NUM_CHANNELS==5) begin : ad5
  assign priority_int = {1'b0,ch_prior_int[14:12],1'b0,ch_prior_int[14:12],
                          1'b0,ch_prior_int[11:9],1'b0,ch_prior_int[11:9],
                          1'b0,ch_prior_int[8:6],1'b0,ch_prior_int[8:6],
                          1'b0,ch_prior_int[5:3],1'b0,ch_prior_int[5:3],
                          1'b0,ch_prior_int[2:0],1'b0,ch_prior_int[2:0]};
 end
 else if (`DMAH_NUM_CHANNELS==6) begin : ad6
  assign priority_int = {1'b0,ch_prior_int[17:15],1'b0,ch_prior_int[17:15],
                          1'b0,ch_prior_int[14:12],1'b0,ch_prior_int[14:12],
                          1'b0,ch_prior_int[11:9],1'b0,ch_prior_int[11:9],
                          1'b0,ch_prior_int[8:6],1'b0,ch_prior_int[8:6],
                          1'b0,ch_prior_int[5:3],1'b0,ch_prior_int[5:3],
                          1'b0,ch_prior_int[2:0],1'b0,ch_prior_int[2:0]};
 end
 else if (`DMAH_NUM_CHANNELS==7) begin : ad7
  assign priority_int = {1'b0,ch_prior_int[20:18],1'b0,ch_prior_int[20:18],
                          1'b0,ch_prior_int[17:15],1'b0,ch_prior_int[17:15],
                          1'b0,ch_prior_int[14:12],1'b0,ch_prior_int[14:12],
                          1'b0,ch_prior_int[11:9],1'b0,ch_prior_int[11:9],
                          1'b0,ch_prior_int[8:6],1'b0,ch_prior_int[8:6],
                          1'b0,ch_prior_int[5:3],1'b0,ch_prior_int[5:3],
                          1'b0,ch_prior_int[2:0],1'b0,ch_prior_int[2:0]};
 end
 else begin : ad8 //if (`DMAH_NUM_CHANNELS==8)
  assign priority_int = {1'b0,ch_prior_int[23:21],1'b0,ch_prior_int[23:21],
                          1'b0,ch_prior_int[20:18],1'b0,ch_prior_int[20:18],
                          1'b0,ch_prior_int[17:15],1'b0,ch_prior_int[17:15],
                          1'b0,ch_prior_int[14:12],1'b0,ch_prior_int[14:12],
                          1'b0,ch_prior_int[11:9],1'b0,ch_prior_int[11:9],
                          1'b0,ch_prior_int[8:6],1'b0,ch_prior_int[8:6],
                          1'b0,ch_prior_int[5:3],1'b0,ch_prior_int[5:3],
                          1'b0,ch_prior_int[2:0],1'b0,ch_prior_int[2:0]};
 end
endgenerate

// 1 Tier arbitration.
assign prioritywire = priority_int;

// lock input only needs to follow request lines when 3 tier
// arbitration is employed using a fcfs arbiter for
// each possible priority. For the 2 tier dynamic priority
// arbitration can drive lock to 0.

// A arbitration grant is locked when
// 1. The request is asserted
// 2. The request is currently granted.
// A state machine will keep requesting until it
// transitions to it's AMBA state. Therefore, once
// a request line granted then it will remain granted
// until the one cycle after tfr_req is pulsed
// ( goto_amba_state in s/m )
// arb_dp -> bcm52

// In a module instantiation.
DW_ahb_dmac_bcm52
#(NUM_PER,PARK_MODE,PARK_INDEX,OUTPUT_MODE,
  `LOG2_DMAH_NUM_PER,`LOG2_DMAH_NUM_PERP1)
U_ARB_DPbb
(
 .clk(hclk),
 .enable(1'b1),
 .rst_n(hresetn),
 .init_n(1'b1),
 .request(req_mi),
 .prior(prioritywire),
 .lock({`DMAH_NUM_PER{1'b0}}),
 .mask(mask_lck_ch),
 //spyglass disable_block W287b
 //SMD : Output port to an instance is not connected
 //SJ  : The BCM52 is a generic Arbiter design, which has many features.
 //      But this use case does not use all features. Hence these signals
 //      are unused. But there is no functional issue, hence this can be
 //      waived.
 .parked(),
 //spyglass enable_block W287b
 .granted(granted_mi),
 //spyglass disable_block W287b
 //SMD : Output port to an instance is not connected
 //SJ  : The BCM52 is a generic Arbiter design, which has many features.
 //      But this use case does not use all features. Hence these signals
 //      are unused. But there is no functional issue, hence this can be
 //      waived.
 .locked(),
 //spyglass enable_block W287b
 .grant(grant_mi),
 .grant_index(grant_index_mi)
);

endmodule
