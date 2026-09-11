// 50MHz → 40MHz (ピクセルクロック) / 400MHz (シリアルクロック)
module pll (
    input  logic clk_in,    // 50 MHz
    output logic clk_pix,   // 40 MHz
    output logic clk_ser,   // 400 MHz
    output logic locked
);

    logic lock_ser, lock_pix;

    // シリアルクロック用 PLL: 50MHz → 400MHz (VCO=400MHz)
    rPLL #(
        .FCLKIN("50"),
        .DYN_SDIV_EN("false"),
        .IDIV_SEL(0),       // ÷1
        .FBDIV_SEL(7),      // ×8 → VCO 400MHz
        .ODIV_SEL(0),       // ÷1 → 400MHz
        .CLKFB_SEL("internal"),
        .CLKOUTD_SEL("CLKOUT"),
        .CLKOUTD3_SEL("CLKOUT"),
        .CLKOUTD_EN("false"),
        .CLKOUTD3_EN("false"),
        .DYN_DIV_EN("false"),
        .RESET_I_EN("false"),
        .RESET_P_EN("false"),
        .GND_EN("false"),
        .PSDA_SEL("0000"),
        .DUTYDA_SEL("1000"),
        .FDLY_SEL("0000")
    ) u_pll_ser (
        .CLKOUT  (clk_ser),
        .CLKOUTP (),
        .CLKOUTD (),
        .CLKOUTD3(),
        .CLKFB   (),
        .CLKIN   (clk_in),
        .RESET   (1'b0),
        .RESET_P (1'b0),
        .FBDSEL  (6'b000000),
        .IDSEL   (6'b000000),
        .ODSEL   (6'b000000),
        .PSDA    (4'b0000),
        .DUTYDA  (4'b0000),
        .FDLY    (4'b0000),
        .LOCK    (lock_ser)
    );

    // ピクセルクロック用 PLL: 50MHz → 40MHz (VCO=200MHz)
    rPLL #(
        .FCLKIN("50"),
        .DYN_SDIV_EN("false"),
        .IDIV_SEL(0),       // ÷1
        .FBDIV_SEL(3),      // ×4 → VCO 200MHz
        .ODIV_SEL(4),       // ÷5 → 40MHz
        .CLKFB_SEL("internal"),
        .CLKOUTD_SEL("CLKOUT"),
        .CLKOUTD3_SEL("CLKOUT"),
        .CLKOUTD_EN("false"),
        .CLKOUTD3_EN("false"),
        .DYN_DIV_EN("false"),
        .RESET_I_EN("false"),
        .RESET_P_EN("false"),
        .GND_EN("false"),
        .PSDA_SEL("0000"),
        .DUTYDA_SEL("1000"),
        .FDLY_SEL("0000")
    ) u_pll_pix (
        .CLKOUT  (clk_pix),
        .CLKOUTP (),
        .CLKOUTD (),
        .CLKOUTD3(),
        .CLKFB   (),
        .CLKIN   (clk_in),
        .RESET   (1'b0),
        .RESET_P (1'b0),
        .FBDSEL  (6'b000000),
        .IDSEL   (6'b000000),
        .ODSEL   (6'b000000),
        .PSDA    (4'b0000),
        .DUTYDA  (4'b0000),
        .FDLY    (4'b0000),
        .LOCK    (lock_pix)
    );

    assign locked = lock_ser & lock_pix;

endmodule