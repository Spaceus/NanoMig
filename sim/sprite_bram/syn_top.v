// top level for a synthesis of sprite_ram alone, see syn.tcl
module syn_top (
  input  wire        clk,
  input  wire        wea,
  input  wire  [3:0] addra,
  input  wire [15:0] dina,
  input  wire  [2:0] addrb,
  input  wire        selb,
  output wire [31:0] doutb
);

sprite_ram #(.BRAM(1)) ram (
  .clk(clk), .wea(wea), .addra(addra), .dina(dina),
  .addrb(addrb), .selb(selb), .doutb(doutb)
);

endmodule
