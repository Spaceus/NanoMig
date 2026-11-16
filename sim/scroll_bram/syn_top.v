// top level for a synthesis of denise_scroll_history alone, see syn.tcl
module syn_top (
  input  wire       clk,
  input  wire       shift,
  input  wire [7:0] pixel,
  input  wire [5:0] select1_nxt,
  input  wire [5:0] select2_nxt,
  output wire [7:0] out
);

denise_scroll_history #(.BRAM(1)) history (
  .clk(clk), .shift(shift), .pixel(pixel),
  .select1(6'd0), .select2(6'd0),
  .select1_nxt(select1_nxt), .select2_nxt(select2_nxt), .out(out)
);

endmodule
