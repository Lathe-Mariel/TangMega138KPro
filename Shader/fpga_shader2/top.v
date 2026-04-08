// ============================================================
// Top Module: DVI Shader Output
// Board: Tang Mega 138K Pro Dock
// Resolution: 1920x1080 @ 30Hz
// Effect: 3D Space Tunnel Flight Shader
// ============================================================
module top (
    input  wire clk_27m,        // 27MHz onboard oscillator
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
wire clk_pixel;   // 148.5 MHz  (pixel clock for 1920×1080@30)
wire clk_tmds;    // 742.5 MHz  (×5, TMDS serialiser)
wire pll_lock;

pll_hdmi u_pll (
    .clkin  (clk_27m),
    .clkout0(clk_pixel),   // 148.5 MHz
    .clkout1(clk_tmds),    // 742.5 MHz
    .lock   (pll_lock)
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
wire [9:0] tmds_d0, tmds_d1, tmds_d2, tmds_clk_w;

tmds_encoder u_enc_b (
    .clk(clk_pixel), .rst(rst),
    .data(b_out), .ctrl({vsync,hsync}), .de(de),
    .tmds(tmds_d0)
);
tmds_encoder u_enc_g (
    .clk(clk_pixel), .rst(rst),
    .data(g_out), .ctrl(2'b00), .de(de),
    .tmds(tmds_d1)
);
tmds_encoder u_enc_r (
    .clk(clk_pixel), .rst(rst),
    .data(r_out), .ctrl(2'b00), .de(de),
    .tmds(tmds_d2)
);

// TMDS serialiser × 4 channels (3 data + clock)
tmds_serializer u_ser0 (.clk_pixel(clk_pixel),.clk_tmds(clk_tmds),.rst(rst),.tmds_d(tmds_d0),.tmds_p(tmds_data_p[0]),.tmds_n(tmds_data_n[0]));
tmds_serializer u_ser1 (.clk_pixel(clk_pixel),.clk_tmds(clk_tmds),.rst(rst),.tmds_d(tmds_d1),.tmds_p(tmds_data_p[1]),.tmds_n(tmds_data_n[1]));
tmds_serializer u_ser2 (.clk_pixel(clk_pixel),.clk_tmds(clk_tmds),.rst(rst),.tmds_d(tmds_d2),.tmds_p(tmds_data_p[2]),.tmds_n(tmds_data_n[2]));
tmds_serializer u_ser_clk (.clk_pixel(clk_pixel),.clk_tmds(clk_tmds),.rst(rst),.tmds_d(10'b1111100000),.tmds_p(tmds_clk_p),.tmds_n(tmds_clk_n));

endmodule
