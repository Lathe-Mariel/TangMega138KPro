// ============================================================
// TMDS Serializer  (10:1)
// Uses Gowin OSER10 + ELVDS_OBUF primitives
// Tang Mega 138K Pro uses GW5AST-138B (Arora V)
// ============================================================
module tmds_serializer (
    input  wire        clk_pixel,   // parallel clock (148.5 MHz)
    input  wire        clk_tmds,    // serial  clock (742.5 MHz = ×5)
    input  wire        rst,
    input  wire [ 9:0] tmds_d,     // 10-bit TMDS word
    output wire        tmds_p,
    output wire        tmds_n
);

wire serial_out;

// Gowin OSER10 primitive (10:1 DDR serialiser)
// Data loads MSB-first: d0=LSB ... d9=MSB
OSER10 u_oser (
    .Q    (serial_out),
    .D0   (tmds_d[0]),
    .D1   (tmds_d[1]),
    .D2   (tmds_d[2]),
    .D3   (tmds_d[3]),
    .D4   (tmds_d[4]),
    .D5   (tmds_d[5]),
    .D6   (tmds_d[6]),
    .D7   (tmds_d[7]),
    .D8   (tmds_d[8]),
    .D9   (tmds_d[9]),
    .PCLK (clk_pixel),
    .FCLK (clk_tmds),
    .RESET(rst)
);

// LVDS output buffer
ELVDS_OBUF u_buf (
    .I  (serial_out),
    .O  (tmds_p),
    .OB (tmds_n)
);

endmodule
