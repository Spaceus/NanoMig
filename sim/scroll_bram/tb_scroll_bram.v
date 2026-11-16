// Compares the block ram version of denise_scroll_history with the
// distributed ram version, clock by clock.
//
// The stimulus follows denise_bitplanes: shift comes from the c1/c3 phase and
// the resolution, the selects come from a scroll register that only changes
// on clk7_en, and the "next" selects are built the same way as there.
//
//   default       : resolution and fetch mode change rarely and on a fixed
//                   grid, the two versions must match on every clock except
//                   the one right after such a change
//   +midline_mode : resolution and fetch mode change at random clocks
//
// The next selects use the current resolution and fetch mode, so the single
// clock after a mode change may differ. Those clocks are counted separately.
`timescale 1ns/1ps

module tb;

reg clk = 0; always #17.5 clk = ~clk;
`ifdef GOWIN
GSR GSR (.GSRI(1'b1));   // global set/reset of the Gowin simulation library, found by name
`endif

reg  [1:0] phase = 0;          // position in the 7 MHz period
wire       c1 = phase[1];
wire       c3 = phase[1] ^ phase[0];
wire       clk7_en = (phase == 2'd3);

reg        hires = 0, shres = 0;
reg  [1:0] fmode = 0;
reg  [7:0] pf1h = 0, pf2h = 0, pf1h_del = 0, pf2h_del = 0;
reg  [7:0] pixel = 0;

reg  [5:0] fmode_mask;
always @(*)
  case (fmode)
    2'b00  : fmode_mask = 6'b00_1111;
    2'b11  : fmode_mask = 6'b11_1111;
    default: fmode_mask = 6'b01_1111;
  endcase

reg shift;
always @(*)
  if (shres)      shift = 1'b1;
  else if (hires) shift = ~c1 ^ c3;
  else            shift = ~c1 & ~c3;

wire [5:0] select1 = (shres ? pf1h_del[5:0] : hires ? pf1h_del[6:1] : pf1h_del[7:2]) & fmode_mask;
wire [5:0] select2 = (shres ? pf2h_del[5:0] : hires ? pf2h_del[6:1] : pf2h_del[7:2]) & fmode_mask;

wire [7:0] pf1h_del_nxt = clk7_en ? pf1h : pf1h_del;
wire [7:0] pf2h_del_nxt = clk7_en ? pf2h : pf2h_del;
wire [5:0] select1_nxt = (shres ? pf1h_del_nxt[5:0] : hires ? pf1h_del_nxt[6:1] : pf1h_del_nxt[7:2]) & fmode_mask;
wire [5:0] select2_nxt = (shres ? pf2h_del_nxt[5:0] : hires ? pf2h_del_nxt[6:1] : pf2h_del_nxt[7:2]) & fmode_mask;

wire [7:0] out_dist, out_bram;

denise_scroll_history #(.BRAM(0)) u_dist (
  .clk(clk), .shift(shift), .pixel(pixel),
  .select1(select1), .select2(select2),
  .select1_nxt(select1_nxt), .select2_nxt(select2_nxt), .out(out_dist));

denise_scroll_history #(.BRAM(1)) u_bram (
  .clk(clk), .shift(shift), .pixel(pixel),
  .select1(select1), .select2(select2),
  .select1_nxt(select1_nxt), .select2_nxt(select2_nxt), .out(out_bram));

integer clocks = 0, mismatches = 0, after_mode = 0, modechanges = 0, zero_sel = 0;
integer seed = 1;
reg     midline;
reg     newmode;
reg     mode_changed = 0;      // the mode registers changed at the last clock

initial midline = $test$plusargs("midline_mode");

always @(posedge clk) begin
  phase <= phase + 2'd1;
  pixel <= $random(seed);

  // scroll registers: written now and then, the delayed copy follows on clk7_en
  if (($random(seed) & 63) == 0) pf1h <= ($random(seed) & 3) ? $random(seed) : 8'd0;
  if (($random(seed) & 63) == 0) pf2h <= ($random(seed) & 3) ? $random(seed) : 8'd0;
  if (clk7_en) begin
    pf1h_del <= pf1h;
    pf2h_del <= pf2h;
  end

  // resolution / fetch mode
  newmode = midline ? (($random(seed) & 1023) == 0) : ((clocks % 1816) == 1815);
  mode_changed <= newmode;
  if (newmode) begin
    modechanges = modechanges + 1;
    fmode <= $random(seed);
    case ($random(seed) & 3)
      0, 1: begin hires <= 0; shres <= 0; end
      2:    begin hires <= 1; shres <= 0; end
      3:    begin hires <= 0; shres <= 1; end
    endcase
  end
end

always @(negedge clk) begin
  clocks = clocks + 1;
  if (select1 == 0 || select2 == 0) zero_sel = zero_sel + 1;
  if (out_dist !== out_bram) begin
    if (mode_changed)
      after_mode = after_mode + 1;
    else begin
      mismatches = mismatches + 1;
      if (mismatches <= 10)
        $display("MISMATCH clock %0d: dist %02x bram %02x sel %0d/%0d", clocks, out_dist, out_bram, select1, select2);
    end
  end
  if (clocks == 2000000) begin
    $display("%0d clocks, %0d with a select of 0, %0d mode changes", clocks, zero_sel, modechanges);
    $display("%0d differences in the clock after a mode change (expected), %0d elsewhere", after_mode, mismatches);
    if (mismatches == 0) $display("PASS");
    else                 $display("FAIL");
    $finish;
  end
end

endmodule
