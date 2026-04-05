//==============================================================================
// GOWIN Timing Constraint File (.sdc)
// Project  : DVI Frame Buffer with Image Composer
// Board    : Tang Mega 138K Pro Dock
// Device   : GW5AST-LV138FPG676A
// Updated  : 2026-04-04
//
// Clock Plan (all derived from 50 MHz system clock via PLL):
//
//   clk          50.000 MHz  System clock input (P16)
//   clk_pixel    74.250 MHz  Pixel clock for 1920x1080@30fps  (PLL_VIDEO)
//   clk_5x      371.250 MHz  TMDS serializer clock = clk_pixel x5 (PLL_VIDEO)
//   clk_ddr     400.000 MHz  DDR3 memory clock  (GOWIN DDR IP internal PLL)
//   clk_sys     100.000 MHz  Internal logic / AXI bus  (PLL_SYS)
//==============================================================================

//------------------------------------------------------------------------------
// Primary Clock - System Oscillator (50 MHz, Pin P16)
//------------------------------------------------------------------------------
create_clock -name {clk} -period 20.000 -waveform {0.000 10.000} [get_ports {clk}]

//------------------------------------------------------------------------------
// Derived Clocks - PLL_VIDEO output ports
//   PLL input  : clk (50 MHz)
//   clk_pixel  : 50 MHz x (74.25/50) = x1.485  → set by GOWIN PLL DIVSEL
//   clk_5x     : clk_pixel x 5 = 371.25 MHz
//------------------------------------------------------------------------------
create_generated_clock \
    -name {clk_pixel} \
    -source [get_ports {clk}] \
    -multiply_by 1485 \
    -divide_by   1000 \
    [get_nets {clk_pixel}]

create_generated_clock \
    -name {clk_5x} \
    -source [get_nets {clk_pixel}] \
    -multiply_by 5 \
    [get_nets {clk_5x}]

//------------------------------------------------------------------------------
// Derived Clock - PLL_SYS output (100 MHz internal logic)
//   PLL input  : clk (50 MHz)
//   clk_sys    : 50 MHz x 2 = 100 MHz
//------------------------------------------------------------------------------
create_generated_clock \
    -name {clk_100} \
    -source [get_ports {clk}] \
    -multiply_by 2 \
    [get_nets {clk_100}]

//------------------------------------------------------------------------------
// DDR3 Clock (400 MHz) - managed internally by GOWIN DDR IP
//   Declared here for reference; actual constraints are inside the IP.
//------------------------------------------------------------------------------
# create_generated_clock \
#     -name {clk_ddr} \
#     -source [get_ports {clk}] \
#     -multiply_by 8 \
#     [get_nets {clk_ddr}]

//------------------------------------------------------------------------------
// TMDS RX Recovered Clock
//   The DVI RX IP recovers a 74.25 MHz clock from the TMDS stream.
//   Declared as a virtual clock for cross-domain timing analysis.
//------------------------------------------------------------------------------
create_clock -name {clk_rx_pixel} -period 13.468

//------------------------------------------------------------------------------
// Clock Groups (asynchronous domains - no timing paths between them)
//------------------------------------------------------------------------------
set_clock_groups \
    -asynchronous \
    -group {clk clk_sys} \
    -group {clk_pixel clk_5x} \
    -group {clk_rx_pixel} \
    -group {clk_ddr}

//------------------------------------------------------------------------------
// Input / Output Delay (placeholder - adjust to board trace delays)
//------------------------------------------------------------------------------

# System reset (synchronous to clk_sys, 100 MHz period = 10 ns)
set_input_delay  -clock {clk} -max 2.0 [get_ports {rst_n}]
set_input_delay  -clock {clk} -min 0.5 [get_ports {rst_n}]

# User switches
set_input_delay  -clock {clk} -max 2.0 [get_ports {sw0}]
set_input_delay  -clock {clk} -max 2.0 [get_ports {sw1}]

# Status LEDs
set_output_delay -clock {clk_sys} -max 2.0 [get_ports {state_led[*]}]

//==============================================================================
// END OF TIMING CONSTRAINT FILE
//==============================================================================
