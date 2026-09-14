module top (
    input  logic clk_50m,        // 50MHz システムクロック
    input  logic rst_n,          // リセットボタン (アクティブLow)
    input  logic [7:0] leds,     // 追加: LED入力信号
    output logic hdmi_tx_clk_p,  // HDMI TX クロック +
    output logic hdmi_tx_clk_n,  // HDMI TX クロック -
    output logic[2:0] hdmi_tx_p,   // データチャネル0 (Blue) +
    output logic[2:0] hdmi_tx_n   // データチャネル0 (Blue) -
);

    logic clk_pix, clk_ser, pll_locked;
    logic rst_pix;
    logic hsync, vsync, de;
    logic [11:0] hcount, vcount;
    logic [7:0] r, g, b;

/*
    // PLL: 50MHz → 40MHz (ピクセルクロック) / 400MHz (シリアルクロック)
    pll u_pll (
        .clk_in (clk_50m),
        .clk_pix(clk_pix),
        .clk_ser(clk_ser),
        .locked (pll_locked)
    );
*/

    Gowin_PLL u_pll(
        .clkin(clk_50m), //input  clkin
        .init_clk(clk_50m), //input  init_clk
        .clkout0(clk_ser), //output  clkout0 371.25MHz
        .lock(pll_locked), //output  lock
        .reset(~rst_n) //input  reset
);

    Gowin_CLKDIV u_divider(
        .clkout(clk_pix), //output clkout 74.25MHz
        .hclkin(clk_ser), //input hclkin
        .resetn(rst_n) //input resetn
    );

    // リセット同期化 (ピクセルクロックドメイン)
    always_ff @(posedge clk_pix) begin
        rst_pix <= ~pll_locked | ~rst_n;
    end

    // タイミング生成 (800x600@60Hz)
    vga_timing u_timing (
        .clk   (clk_pix),
        .rst   (rst_pix),
        .hsync (hsync),
        .vsync (vsync),
        .de    (de),
        .hcount(hcount),
        .vcount(vcount)
    );

    // 座標と時間から色を生成するシェーダ
    shader u_shader (
        .clk   (clk_pix),
        .rst   (rst_pix),
        .de    (de),
        .hcount(hcount),
        .vcount(vcount),
        .r     (r),
        .g     (g),
        .b     (b)
    );

	DVI_TX_Top u_dvi_tx(
		.I_rst_n(rst_n), //input I_rst_n
		.I_serial_clk(clk_ser), //input I_serial_clk
		.I_rgb_clk(clk_pix), //input I_rgb_clk
		.I_rgb_vs(vsync), //input I_rgb_vs
		.I_rgb_hs(hsync), //input I_rgb_hs
		.I_rgb_de(de), //input I_rgb_de
		.I_rgb_r(r), //input [7:0] I_rgb_r
		.I_rgb_g(g), //input [7:0] I_rgb_g
		.I_rgb_b(b), //input [7:0] I_rgb_b
		.O_tmds_clk_p(hdmi_tx_clk_p), //output O_tmds_clk_p
		.O_tmds_clk_n(hdmi_tx_clk_n), //output O_tmds_clk_n
		.O_tmds_data_p(hdmi_tx_p), //output [2:0] O_tmds_data_p
		.O_tmds_data_n(hdmi_tx_n) //output [2:0] O_tmds_data_n
	);

endmodule