//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12 (64-bit) 
//Created Time: 2026-09-18 20:22:12
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]
create_generated_clock -name clk_100 -source [get_ports {clk}] -master_clock clk -multiply_by 2 [get_nets {clk_100}]
create_generated_clock -name clk_5x -source [get_ports {clk}] -master_clock clk -divide_by 5 -multiply_by 37 [get_nets {clk_5x}]
create_generated_clock -name clk_pixel -source [get_nets {clk_5x}] -master_clock clk_5x -divide_by 5 [get_nets {clk_pixel}]
set_input_delay -clock clk 2 -max [get_ports {rst_n}]
set_input_delay -clock clk 0.5 -min [get_ports {rst_n}]
set_input_delay -clock clk 10 -max [get_ports {sd_dat}]
set_input_delay -clock clk 0 -min [get_ports {sd_dat}]
set_input_delay -clock clk 2 -max [get_ports {explode_btn}]
set_input_delay -clock clk 0.5 -min [get_ports {explode_btn}]

# ============================================================================
# クロックドメイン間の非同期関係を宣言する。
#   SD 読出 (clk) / 表示 (clk_pixel, clk_5x) / メモリ (clk_100)
#   は VFB の非同期 FIFO を介して結合されるため、相互に非同期 (false path)。
#   memory_clk / dma_clk は Gowin DDR3 IP が内部でタイミングを処理するため
#   手動制約しない (リファレンス HDMI2HDMI と同一方針)。
# ============================================================================
set_clock_groups -asynchronous -group [get_clocks {clk}] -group [get_clocks {clk_pixel clk_5x}] -group [get_clocks {clk_100}]
