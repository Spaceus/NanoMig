module sprite_ram #(
  parameter BRAM = 0   // 1: one block ram instead of 8 distributed RAM16 (DENISE_SPRITE_BRAM)
) (
  // Port write
  input  wire        clk,
  input  wire        wea,
  input  wire  [3:0] addra,
  input  wire [15:0] dina,

  // Port read
  input  wire  [2:0] addrb,
  input  wire        selb,   // block ram only: 0 reads the DATA (A) word, 1 the DATB (B) word
  output wire [31:0] doutb
);

// RAM16 version: the low half (bit 15:0) holds the DATA (A) words, the high
// half the DATB (B) words, both are read together.
//
// Block ram version: 16 words of 16 bit, written and read with the same
// address {buffer, bank, A/B}. Only one word is read at a time (selb), it
// comes in doutb[15:0]. A 32 bit wide block ram would give both words at
// once, but takes two block ram sites on the GW5A-25, a 16 bit one takes one.

generate if (BRAM) begin : g_bram

wire [15:0] q;
assign doutb = {16'd0, q};

`ifdef GOWIN

// One SDPB, 16 bit wide on both ports, instantiated directly so that it is
// certain to be a single block. With a 16 bit port AD[13:4] is the word
// address and ADA[1:0] are the byte enables. Bypass read mode: address in,
// data one clock later, and a read of a word written in the same clock
// returns the old word.
wire [31:0] do32;
assign q = do32[15:0];

SDPB #(
  .READ_MODE(1'b0),
  .BIT_WIDTH_0(16),
  .BIT_WIDTH_1(16),
  .BLK_SEL_0(3'b000),
  .BLK_SEL_1(3'b000),
  .RESET_MODE("SYNC")
) mem (
  .CLKA(clk),
  .CEA(wea),
  .BLKSELA(3'b000),
  .ADA({6'd0, addra, 2'b00, 2'b11}),
  .DI({16'd0, dina}),
  .CLKB(clk),
  .CEB(1'b1),
  .OCE(1'b1),
  .RESET(1'b0),
  .BLKSELB(3'b000),
  .ADB({6'd0, addrb, selb, 4'd0}),
  .DO(do32)
);

`else

// 16x16 block ram. Same latency as below: address in, data one clock later
(* ram_style = "block", syn_ramstyle = "block_ram" *)
reg [15:0] mem [0:15];
reg [15:0] q_r;
assign q = q_r;

always @(posedge clk)
  if (wea)
    mem[addra] <= dina;

always @(posedge clk)
  q_r <= mem[{addrb, selb}];

`endif

end else begin : g_dist

reg [15:0] mem0 [0:7];
reg [15:0] mem1 [0:7];

reg [2:0] addrb_r;

assign doutb = {mem1[addrb_r], mem0[addrb_r]};

always @(posedge clk) begin
  if (wea && !addra[0])
    mem0[addra[3:1]] <= dina;
  if (wea &&  addra[0])
    mem1[addra[3:1]] <= dina;
end

always @(posedge clk) begin
  addrb_r <= addrb;
end

end endgenerate

endmodule
