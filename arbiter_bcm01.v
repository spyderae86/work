//-----------------------------------------------------------------
//      module
//      test.com
//      Copyright 2025-2026
//      BSD
//-----------------------------------------------------------------
module DW_ahb_dmac_bcm01 (
  // Inputs
  a,
  tc,
  min_max,
  // Outputs
  value,
  index
);

  parameter integer WIDTH = 4;       // element width
  parameter integer NUM_INPUTS = 8;  // number of elements in input array
  parameter integer INDEX_WIDTH = 3; // size of index pointer = ceil(log2(NUM_INPUTS))

  input  [NUM_INPUTS*WIDTH-1 : 0] a;     // Concatenated input vector
  input                           tc;    // 0 = unsigned, 1 = signed
  input                           min_max; // 0 = find min, 1 = find max
  output [WIDTH-1:0]              value; // mon or max value found
  output [INDEX_WIDTH-1:0]        index; // index to value found

  DW_minmax #(WIDTH, NUM_INPUTS) U1 (
    .a(a),
    .tc(tc),
    .min_max(min_max),
    .value(value),
    .index(index)
  );

endmodule