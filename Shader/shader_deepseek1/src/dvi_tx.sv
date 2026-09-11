// DVI送信: TMDSエンコード + シリアライズ + LVDS出力
module dvi_tx (
    input  logic       clk_pix,
    input  logic       clk_ser,
    input  logic       rst,
    input  logic [7:0] r,
    input  logic [7:0] g,
    input  logic [7:0] b,
    input  logic       hsync,
    input  logic       vsync,
    input  logic       de,
    output logic       tx_clk_p,
    output logic       tx_clk_n,
    output logic       tx_d0_p,
    output logic       tx_d0_n,
    output logic       tx_d1_p,
    output logic       tx_d1_n,
    output logic       tx_d2_p,
    output logic       tx_d2_n
);

    logic [9:0] tmds_r, tmds_g, tmds_b;
    logic ser_r, ser_g, ser_b, ser_clk;

    // TMDSエンコーダ (R, G, B)
    tmds_encoder u_enc_r (
        .clk        (clk_pix),
        .rst        (rst),
        .data_in    (r),
        .control_in (2'b00),
        .blank_in   (~de),
        .tmds_out   (tmds_r)
    );

    tmds_encoder u_enc_g (
        .clk        (clk_pix),
        .rst        (rst),
        .data_in    (g),
        .control_in (2'b00),
        .blank_in   (~de),
        .tmds_out   (tmds_g)
    );

    // Blueチャネルはブランキング期間に同期信号を載せる
    tmds_encoder u_enc_b (
        .clk        (clk_pix),
        .rst        (rst),
        .data_in    (b),
        .control_in ({vsync, hsync}),
        .blank_in   (~de),
        .tmds_out   (tmds_b)
    );

    // シリアライザ (10:1)
    oser16_wrap u_oser_r (
        .clk_pix (clk_pix),
        .clk_ser (clk_ser),
        .rst     (rst),
        .data    (tmds_r),
        .serial  (ser_r)
    );

    oser16_wrap u_oser_g (
        .clk_pix (clk_pix),
        .clk_ser (clk_ser),
        .rst     (rst),
        .data    (tmds_g),
        .serial  (ser_g)
    );

    oser16_wrap u_oser_b (
        .clk_pix (clk_pix),
        .clk_ser (clk_ser),
        .rst     (rst),
        .data    (tmds_b),
        .serial  (ser_b)
    );

    // クロックチャネル: ピクセルクロック周波数の方形波
    // 0000011111 を10倍クロックでシリアライズ → 5サイクルHigh/5サイクルLow
    oser16_wrap u_oser_clk (
        .clk_pix (clk_pix),
        .clk_ser (clk_ser),
        .rst     (rst),
        .data    (10'b0000011111),
        .serial  (ser_clk)
    );

    // LVDS差動出力バッファ
    ELVDS_OBUF u_obuf_clk (.I(ser_clk), .O(tx_clk_p), .OB(tx_clk_n));
    ELVDS_OBUF u_obuf_d0  (.I(ser_b),   .O(tx_d0_p),  .OB(tx_d0_n));  // D0 = Blue
    ELVDS_OBUF u_obuf_d1  (.I(ser_g),   .O(tx_d1_p),  .OB(tx_d1_n));  // D1 = Green
    ELVDS_OBUF u_obuf_d2  (.I(ser_r),   .O(tx_d2_p),  .OB(tx_d2_n));  // D2 = Red

endmodule