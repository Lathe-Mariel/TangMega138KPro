// ============================================================
// Top Module: DVI Shader Output
// Board: Tang Mega 138K Pro Dock
// Resolution: 1920x1080 @ 30Hz
// Effect: 3D Space Tunnel Flight Shader
// ============================================================
module top (
    input  wire clk,        // 27MHz onboard oscillator
    input  wire rst_n,

    // DVI TMDS output (HDMI connector)
    output wire tmds_clk_p,
    output wire tmds_clk_n,
    output wire [2:0] tmds_data_p,
    output wire [2:0] tmds_data_n
);

// ─────────────────────────────────────────────
// Clock Generation
//   27MHz → PLL → 148.5MHz pixel clock (1080p30)
//                  742.5MHz TMDS serial clock (×5)
// ─────────────────────────────────────────────
wire clk_pixel;   //  MHz  (pixel clock for 1920×1080@30)
wire clk_tmds;    //  MHz  (×5, TMDS serialiser)
wire pll_lock;

    Gowin_PLL pll_inst(
        .clkin(clk), //input  clkin
        .clkout0(clk_tmds), //output  clkout0
        .clkout1(clk_pixel), //output  clkout1
        .lock(pll_lock), //output  lock
        .reset(!rst_n) //input  reset
);

wire rst = ~rst_n | ~pll_lock;

// ─────────────────────────────────────────────
// Video Timing Generator  1920×1080 @ 30 Hz
//   Total H: 2200  Total V: 1125
//   HSync: 44px  VSync: 5 lines
// ─────────────────────────────────────────────
wire [10:0] hcount;   // 0..2199
wire [10:0] vcount;   // 0..1124
wire hsync, vsync, de, field_start;

video_timing u_timing (
    .clk      (clk_pixel),
    .rst      (rst),
    .hcount   (hcount),
    .vcount   (vcount),
    .hsync    (hsync),
    .vsync    (vsync),
    .de       (de),
    .field_start(field_start)
);

// ─────────────────────────────────────────────
// Frame Counter (for animation time)
// ─────────────────────────────────────────────
reg [23:0] frame_cnt;
always @(posedge clk_pixel or posedge rst) begin
    if (rst) frame_cnt <= 0;
    else if (field_start) frame_cnt <= frame_cnt + 1;
end

// ─────────────────────────────────────────────
// Shader Pixel Generator
// ─────────────────────────────────────────────
wire [7:0] r_out, g_out, b_out;

shader_mountains u_shader (
    .clk      (clk_pixel),
    .rst      (rst),
    .hcount   (hcount),
    .vcount   (vcount),
    .de       (de),
    .frame_cnt(frame_cnt),
    .r        (r_out),
    .g        (g_out),
    .b        (b_out)
);

// ─────────────────────────────────────────────
// TMDS Encoder + Serialiser
// ─────────────────────────────────────────────

	DVI_TX_Top your_instance_name(
		.I_rst_n(rst_n), //input I_rst_n
		.I_serial_clk(clk_tmds), //input I_serial_clk
		.I_rgb_clk(clk_pixel), //input I_rgb_clk
		.I_rgb_vs(vsync), //input I_rgb_vs
		.I_rgb_hs(hsync), //input I_rgb_hs
		.I_rgb_de(de), //input I_rgb_de
		.I_rgb_r(r_out), //input [7:0] I_rgb_r
		.I_rgb_g(g_out), //input [7:0] I_rgb_g
		.I_rgb_b(b_out), //input [7:0] I_rgb_b
		.O_tmds_clk_p(tmds_clk_p), //output O_tmds_clk_p
		.O_tmds_clk_n(tmds_clk_n), //output O_tmds_clk_n
		.O_tmds_data_p(tmds_data_p), //output [2:0] O_tmds_data_p
		.O_tmds_data_n(tmds_data_n) //output [2:0] O_tmds_data_n
	);

endmodule
