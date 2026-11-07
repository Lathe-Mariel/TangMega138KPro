module top (
    input  wire        clk,
    input  wire        rst_n,
    // SD
    output wire        sd_clk,
    output wire        sd_cmd,
    input  wire        sd_dat,
    output wire        sd_cs_n,
    output wire        sd_dat1,
    output wire        sd_dat2,
    // DDR3
    output wire [15:0] ddr_addr,
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
    // DVI TX
    output wire        hdmi_tx_clk_p,
    output wire        hdmi_tx_clk_n,
    output wire [2:0]  hdmi_tx_p,
    output wire [2:0]  hdmi_tx_n,
    output wire [5:0]  state_led
);

    assign sd_dat1 = 1'b1;
    assign sd_dat2 = 1'b1;

    // clocks
    wire clk_5x, clk_pixel, pll_video_lock;
    Gowin_PLL_DVI u_pll_dvi (.clkin(clk), .clkout0(clk_5x), .lock(pll_video_lock), .reset(~rst_n));
    Gowin_CLKDIV u_clkdiv (.clkout(clk_pixel), .hclkin(clk_5x), .resetn(rst_n));

    wire memory_clk, clk_100, memory_pll_lock;
    Gowin_PLL u_pll_mem (.lock(memory_pll_lock), .clkout0(memory_clk), .clkout1(clk_100), .clkin(clk), .reset(~rst_n));

    wire sys_rst_n = rst_n & pll_video_lock & memory_pll_lock;

    // vga timing
    reg [11:0] x, y;
    always @(posedge clk_pixel or negedge sys_rst_n) begin
        if (!sys_rst_n) begin x<=0; y<=0; end
        else begin
            if (x==1649) begin x<=0; if (y==749) y<=0; else y<=y+1; end
            else x<=x+1;
        end
    end
    wire de = (x<1280)&&(y<720);
    wire hs = (x>=1390)&&(x<1430);
    wire vs = (y>=725)&&(y<730);
    wire vs_n = ~vs;

    // SD read
    reg [31:0] block_cnt = 0, block_addr = 0;
    reg read_req, sd_done, rd_pending;
    wire sd_busy, sd_init_done;
    wire [2:0] sd_debug_stage;
    wire [7:0] sd_byte;
    wire sd_byte_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            block_cnt <= 0; block_addr <= 0; read_req <= 0; sd_done <= 0; rd_pending <= 0;
        end else begin
            read_req <= 0;
            if (!sd_done && !frame_done_w) begin
                if (!rd_pending && !sd_busy && block_cnt < 6000) begin
                    read_req <= 1;
                    block_addr <= block_cnt;
                    block_cnt <= block_cnt + 1;
                    rd_pending <= 1;
                end else if (rd_pending && sd_busy) begin
                    rd_pending <= 0;
                end
            end else if (frame_done_w) begin
                sd_done <= 1;
            end
        end
    end

    sd_reader u_sd (
        .clk(clk), .rst_n(rst_n),
        .sd_clk(sd_clk), .sd_cmd(sd_cmd), .sd_dat(sd_dat), .sd_cs_n(sd_cs_n),
        .read_req(read_req), .block_addr(block_addr),
        .data(sd_byte), .data_valid(sd_byte_valid), .busy(sd_busy),
        .init_done(sd_init_done), .debug_stage(sd_debug_stage)
    );

    // BMP parser
    wire [7:0] bmp_r, bmp_g, bmp_b;
    wire bmp_valid, bmp_ready;
    bmp_parser u_bmp (
        .clk(clk), .rst_n(rst_n),
        .in_data(sd_byte), .in_valid(sd_byte_valid),
        .px_r(bmp_r), .px_g(bmp_g), .px_b(bmp_b), .px_valid(bmp_valid),
        .img_ready(bmp_ready)
    );

    // frame writer
    wire vin_vs_n, vin_de;
    wire [23:0] vin_data;
    wire fw_wr_halt;
    wire frame_done_w;
    frame_writer u_fw (
        .clk(clk), .rst_n(rst_n),
        .px_r(bmp_r), .px_g(bmp_g), .px_b(bmp_b), .px_valid(bmp_valid),
        .vin_vs_n(vin_vs_n), .vin_de(vin_de), .vin_data(vin_data),
        .wr_halt(fw_wr_halt), .frame_done(frame_done_w)
    );

    // VFB
    wire init_calib_complete;
    wire cmd_ready;
    wire [2:0] cmd;
    wire cmd_en;
    wire [28:0] addr;
    wire wr_data_rdy;
    wire [255:0] wr_data;
    wire wr_data_en, wr_data_end;
    wire [31:0] wr_data_mask;
    wire [255:0] rd_data;
    wire rd_data_valid, rd_data_end;
    wire vout_den, vout_fifo_empty;
    wire [23:0] vout_data;
    wire O_vin0_fifo_full;

    Video_Frame_Buffer_Top vfb (
        .I_rst_n(sys_rst_n),
        .I_dma_clk(clk_100),
        .I_wr_halt(1'b0),
        .I_rd_halt(1'b0),
        .I_vin0_clk(clk),
        .I_vin0_vs_n(vin_vs_n),
        .I_vin0_de(vin_de),
        .I_vin0_data(vin_data),
        .O_vin0_fifo_full(O_vin0_fifo_full),
        .I_vout0_clk(clk_pixel),
        .I_vout0_vs_n(vs_n),
        .I_vout0_de(de),
        .O_vout0_den(vout_den),
        .O_vout0_data(vout_data),
        .O_vout0_fifo_empty(vout_fifo_empty),
        .I_cmd_ready(cmd_ready),
        .O_cmd(cmd),
        .O_cmd_en(cmd_en),
        .O_addr(addr),
        .I_wr_data_rdy(wr_data_rdy),
        .O_wr_data_en(wr_data_en),
        .O_wr_data_end(wr_data_end),
        .O_wr_data(wr_data),
        .O_wr_data_mask(wr_data_mask),
        .I_rd_data_valid(rd_data_valid),
        .I_rd_data_end(rd_data_end),
        .I_rd_data(rd_data),
        .I_init_calib_complete(init_calib_complete)
    );

    // DDR3
    DDR3_Memory_Interface_Top u_ddr3 (
        .clk(clk_100),
        .pll_stop(),
        .memory_clk(memory_clk),
        .pll_lock(memory_pll_lock),
        .rst_n(sys_rst_n),
        .clk_out(),
        .ddr_rst(),
        .init_calib_complete(init_calib_complete),
        .cmd_ready(cmd_ready),
        .cmd(cmd),
        .cmd_en(cmd_en),
        .addr(addr),
        .wr_data_rdy(wr_data_rdy),
        .wr_data(wr_data),
        .wr_data_en(wr_data_en),
        .wr_data_end(wr_data_end),
        .wr_data_mask(wr_data_mask),
        .rd_data(rd_data),
        .rd_data_valid(rd_data_valid),
        .rd_data_end(rd_data_end),
        .sr_req(1'b0),
        .ref_req(1'b0),
        .sr_ack(),
        .ref_ack(),
        .burst(1'b1),
        .O_ddr_addr(ddr_addr),
        .O_ddr_ba(ddr_bank),
        .O_ddr_cs_n(ddr_cs_n),
        .O_ddr_ras_n(ddr_ras_n),
        .O_ddr_cas_n(ddr_cas_n),
        .O_ddr_we_n(ddr_we_n),
        .O_ddr_clk(ddr_ck),
        .O_ddr_clk_n(ddr_ck_n),
        .O_ddr_cke(ddr_cke),
        .O_ddr_odt(ddr_odt),
        .O_ddr_reset_n(ddr_reset_n),
        .O_ddr_dqm(ddr_dm),
        .IO_ddr_dq(ddr_dq),
        .IO_ddr_dqs(ddr_dqs),
        .IO_ddr_dqs_n(ddr_dqs_n)
    );

    // DVI TX
    wire [7:0] fb_r, fb_g, fb_b;
    assign {fb_r, fb_g, fb_b} = vout_data;

    DVI_TX_Top u_dvi (
        .I_rst_n(sys_rst_n),
        .I_serial_clk(clk_5x),
        .I_rgb_clk(clk_pixel),
        .I_rgb_vs(vs),
        .I_rgb_hs(hs),
        .I_rgb_de(vout_den),
        .I_rgb_r(fb_r),
        .I_rgb_g(fb_g),
        .I_rgb_b(fb_b),
        .O_tmds_clk_p(hdmi_tx_clk_p),
        .O_tmds_clk_n(hdmi_tx_clk_n),
        .O_tmds_data_p(hdmi_tx_p),
        .O_tmds_data_n(hdmi_tx_n)
    );

    assign state_led = {sd_init_done, frame_done_w, init_calib_complete, sys_rst_n, 2'b0};
endmodule