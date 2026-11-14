// Testbench for src/misc/rtg_scanout.v
// iverilog -g2012 -o /tmp/rtg_tb sim/rtg_scanout_tb.v src/misc/rtg_scanout.v && vvp /tmp/rtg_tb
`timescale 1ns/1ps
module rtg_scanout_tb;

reg clk = 0;        // "85 MHz"
reg clk_pixel = 0;  // clk / 3
always #6 clk = ~clk;
always #18 clk_pixel = ~clk_pixel;

reg reset = 1;
initial begin #100 reset = 0; end

// hdmi style pixel counters, NTSC frame 908 x 526
reg [10:0] cx = 0;
reg [9:0]  cy = 0;
always @(posedge clk_pixel) begin
  if (cx == 11'd907) begin
    cx <= 0;
    cy <= (cy == 10'd525) ? 10'd0 : cy + 10'd1;
  end else cx <= cx + 11'd1;
end

wire        p3_cs;
wire [23:0] p3_addr;
reg  [15:0] p3_dout;
reg  [47:0] p3_dout48;
reg         p3_ack = 0;
wire [23:0] rgb;
wire        rtg_active;

rtg_scanout dut (
  .clk(clk), .reset(reset),
  .p3_cs(p3_cs), .p3_addr(p3_addr), .p3_dout(p3_dout), .p3_dout48(p3_dout48), .p3_ack(p3_ack),
  .clk_pixel(clk_pixel), .cx(cx), .cy(cy), .rgb(rgb), .rtg_active(rtg_active)
);

// ---- video memory model (what the driver would have written) ------------
function [7:0] vbyte(input integer n);   // VRAM byte n
  integer y, x, i;
  begin
    if (n < 640*480) begin
      y = n / 640; x = n % 640;
      vbyte = (x*3 + y) & 255;
    end else if (n == 32'h3ff000) vbyte = 8'h52;      // control word "RT", big endian
    else if (n == 32'h3ff001) vbyte = 8'h54;
    else if (n >= 32'h3ff400 && n < 32'h3ff800) begin
      i = (n - 32'h3ff400) / 4;
      case ((n - 32'h3ff400) % 4)
        0: vbyte = 8'h00;
        1: vbyte = i;               // R
        2: vbyte = 255 - i;         // G
        default: vbyte = i ^ 8'h55; // B
      endcase
    end else vbyte = 8'h00;
  end
endfunction

// byte swapped window: VRAM byte 2k is the low byte of SDRAM word k
function [15:0] sword(input [23:0] a);
  integer n;
  begin
    n = (a - 24'h600000) * 2;
    sword = { vbyte(n+1), vbyte(n) };
  end
endfunction

// ---- model of port 3 of sdram.sv: slot every 12 clocks, ack 9 clocks later ----
reg [3:0]  slot = 0;
reg        cs_d = 0, taken = 0;
reg [4:0]  busy = 0;
reg [23:0] la;
always @(posedge clk) begin
  cs_d <= p3_cs;
  if (!p3_cs) taken <= 0;
  slot <= (slot == 4'd11) ? 4'd0 : slot + 4'd1;
  if (busy != 0) begin
    busy <= busy - 1;
    if (busy == 1) begin
      p3_dout   <= sword(la);
      p3_dout48 <= { sword(la+1), sword(la+2), sword(la+3) };
      p3_ack    <= ~p3_ack;
    end
  end else if (slot == 0 && p3_cs && cs_d && !taken) begin
    taken <= 1; la <= p3_addr; busy <= 5'd9;
  end
end

// ---- checker -------------------------------------------------------------
function [23:0] expect_rgb(input integer x, input integer y);
  reg [7:0] i;
  begin
    i = (x*3 + y) & 255;
    expect_rgb = { i, 8'd255 - i, i ^ 8'h55 };
  end
endfunction

integer frame = 0, errors = 0, checked = 0;
always @(posedge clk_pixel) if (cx == 0 && cy == 0) frame <= frame + 1;

always @(negedge clk_pixel) begin
  if (frame >= 3 && rtg_active) begin
    if (cy < 480 && cx >= 40 && cx < 680) begin
      checked = checked + 1;
      if (rgb !== expect_rgb(cx - 40, cy)) begin
        errors = errors + 1;
        if (errors < 10) $display("ERR frame %0d x=%0d y=%0d got %h exp %h", frame, cx-40, cy, rgb, expect_rgb(cx-40, cy));
      end
    end else if (rgb !== 24'h0) begin
      errors = errors + 1;
      if (errors < 10) $display("ERR border not black x=%0d y=%0d rgb=%h", cx, cy, rgb);
    end
  end
end

initial begin
  #60_000_000;   // ~3.5 frames
  $display("frames=%0d active=%0d checked=%0d errors=%0d", frame, rtg_active, checked, errors);
  if (checked > 0 && errors == 0) $display("PASS"); else $display("FAIL");
  $finish;
end
endmodule
