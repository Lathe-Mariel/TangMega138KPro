//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.11.01 (64-bit) 
//Created Time: 2026-04-12 01:37:44
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]
create_generated_clock -name clk_pixel -source [get_ports {clk}] -master_clock clk -divide_by 25 -multiply_by 37 [get_nets {clk_pixel}]
create_generated_clock -name clk_tmds -source [get_ports {clk}] -master_clock clk -divide_by 5 -multiply_by 37 [get_nets {clk_tmds}]
set_false_path -from [get_clocks {clk_pixel}] -to [get_clocks {clk_tmds}] 
