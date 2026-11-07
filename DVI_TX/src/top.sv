module top (
    input  wire clk,
    input  wire rst_n,
    output wire hdmi_tx_clk_p,
    output wire hdmi_tx_clk_n,
    output wire [2:0] hdmi_tx_p,
    output wire [2:0] hdmi_tx_n
);
    wire clk_5x, clk_pixel, pll_lock;
    Gowin_PLL_DVI u_pll (
        .clkin   (clk),
        .clkout0 (clk_5x),
        .lock    (pll_lock),
        .reset   (~rst_n)
    );
    Gowin_CLKDIV u_clkdiv (
        .clkout (clk_pixel),
        .hclkin (clk_5x),
        .resetn (rst_n)
    );

    reg [11:0] x;
    reg [11:0] y;
    always @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin x<=0; y<=0; end
        else begin
            if (x==1649) begin x<=0; if (y==749) y<=0; else y<=y+1; end
            else x<=x+1;
        end
    end
    wire de = (x<1280)&&(y<720);
    wire hs = (x>=1390)&&(x<1430);
    wire vs = (y>=725)&&(y<730);
    wire [7:0] r = de ? x[7:0] : 8'd0;
    wire [7:0] g = de ? y[7:0] : 8'd0;
    wire [7:0] b = de ? (x[7:0]^y[7:0]) : 8'd0;

    DVI_TX_Top u_dvi (
        .I_rst_n     (rst_n & pll_lock),
        .I_serial_clk(clk_5x),
        .I_rgb_clk   (clk_pixel),
        .I_rgb_vs    (vs),
        .I_rgb_hs    (hs),
        .I_rgb_de    (de),
        .I_rgb_r     (r),
        .I_rgb_g     (g),
        .I_rgb_b     (b),
        .O_tmds_clk_p(hdmi_tx_clk_p),
        .O_tmds_clk_n(hdmi_tx_clk_n),
        .O_tmds_data_p(hdmi_tx_p),
        .O_tmds_data_n(hdmi_tx_n)
    );
endmodule