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

/*
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
    );*/

logic [15:0] shader_output;
logic [11:0] frame_counter;

pixel_render inst_shader(
.clk(clk_pix),
.rst_n(rst_n),
.start(rst_n),      // qx_in/qy_in/time_inが有効、計算開始
.qx_in({8'b0,hcount}),      // 画面空間座標 (アスペクト補正済み, -1..1相当)
.qy_in({8'b0,vcount}),
.time_in({8'b0,frame_counter}),    // iTime
.busy(),
.done(),       // 1クロックパルス
.rgb565(shader_output)
);

    always_ff @(posedge clk_pix)begin
        frame_counter <= frame_counter + 12'b1;
    end

assign {r,g,b} = shader_output;

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