//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
// 50MHz システムクロック
create_clock -name clk_50m -period 20 -waveform {0 10} [get_ports {clk_50m}]

// シリアルクロック 371.25MHz (PLL出力)
create_generated_clock -name clk_ser -source [get_ports {clk_50m}] -master_clock clk_50m -divide_by 40 -multiply_by 297 [get_nets {clk_ser}]

// ピクセルクロック 74.25MHz (CLKDIV出力)
create_generated_clock -name clk_pix -source [get_ports {clk_50m}] -master_clock clk_50m -divide_by 200 -multiply_by 297 [get_nets {clk_pix}]
