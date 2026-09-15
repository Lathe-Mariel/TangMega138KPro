//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12 (64-bit) 
//Created Time: 2026-09-15 21:54:38
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]
create_generated_clock -name clk_100 -source [get_ports {clk}] -master_clock clk -divide_by 1 -multiply_by 2 [get_nets {clk_100}]
create_generated_clock -name clk_5x -source [get_ports {clk}] -master_clock clk -divide_by 3 -multiply_by 25 [get_nets {clk_5x}]
set_input_delay -clock clk 2 -max [get_ports {rst_n}]
set_input_delay -clock clk 0.5 -min [get_ports {rst_n}]
set_input_delay -clock clk 2 -max [get_ports {sw0}]
set_input_delay -clock clk 2 -max [get_ports {sw1}]
set_output_delay -clock clk_100 2 -max [get_ports {state_led[*]}]
