// Gowin DDR3 IP bring-up: init_calib_complete を LED で表示
module top (
    input  wire        clk,
    input  wire        rst_n,
    output wire [14:0] ddr_addr,
    output wire [2:0]  ddr_bank,
    output wire        ddr_cs_n,
    output wire        ddr_ras_n,
    output wire        ddr_cas_n,
    output wire        ddr_we_n,
    output wire        ddr_ck,
    output wire        ddr_ck_n,
    output wire        ddr_cke,
    output wire        ddr_odt,
    output wire        ddr_reset_n,
    output wire [3:0]  ddr_dm,
    inout  wire [31:0] ddr_dq,
    inout  wire [3:0]  ddr_dqs,
    inout  wire [3:0]  ddr_dqs_n,
    output wire [5:0]  state_led
);
    wire memory_clk, clk_100, memory_pll_lock;
    Gowin_PLL u_pll (
        .lock    (memory_pll_lock),
        .clkout0 (memory_clk),
        .clkout1 (clk_100),
        .clkin   (clk),
        .reset   (~rst_n)
    );
    wire sys_rst_n = rst_n & memory_pll_lock;

    wire cmd_ready, wr_data_rdy;
    wire [255:0] rd_data;
    wire rd_data_valid, rd_data_end;
    wire sr_ack, ref_ack;
    wire [2:0] cmd = 3'b000;
    wire cmd_en   = 1'b0;
    wire [28:0] addr = 29'b0;
    wire [255:0] wr_data = 256'b0;
    wire wr_data_en = 1'b0;
    wire wr_data_end = 1'b0;
    wire [31:0] wr_data_mask = 32'b0;
    wire sr_req = 1'b0;
    wire ref_req = 1'b0;
    wire burst = 1'b0;

    wire pll_stop, clk_out, ddr_rst, init_calib_complete;
    DDR3_Memory_Interface_Top u_ddr3 (
        .clk                (clk_100),
        .pll_stop           (pll_stop),
        .memory_clk         (memory_clk),
        .pll_lock           (memory_pll_lock),
        .rst_n              (sys_rst_n),
        .clk_out            (clk_out),
        .ddr_rst            (ddr_rst),
        .init_calib_complete(init_calib_complete),
        .cmd_ready          (cmd_ready),
        .cmd                (cmd),
        .cmd_en             (cmd_en),
        .addr               (addr),
        .wr_data_rdy        (wr_data_rdy),
        .wr_data            (wr_data),
        .wr_data_en         (wr_data_en),
        .wr_data_end        (wr_data_end),
        .wr_data_mask       (wr_data_mask),
        .rd_data            (rd_data),
        .rd_data_valid      (rd_data_valid),
        .rd_data_end        (rd_data_end),
        .sr_req             (sr_req),
        .ref_req            (ref_req),
        .sr_ack             (sr_ack),
        .ref_ack            (ref_ack),
        .burst              (burst),
        .O_ddr_addr         (ddr_addr),
        .O_ddr_ba           (ddr_bank),
        .O_ddr_cs_n         (ddr_cs_n),
        .O_ddr_ras_n        (ddr_ras_n),
        .O_ddr_cas_n        (ddr_cas_n),
        .O_ddr_we_n         (ddr_we_n),
        .O_ddr_clk          (ddr_ck),
        .O_ddr_clk_n        (ddr_ck_n),
        .O_ddr_cke          (ddr_cke),
        .O_ddr_odt          (ddr_odt),
        .O_ddr_reset_n      (ddr_reset_n),
        .O_ddr_dqm          (ddr_dm),
        .IO_ddr_dq          (ddr_dq),
        .IO_ddr_dqs         (ddr_dqs),
        .IO_ddr_dqs_n       (ddr_dqs_n)
    );
    assign state_led = {5'b0, init_calib_complete};
endmodule