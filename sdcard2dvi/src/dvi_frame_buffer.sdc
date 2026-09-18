//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12 (64-bit)

// システムクロック 50MHz
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]

// リセット入力遅延
set_input_delay -clock clk 2 -max [get_ports {rst_n}]
set_input_delay -clock clk 0.5 -min [get_ports {rst_n}]

// SDカード MISO (sd_dat) 入力遅延 (SPI クロックは内部生成)
set_input_delay -clock clk 10 -max [get_ports {sd_dat}]
set_input_delay -clock clk 0 -min [get_ports {sd_dat}]
