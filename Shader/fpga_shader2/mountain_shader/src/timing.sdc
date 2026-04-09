//==============================================================
// Timing Constraints (SDC)
// Project: DVI 3D Shader  –  Tang Mega 138K Pro Dock
//==============================================================

// ── Input clock ────────────────────────────────────────────
create_clock -name {clk_27m} -period 37.037 [get_ports {clk_27m}]

// ── PLL derived clocks ─────────────────────────────────────
// Pixel clock 148.5 MHz (period = 6.734 ns)
create_generated_clock -name {clk_pixel} \
    -source [get_ports {clk_27m}]    \
    -master_clock {clk_27m}          \
    -multiply_by 55 -divide_by 10   \
    [get_nets {u_pll/clkout0}]

// TMDS serial clock 742.5 MHz (period = 1.347 ns)
create_generated_clock -name {clk_tmds} \
    -source [get_ports {clk_27m}]    \
    -master_clock {clk_27m}          \
    -multiply_by 55 -divide_by 2    \
    [get_nets {u_pll/clkout1}]

// ── Path exceptions ────────────────────────────────────────
// The serialiser output path crosses clock domains (pixel→tmds)
// Mark as false path so STA doesn't try to time the serialiser data
set_false_path -from [get_clocks {clk_pixel}] -to [get_clocks {clk_tmds}]

// frame_cnt crosses from pixel clock only; no cross-domain issue.
