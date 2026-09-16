//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12 (64-bit) 
//Created Time: 2026-09-16 19:40:46
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk_50m}]
create_generated_clock -name clk_ser -source [get_ports {clk_50m}] -master_clock clk -divide_by 5 -multiply_by 37 [get_nets {clk_ser}]
