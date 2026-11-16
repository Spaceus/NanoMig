// Compares two complete denise_bitplanes, one with the distributed ram scroll
// history and one with the block ram version, clock by clock on bpldata.
// Unlike tb_scroll_bram.v this goes through the real wiring of the selects.
//
// Random register traffic: BPLxDAT, BPLCON1 and FMODE writes, resolution
// changes. A difference is only accepted in the clocks right after a change
// of resolution or FMODE (the history output passes an 8 stage scroller).
`timescale 1ns/1ps

module tb;

reg clk = 0; always #17.5 clk = ~clk;
`ifdef GOWIN
GSR GSR (.GSRI(1'b1));
`endif

reg  [1:0] phase = 0;
wire       c1 = phase[1];
wire       c3 = phase[1] ^ phase[0];
wire       clk7_en = (phase == 2'd3);

reg        reset = 1;
reg        hires = 0, shres = 0;
reg  [8:1] reg_address_in = 8'hff;
reg [15:0] data_in = 0, chip16_r = 0;
reg  [1:0] chip16_idx = 0;
reg  [8:0] hpos = 0;

wire [8:1] bpl_dist, bpl_bram;

denise_bitplanes u_dist (
  .clk(clk), .clk7_en(clk7_en), .reset(reset), .c1(c1), .c3(c3), .aga(1'b1),
  .reg_address_in(reg_address_in), .data_in(data_in), .chip16_r(chip16_r),
  .chip16_idx(chip16_idx), .hires(hires), .shres(shres), .hpos(hpos), .bpldata(bpl_dist));

denise_bitplanes u_bram (
  .clk(clk), .clk7_en(clk7_en), .reset(reset), .c1(c1), .c3(c3), .aga(1'b1),
  .reg_address_in(reg_address_in), .data_in(data_in), .chip16_r(chip16_r),
  .chip16_idx(chip16_idx), .hires(hires), .shres(shres), .hpos(hpos), .bpldata(bpl_bram));

defparam u_dist.history.BRAM = 0;
defparam u_bram.history.BRAM = 1;

integer clocks = 0, mismatches = 0, after_mode = 0, nonzero = 0, since_mode = 100;
integer seed = 7;
integer r;

always @(posedge clk) begin
  phase <= phase + 2'd1;
  chip16_r   <= $random(seed);
  chip16_idx <= chip16_idx + 2'd1;
  since_mode = since_mode + 1;

  if (clk7_en) begin
    reset <= 0;
    hpos  <= hpos + 9'd1;
    data_in <= $random(seed);

    // one register access per 7 MHz cycle: mostly bitplane data, sometimes
    // BPLCON1 (0x102) or FMODE (0x1fc), often nothing
    r = $random(seed) & 255;
    if      (r < 96)  reg_address_in <= 8'h88 + (r & 7);       // BPL1DAT..BPL8DAT (0x110..0x11e)
    else if (r < 100) reg_address_in <= 8'h81;                 // BPLCON1
    else if (r == 100 && ($random(seed) & 7) == 0) begin
      reg_address_in <= 8'hfe;                                 // FMODE
      since_mode = 0;
    end
    else              reg_address_in <= 8'hff;

    if (($random(seed) & 8191) == 0) begin
      since_mode = 0;
      case ($random(seed) & 3)
        0, 1: begin hires <= 0; shres <= 0; end
        2:    begin hires <= 1; shres <= 0; end
        3:    begin hires <= 0; shres <= 1; end
      endcase
    end
  end
end

always @(negedge clk) begin
  clocks = clocks + 1;
  if (bpl_dist !== 8'd0) nonzero = nonzero + 1;
  if (bpl_dist !== bpl_bram) begin
    if (since_mode < 40)
      after_mode = after_mode + 1;
    else begin
      mismatches = mismatches + 1;
      if (mismatches <= 10)
        $display("MISMATCH clock %0d: dist %02x bram %02x", clocks, bpl_dist, bpl_bram);
    end
  end
  if (clocks == 2000000) begin
    $display("%0d clocks, %0d with bitplane data", clocks, nonzero);
    $display("%0d differences right after a mode change (expected), %0d elsewhere", after_mode, mismatches);
    if (mismatches == 0) $display("PASS");
    else                 $display("FAIL");
    $finish;
  end
end

endmodule
