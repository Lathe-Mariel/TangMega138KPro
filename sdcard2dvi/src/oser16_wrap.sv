// OSER16 による 10:1 シリアライザ
module oser16_wrap (
    input  logic       clk_pix,   // ピクセルクロック (40MHz)
    input  logic       clk_ser,   // シリアルクロック (400MHz = 10×)
    input  logic       rst,
    input  logic [9:0] data,      // 10bit TMDSデータ
    output logic       serial     // シリアル出力
);

    OSER16 #(
        .TS_CLK_EN("false"),
        .TS_RESET("false"),
        .SDO0_INIT(1'b0),
        .SDO1_INIT(1'b0),
        .SDO2_INIT(1'b0),
        .SDO3_INIT(1'b0)
    ) u_oser16 (
        .SDO0      (serial),
        .SDO1      (),
        .SDO2      (),
        .SDO3      (),
        .Q0        (data[0]),
        .Q1        (data[1]),
        .Q2        (data[2]),
        .Q3        (data[3]),
        .Q4        (data[4]),
        .Q5        (data[5]),
        .Q6        (data[6]),
        .Q7        (data[7]),
        .Q8        (data[8]),
        .Q9        (data[9]),
        .Q10       (1'b0),
        .Q11       (1'b0),
        .Q12       (1'b0),
        .Q13       (1'b0),
        .Q14       (1'b0),
        .Q15       (1'b0),
        .FCLK      (clk_ser),
        .PCLK      (clk_pix),
        .RESET     (rst),
        .TS_RESET_I(1'b0),
        .TS_CLK_EN (1'b1),
        .TS_EN     (1'b0)
    );

endmodule