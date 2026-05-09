
module video_top
(
    input             I_clk           , //50Mhz
    input             rst_sw          ,
    input             sw0             ,
    output     [5:0]  O_led           , 
    input             I_tmds_clk_p    ,
    input             I_tmds_clk_n    ,
    input      [2:0]  I_tmds_data_p   ,//{r,g,b}
    input      [2:0]  I_tmds_data_n   ,
    output            O_tmds_clk_p    ,
    output            O_tmds_clk_n    ,
    output     [2:0]  O_tmds_data_p   ,//{r,g,b}
    output     [2:0]  O_tmds_data_n   ,
    inout             IO_sda          ,
    input             I_scl           ,
    output            fan           
);

//==================================================
reg  [31:0] run_cnt;
wire        running;

//-------------------------
wire        rx0_pclk   ;
wire        rx0_vsync  ;
wire        rx0_hsync  ;
wire        rx0_de     ;
wire [7:0]  rx0_r      ; 
wire [7:0]  rx0_g      ; 
wire [7:0]  rx0_b      ; 
wire		rx_pll_lock	  ;
wire [3:0]  pll_phase     ;  
wire        pll_phase_lock;
logic I_rst_n;

assign fan = 1'b1;
assign I_rst_n = 1'b1;

//------------------------------------
wire serial_clk;
wire pll_lock;

wire hdmi4_rst_n;

//===================================================
//LED test
always @(posedge I_clk or negedge I_rst_n) //I_clk
begin
    if(!I_rst_n)
        run_cnt <= 32'd0;
    else if(run_cnt >= 32'd50_000_000)
        run_cnt <= 32'd50_000_000;
    else
        run_cnt <= run_cnt + 1'b1;
end

assign  running = (run_cnt < 32'd25_000_000) ? 1'b1 : 1'b0;

assign  O_led[0] = running;
assign  O_led[1] = ~pll_phase_lock;
assign  O_led[2] = 1'b0;
assign  O_led[3] = ~I_rst_n;
assign  O_led[4] = rst_sw;
assign  O_led[5] = sw0;

//===========================================================================
EDID_PROM_Top EDID_PROM_Top_inst 
(
    .I_clk     (I_clk  ),//>= 5MHz, <=200MHz 
    .I_rst_n   (I_rst_n),
    .I_scl     (I_scl  ),    
    .IO_sda    (IO_sda )
);

//=======================================================
//TMDS RX(HDMI3)
DVI_RX_Top DVI_RX_Top_inst
(
    .I_rst_n         (I_rst_n       ),// active low 
    .I_tmds_clk_p    (I_tmds_clk_p  ),  
    .I_tmds_clk_n    (I_tmds_clk_n  ),  
    .I_tmds_data_p   (I_tmds_data_p ),//{r,g,b}
    .I_tmds_data_n   (I_tmds_data_n ),  
	.O_pll_lock		 (rx_pll_lock   ),
    .O_pll_phase     (pll_phase     ),  
    .O_pll_phase_lock(pll_phase_lock),       
    .O_rgb_clk       (rx0_pclk      ),
    .O_rgb_vs        (rx0_vsync     ),
    .O_rgb_hs        (rx0_hsync     ),
    .O_rgb_de        (rx0_de        ),
    .O_rgb_r         (rx0_r         ),
    .O_rgb_g         (rx0_g         ),
    .O_rgb_b         (rx0_b         )
);


//==============================================================================
//TMDS TX(HDMI4)
/*
TMDS_rPLL u_tmds_rpll
(.clkin     (rx0_pclk  )     //input clk 
,.clkout    (serial_clk)     //output clk 
,.lock      (pll_lock  )     //output lock
);*/

Gowin_PLL your_instance_name(
   .lock(pll_lock), //output lock
   .clkout0(serial_clk), //output clkout0
   .clkin(rx0_pclk) //input clkin
);

assign hdmi4_rst_n = I_rst_n & pll_lock;


DVI_TX_Top DVI_TX_Top_inst
(
    .I_rst_n       (hdmi4_rst_n   ),  //asynchronous reset, low active
    .I_serial_clk  (serial_clk    ),
    .I_rgb_clk     (rx0_pclk      ),  //pixel clock
    .I_rgb_vs      (rx0_vsync     ), 
    .I_rgb_hs      (rx0_hsync     ),    
    .I_rgb_de      (rx0_de        ), 
    .I_rgb_r       (rx0_r         ),  
    .I_rgb_g       (rx0_g         ),  
    .I_rgb_b       (rx0_b         ),  
    .O_tmds_clk_p  (O_tmds_clk_p  ),
    .O_tmds_clk_n  (O_tmds_clk_n  ),
    .O_tmds_data_p (O_tmds_data_p ),  //{r,g,b}
    .O_tmds_data_n (O_tmds_data_n )
);

endmodule