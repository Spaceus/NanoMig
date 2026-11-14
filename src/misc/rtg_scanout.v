//
// rtg_scanout.v
//
// RTG scanout, first step: fixed 640x480 8 bit CLUT picture read from SDRAM
// (UNTESTED sketch, see doc/RTG_PRIMER25K.md).
//
// The CPU needs no register block. It only writes into the RTG window
// ($02000000 ... $023fffff, mapped to the SDRAM at 12 MB .. 16 MB):
//
//   offset 0x000000 .. 0x04afff   frame buffer, 640 bytes per line, 1 byte per pixel
//   offset 0x3ff000               control word, 16 bit: 0x5254 ("RT") = RTG on, else off
//   offset 0x3ff400 .. 0x3ff7ff   palette, 256 entries of 4 bytes: 00 RR GG BB
//
// The control word and the palette are re-read once per frame during the
// vertical blanking, so a driver only has to write memory. Everything is
// read through the 4 word burst port 3 of sdram.sv.
//
// Byte order: the CPU wrapper byte swaps the RTG window, so VRAM byte n
// is the low byte (n even) or the high byte (n odd) of SDRAM word n/2.
//
// Timing: the picture is centred in the 720x480 HDMI frame (NTSC timing),
// so the HDMI timing must be forced to pal_mode=0, screen=0 by the caller
// while rtg_active is set.
//

`default_nettype none

module rtg_scanout #(
  parameter [23:0] VRAM_BASE   = 24'h600000,  // SDRAM word address of VRAM offset 0 (byte 12 MB)
  parameter [23:0] CTRL_BASE   = 24'h7ff800,  // VRAM_BASE + 0x3ff000/2
  parameter [23:0] PAL_BASE    = 24'h7ffa00,  // VRAM_BASE + 0x3ff400/2
  parameter [10:0] X_OFFSET    = 11'd40,      // (720-640)/2
  parameter [9:0]  V_ACTIVE    = 10'd480,
  parameter [8:0]  PITCH_WORDS = 9'd320,      // 640 bytes
  parameter [8:0]  LINE_BURSTS = 9'd80        // 320 words / 4
) (
  // memory side, 85 MHz
  input  wire        clk,
  input  wire        reset,

  output reg         p3_cs,
  output reg  [23:0] p3_addr,
  input  wire [15:0] p3_dout,
  input  wire [47:0] p3_dout48,
  input  wire        p3_ack,

  // video side, hdmi pixel clock and hdmi pixel counters
  input  wire        clk_pixel,
  input  wire [10:0] cx,
  input  wire [9:0]  cy,

  output wire [23:0] rgb,
  output reg         rtg_active = 1'b0  // RTG picture is shown (latched at frame start)
);

// ------------------------------------------------------------------------
// pixel side: line events for the fetcher
// ------------------------------------------------------------------------

reg       ln_tgl = 1'b0;
reg [9:0] ln_y   = 10'd0;

always @(posedge clk_pixel) begin
  if (cx == 11'd4) ln_y   <= cy;       // stable for a whole line ...
  if (cx == 11'd8) ln_tgl <= ~ln_tgl;  // ... before the event is raised
end

// ------------------------------------------------------------------------
// memory side
// ------------------------------------------------------------------------

reg [2:0] tgl_s = 3'b000;
always @(posedge clk) tgl_s <= { tgl_s[1:0], ln_tgl };
wire ln_ev = tgl_s[2] ^ tgl_s[1];

reg rtg_en = 1'b0;                 // set from the control word

// line buffer: 2 lines of 320 words, the line parity selects the half
reg [15:0] lb [0:1023];
reg        lb_we;
reg [9:0]  lb_wa;
reg [15:0] lb_wd;

always @(posedge clk)
  if (lb_we) lb[lb_wa] <= lb_wd;

// palette: 256 x 24 bit
reg [23:0] pal [0:255];
reg        pal_we;
reg [7:0]  pal_wa;
reg [23:0] pal_wd;

always @(posedge clk)
  if (pal_we) pal[pal_wa] <= pal_wd;

localparam [2:0] S_IDLE  = 3'd0,
                 S_REQ   = 3'd1,
                 S_WAIT  = 3'd2,
                 S_STORE = 3'd3,
                 S_PAUSE = 3'd4;

localparam [1:0] K_LINE = 2'd0,
                 K_CTRL = 2'd1,
                 K_PAL  = 2'd2;

reg [2:0]  st = S_IDLE;
reg [1:0]  kind;
reg [9:0]  fl;                     // line being fetched
reg [8:0]  bcnt;                   // burst counter
reg [63:0] wq;                     // burst data, w0 w1 w2 w3
reg [2:0]  wi;                     // words written so far
reg        ack_d;

// address of the current burst
// fl*320 = fl*256 + fl*64
wire [23:0] line_off  = {6'd0, fl, 8'd0} + {8'd0, fl, 6'd0};
wire [23:0] addr_line = VRAM_BASE + line_off + {15'd0, bcnt[6:0], 2'b00};
wire [23:0] addr_ctrl = CTRL_BASE;
wire [23:0] addr_pal  = PAL_BASE + {15'd0, bcnt[6:0], 2'b00};

// the four words of the last burst (w0 = first word)
wire [15:0] w0 = wq[63:48];
wire [15:0] w1 = wq[47:32];
wire [15:0] w2 = wq[31:16];
wire [15:0] w3 = wq[15: 0];
wire [15:0] wsel = (wi[1:0] == 2'd0) ? w0 :
                   (wi[1:0] == 2'd1) ? w1 :
                   (wi[1:0] == 2'd2) ? w2 : w3;

always @(posedge clk) begin
  lb_we  <= 1'b0;
  pal_we <= 1'b0;
  ack_d  <= p3_ack;

  if (reset) begin
    st      <= S_IDLE;
    p3_cs   <= 1'b0;
    rtg_en  <= 1'b0;
  end else begin
    case (st)
      S_IDLE: begin
        p3_cs <= 1'b0;
        if (ln_ev) begin
          if (rtg_en && ln_y < V_ACTIVE - 10'd1) begin
            // prefetch the next visible line
            kind <= K_LINE; fl <= ln_y + 10'd1; bcnt <= 9'd0; st <= S_REQ;
          end else if (rtg_en && ln_y == V_ACTIVE - 10'd1) begin
            // last visible line: fetch line 0 of the next frame
            kind <= K_LINE; fl <= 10'd0; bcnt <= 9'd0; st <= S_REQ;
          end else if (ln_y == V_ACTIVE) begin
            // blanking: control word and palette
            kind <= K_CTRL; bcnt <= 9'd0; st <= S_REQ;
          end
        end
      end

      S_REQ: begin
        case (kind)
          K_LINE: p3_addr <= addr_line;
          K_CTRL: p3_addr <= addr_ctrl;
          default: p3_addr <= addr_pal;
        endcase
        p3_cs <= 1'b1;
        st    <= S_WAIT;
      end

      S_WAIT:
        if (p3_ack != ack_d) begin
          p3_cs <= 1'b0;
          wq    <= { p3_dout, p3_dout48 };
          wi    <= 3'd0;
          st    <= S_STORE;
        end

      S_STORE: begin
        // write the 4 burst words, one per clock (p3_cs is low during this
        // time which re-arms port 3 of the sdram)
        wi <= wi + 3'd1;
        case (kind)
          K_LINE: begin
            lb_we <= 1'b1;
            lb_wa <= { fl[0], bcnt[6:0], wi[1:0] };
            lb_wd <= wsel;
          end
          K_PAL: begin
            // two entries per burst, each is the VRAM byte sequence 00 RR GG BB,
            // i.e. word 0 = {RR,00} and word 1 = {BB,GG}
            if (wi == 3'd1) begin
              pal_we <= 1'b1;
              pal_wa <= { bcnt[6:0], 1'b0 };
              pal_wd <= { w0[15:8], w1[7:0], w1[15:8] };    // R, G, B
            end
            if (wi == 3'd3) begin
              pal_we <= 1'b1;
              pal_wa <= { bcnt[6:0], 1'b1 };
              pal_wd <= { w2[15:8], w3[7:0], w3[15:8] };
            end
          end
          default: ;
        endcase

        if (wi == 3'd3) st <= S_PAUSE;
      end

      S_PAUSE: begin
        // control word: first word of the burst
        if (kind == K_CTRL) begin
          // the CPU writes the 16 bit word $5254; the RTG window is byte swapped
          // so it shows up as 0x5452 in the SDRAM
          rtg_en <= (w0 == 16'h5452);
          kind   <= K_PAL;
          bcnt   <= 9'd0;
          st     <= S_REQ;
        end else if (kind == K_PAL) begin
          if (bcnt == 9'd127) st <= S_IDLE;
          else begin bcnt <= bcnt + 9'd1; st <= S_REQ; end
        end else begin
          if (bcnt == LINE_BURSTS - 9'd1) st <= S_IDLE;
          else begin bcnt <= bcnt + 9'd1; st <= S_REQ; end
        end
      end

      default: st <= S_IDLE;
    endcase
  end
end

// ------------------------------------------------------------------------
// pixel side: line buffer -> palette -> rgb
// ------------------------------------------------------------------------

// rtg_en crosses into the pixel domain, it is only taken over at frame start
reg [1:0] en_s = 2'b00;
always @(posedge clk_pixel) begin
  en_s <= { en_s[0], rtg_en };
  if (cx == 11'd0 && cy == 10'd0) rtg_active <= en_s[1];
end

// look ahead by 3 clocks (line buffer, byte select, palette): the hdmi core
// expects the rgb value of the pixel at (cx,cy) in the same clock cycle
wire [10:0] xn     = cx + 11'd3;
wire        in_x   = (xn >= X_OFFSET) && (xn < X_OFFSET + 11'd640);
wire        in_y   = (cy < V_ACTIVE);
wire [9:0]  px     = xn[9:0] - X_OFFSET[9:0];     // 0..639
wire [9:0]  rd_a   = { cy[0], px[9:1] };

reg [15:0] lb_q;
reg        sel_hi_d;
reg        act_d;
reg        act_dd;
reg        act_ddd;
reg [7:0]  idx;
reg [23:0] pal_q;

always @(posedge clk_pixel) begin
  lb_q     <= lb[rd_a];
  sel_hi_d <= px[0];
  act_d    <= in_x & in_y;

  idx      <= sel_hi_d ? lb_q[15:8] : lb_q[7:0];
  act_dd   <= act_d;

  act_ddd  <= act_dd;

  pal_q    <= pal[idx];
end

assign rgb = act_ddd ? pal_q : 24'h000000;

endmodule

`default_nettype wire
