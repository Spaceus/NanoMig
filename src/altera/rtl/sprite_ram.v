module sprite_ram #(
    parameter BRAM = 0   // only used by minimig-aga/sprite_ram.v, ignored here
) (
    input clk,
    input wea,
    input [3:0] addra,
    input [15:0] dina,
    input [2:0] addrb,
    input selb,          // only used by minimig-aga/sprite_ram.v, ignored here
    output [31:0] doutb
);

dpram_dif #(4,16,3,32)
(
    .clock       ( clk ),

    .address_a   ( addra ),
    .data_a      ( dina ),
    .wren_a      ( wea ),

    .address_b   ( addrb ),
    .q_b         ( {doutb[15:0],doutb[31:16]} )
);

endmodule
