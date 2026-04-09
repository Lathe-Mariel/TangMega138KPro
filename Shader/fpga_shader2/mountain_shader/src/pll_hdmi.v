// ============================================================
// PLL Wrapper  –  Tang Mega 138K Pro (GW5AST-138B / Arora-V)
//
// Input:  27 MHz  (on-board oscillator)
// Output0: 148.5 MHz  → pixel clock  (1080p30)
// Output1: 742.5 MHz  → TMDS serial clock (×5)
//
// Gowin PLLVR parameters (approximate, refine with IP-Core generator):
//   FREF = 27 MHz
//   IDIV = 2   → VCO input = 13.5 MHz
//   FBDIV = 55 → VCO = 742.5 MHz
//   ODIV0 = 5  → clkout0 = 742.5/5 = 148.5 MHz
//   ODIV1 = 1  → clkout1 = 742.5 MHz
// ============================================================
module pll_hdmi (
    input  wire clkin,
    output wire clkout0,   // 148.5 MHz pixel clock
    output wire clkout1,   // 742.5 MHz TMDS clock
    output wire lock
);

// Gowin Arora-V PLL primitive (GW5AST uses PLLVR)
// Replace this block with the IP-Core generator output if available.
PLLVR #(
    .FCLKIN    ("27"),        // MHz, string
    .IDIV_SEL  (2),           // input divider
    .FBDIV_SEL (55),          // feedback divider  → VCO=742.5MHz
    .ODIV0_SEL (5),           // output0 divider   → 148.5MHz
    .ODIV1_SEL (1),           // output1 divider   → 742.5MHz
    .ODIV0_FRAC(0),
    .ODIV0_FRAC_SEL(0),
    .CLKOUT0_EN("TRUE"),
    .CLKOUT1_EN("TRUE"),
    .CLKOUT2_EN("FALSE"),
    .CLKOUT3_EN("FALSE"),
    .CLKOUT4_EN("FALSE"),
    .CLKOUT0_DT_DIR(1'b1),
    .CLKOUT1_DT_DIR(1'b1),
    .CLKOUT0_DT_STEP(0),
    .CLKOUT1_DT_STEP(0),
    .CLK0_IN_SEL(1'b0),
    .CLK0_OUT_SEL(1'b0),
    .CLK1_IN_SEL(1'b0),
    .CLK1_OUT_SEL(1'b0),
    .CLKFB_SEL ("INTERNAL"),
    .DYN_DPS_EN("FALSE"),
    .GMCMODE   (3'b000),
    .DYN_IDIV_SEL  ("FALSE"),
    .DYN_FBDIV_SEL ("FALSE"),
    .DYN_ODIV0_SEL ("FALSE"),
    .DYN_ODIV1_SEL ("FALSE"),
    .DYN_ODIV2_SEL ("FALSE"),
    .DYN_ODIV3_SEL ("FALSE"),
    .DYN_ODIV4_SEL ("FALSE"),
    .VCOSEL    (2'b01)        // select VCO range 600~1250 MHz
) u_pll (
    .CLKIN   (clkin),
    .CLKFB   (1'b0),
    .RESET   (1'b0),
    .RESET_P (1'b0),
    .FBDSEL  (6'b0),
    .IDSEL   (6'b0),
    .ODSEL0  (6'b0),
    .ODSEL1  (6'b0),
    .ODSEL2  (6'b0),
    .ODSEL3  (6'b0),
    .ODSEL4  (6'b0),
    .PSDA    (4'b0),
    .DUTYDA  (4'b0),
    .FDLY    (4'b0),
    .CLKOUT0 (clkout0),
    .CLKOUT1 (clkout1),
    .CLKOUT2 (),
    .CLKOUT3 (),
    .CLKOUT4 (),
    .CLKOUTP (),
    .CLKOUTD3(),
    .LOCK    (lock)
);

endmodule
