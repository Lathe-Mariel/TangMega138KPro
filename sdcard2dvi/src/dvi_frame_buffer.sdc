//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12 (64-bit) 
//Created Time: 2026-09-18 20:22:12
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]
create_generated_clock -name memory_clk -source [get_ports {clk}] -master_clock clk -multiply_by 8 [get_nets {memory_clk}]
create_generated_clock -name clk_5x -source [get_ports {clk}] -master_clock clk -divide_by 5 -multiply_by 37 [get_nets {clk_5x}]
create_generated_clock -name clk_pixel -source [get_nets {clk_5x}] -master_clock clk_5x -divide_by 5 [get_nets {clk_pixel}]
set_input_delay -clock clk 2 -max [get_ports {rst_n}]
set_input_delay -clock clk 0.5 -min [get_ports {rst_n}]
set_input_delay -clock clk 10 -max [get_ports {sd_dat}]
set_input_delay -clock clk 0 -min [get_ports {sd_dat}]
