//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12 (64-bit)

// システムクロック 50MHz
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]

// メモリPLL (Gowin_PLL): clk_100 = 100MHz (clkout1)
//  ※ memory_clk (400MHz) / clk_5x (371.25MHz) / clk_pixel (74.25MHz) は
//    PLL / CLKDIV / DDR3 IP が内部で自動生成するため手動制約しない。
create_generated_clock -name clk_100 -source [get_ports {clk}] -master_clock clk -multiply_by 2 [get_nets {clk_100}]

// リセット入力遅延
set_input_delay -clock clk 2 -max [get_ports {rst_n}]
set_input_delay -clock clk 0.5 -min [get_ports {rst_n}]

// SDカード MISO (sd_dat) 入力遅延 (SPI クロックは内部生成)
set_input_delay -clock clk 10 -max [get_ports {sd_dat}]
set_input_delay -clock clk 0 -min [get_ports {sd_dat}]
