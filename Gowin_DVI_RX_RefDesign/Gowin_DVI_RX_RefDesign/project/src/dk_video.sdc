//Copyright (C)2014-2025 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12.01 (64-bit) 
//Created Time: 2025-12-26 15:42:54
create_clock -name I_tmds_clk_p -period 13.468 -waveform {0 6.734} [get_ports {I_tmds_clk_p}] -add
create_clock -name hclkx5 -period 2.694 -waveform {0 1.347} [get_nets {DVI_RX_Top_inst/dvi2rgb_inst/hclkx5}] -add
create_clock -name I_clk -period 20 -waveform {0 10} [get_ports {I_clk}] -add
create_clock -name rx0_pclk -period 13.468 -waveform {0 6.734} [get_nets {rx0_pclk}] -add
set_clock_groups -exclusive -group [get_clocks {rx0_pclk}] -group [get_clocks {hclkx5}] -group [get_clocks {I_tmds_clk_p}]
