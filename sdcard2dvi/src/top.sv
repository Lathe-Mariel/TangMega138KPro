// ============================================================================
//  top.sv
//  SDカード → DDR3フレームバッファ → DVI(HDMI) 出力 トップモジュール
//  Board: Tang Mega 138K Pro Dock (GW5AST-LV138FPG676A)
//
//  構成 (HDMI2HDMI の dvi_frame_buffer_top.v をベースに、入力側を SD に置換):
//
//   SDカード → sd_reader → bmp_parser → frame_writer ─┐
//                                                       │(書込ポート)
//                                                       ▼
//                                      Video_Frame_Buffer ── DDR3
//                                                       ▲
//                                                       │(読出ポート)
//   vga_timing(1280x720@60) ────────────────────────────┘
//        │
//        └→ DVI_TX (HDMI出力)
//
//   書き込み: 電源投入後、SDからBMPを連続ブロック読出ししてフレームバッファへ
//             1フレーム分書込む (静止画)。
//   表示: 以後、1280x720@60Hz で繰り返し表示。
// ============================================================================
module top (
    //-----------------------------------------------------------------------
    // システムクロック & リセット
    //-----------------------------------------------------------------------
    input  wire        clk,           // 50 MHz (P16)
    input  wire        rst_n,         // アクティブLow (K16)

    //-----------------------------------------------------------------------
    // SDカード SPI インターフェース (ピン割当は .cst で指定)
    //-----------------------------------------------------------------------
    output wire        sd_clk,
    output wire        sd_cmd,        // MOSI
    input  wire        sd_dat,        // MISO
    output wire        sd_cs_n,
    output wire        sd_dat1,       // DAT1 (SPIでは未使用、High固定)
    output wire        sd_dat2,       // DAT2 (SPIでは未使用、High固定)

    //-----------------------------------------------------------------------
    // HDMI TX (DVI 出力)
    //-----------------------------------------------------------------------
    output wire        tmds_tx_clk_p,
    output wire        tmds_tx_clk_n,
    output wire [2:0]  tmds_tx_data_p,
    output wire [2:0]  tmds_tx_data_n,

    //-----------------------------------------------------------------------
    // DDR3 SDRAM
    //-----------------------------------------------------------------------
    output wire [15:0] ddr_addr,
    output wire [2:0]  ddr_bank,
    output wire        ddr_cs,
    output wire        ddr_ras,
    output wire        ddr_cas,
    output wire        ddr_we,
    output wire        ddr_odt,
    output wire        ddr_cke,
    output wire        ddr_reset_n,
    output wire        ddr_ck,
    output wire        ddr_ck_n,
    inout  wire [31:0] ddr_dq,
    inout  wire [3:0]  ddr_dqs,
    inout  wire [3:0]  ddr_dqs_n,
    output wire [3:0]  ddr_dm,

    output logic[5:0] state_led,
    input wire sw0,
    input wire sw1,
    output wire fan,
    output wire led_color,
    input wire DET_A
);

assign fan = 0;
assign led_color = 0;

// SDカード SPIモードでは DAT1/DAT2 は未使用のため High に固定する
assign sd_dat1 = 1'b1;
assign sd_dat2 = 1'b1;

// ============================================================================
// クロック & リセット
// ============================================================================

    wire clk_pixel;     // 74.25 MHz - ピクセルクロック
    wire clk_5x;        // 371.25 MHz - TMDSシリアルクロック
    wire clk_100;       // 100 MHz - DDR3 リファレンス
    wire pll_video_lock;
    wire memory_pll_lock;

    wire sys_rst_n = rst_n & pll_video_lock & memory_pll_lock;

    // リセット同期化 (clk_pixel ドメイン)
    // 非同期リセット rst_n を 2段同期し、PLL ロックを反映する。
    // ※ D入力は定数1をシフトする（コンビ信号を D に入れない）ことで
    //   非同期リセット由来の HOLD 違反を防ぐ。
    reg  [1:0] rst_pixel_sync;
    always_ff @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n)      rst_pixel_sync <= 2'b00;
        else             rst_pixel_sync <= {rst_pixel_sync[0], 1'b1};
    end
    wire rst_pixel_n = rst_pixel_sync[1] & pll_video_lock;

    // ---- ビデオ PLL: 50MHz → 371.25MHz (clk_5x) ---------------------------
    Gowin_PLL_DVI pll_dvi(
        .clkin   (clk),
        .clkout0 (clk_5x),
        .lock    (pll_video_lock),
        .reset   (~rst_n)
    );

    // ---- CLKDIV: 371.25MHz → 74.25MHz (clk_pixel) -------------------------
    Gowin_CLKDIV clkdiv_dvi(
        .clkout (clk_pixel),
        .hclkin (clk_5x),
        .resetn (rst_n)
    );

    // ---- メモリ PLL: 50MHz → memory_clk + 100MHz (clk_100) ---------------
    wire memory_clk;

    Gowin_PLL pll_memory(
        .lock    (memory_pll_lock),
        .clkout0 (memory_clk),
        .clkout1 (clk_100),
        .clkin   (clk),
        .reset   (~rst_n)
    );

// ============================================================================
// SDカード読み出し (連続ブロック)
// ============================================================================

    // 読出す最大ブロック数 (1280x720x3B = 2.7MB / 512B ≈ 5400)
    localparam int MAX_BLOCKS = 6000;

    wire        sd_busy;
    wire        sd_init_done;
    wire [2:0]  sd_debug_stage;
    wire [7:0]  sd_byte;
    wire        sd_byte_valid;

    reg  [31:0] block_cnt;
    reg         read_req;
    reg         sd_done;      // 画像読出し完了 (frame_done ラッチ)

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            block_cnt <= 32'd0;
            read_req  <= 1'b0;
            sd_done   <= 1'b0;
        end else begin
            read_req <= 1'b0;   // デフォルト: パルスは1クロック

            if (!sd_done && !frame_done) begin
                if (!sd_busy && block_cnt < MAX_BLOCKS) begin
                    // 次のブロックを読む
                    read_req  <= 1'b1;
                    block_cnt <= block_cnt + 32'd1;
                end
            end else if (frame_done) begin
                sd_done <= 1'b1;   // 画像読出し完了
            end
        end
    end

    sd_reader u_sd_reader (
        .clk        (clk),
        .rst_n      (rst_n),
        .sd_clk     (sd_clk),
        .sd_cmd     (sd_cmd),
        .sd_dat     (sd_dat),
        .sd_cs_n    (sd_cs_n),
        .read_req   (read_req),
        .block_addr (block_cnt),
        .data       (sd_byte),
        .data_valid (sd_byte_valid),
        .busy       (sd_busy),
        .init_done  (sd_init_done),
        .debug_stage(sd_debug_stage)
    );

// ============================================================================
// BMP パース
// ============================================================================

    wire [7:0]  bmp_px_r, bmp_px_g, bmp_px_b;
    wire        bmp_px_valid;
    wire        bmp_img_ready;

    bmp_parser u_bmp_parser (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_data   (sd_byte),
        .in_valid  (sd_byte_valid),
        .px_x      (),
        .px_y      (),
        .px_r      (bmp_px_r),
        .px_g      (bmp_px_g),
        .px_b      (bmp_px_b),
        .px_valid  (bmp_px_valid),
        .img_ready (bmp_img_ready),
        .width     (),
        .height    ()
    );

// ============================================================================
// フレーム書込 (VFB 書込ポートへ変換)
// ============================================================================

    wire        vin_vs_n;
    wire        vin_de;
    wire [23:0] vin_data;
    wire        frame_done;

    frame_writer u_frame_writer (
        .clk        (clk),
        .rst_n      (rst_n),
        .px_r       (bmp_px_r),
        .px_g       (bmp_px_g),
        .px_b       (bmp_px_b),
        .px_valid   (bmp_px_valid),
        .vin_vs_n   (vin_vs_n),
        .vin_de     (vin_de),
        .vin_data   (vin_data),
        .wr_halt    (),
        .frame_done (frame_done)
    );

    // 書込停止: frame_done 後は VFB 書込を止める
    wire wr_halt;
    assign wr_halt = sd_done;

// ============================================================================
// DDR3 メモリインターフェース & フレームバッファ
// ============================================================================

    wire        dma_clk;
    wire        init_calib_complete;
    wire        cmd_ready;
    wire [2:0]  cmd;
    wire        cmd_en;
    wire [28:0] addr;
    wire        wr_data_rdy;
    wire [255:0] wr_data;
    wire        wr_data_en;
    wire        wr_data_end;
    wire [31:0] wr_data_mask;
    wire [255:0] rd_data;
    wire        rd_data_valid;
    wire        rd_data_end;

    Video_Frame_Buffer_Top vfb_instance (
        .I_rst_n              (init_calib_complete),
        .I_dma_clk            (dma_clk),

        .I_wr_halt            (wr_halt),
        .I_rd_halt            (1'd0),

        // 書込ポート (SD → BMP → frame_writer)
        .I_vin0_clk           (clk),
        .I_vin0_vs_n          (vin_vs_n),
        .I_vin0_de            (vin_de),
        .I_vin0_data          (vin_data),
        .O_vin0_fifo_full     (),

        // 読出ポート (vga_timing → DVI)
        .I_vout0_clk          (clk_pixel),
        .I_vout0_vs_n         (out_vsync),
        .I_vout0_de           (out_de),
        .O_vout0_den          (vout_den),
        .O_vout0_data         (vout_data),
        .O_vout0_fifo_empty   (),

        // DDR3 コントローラ接続
        .I_cmd_ready          (cmd_ready),
        .O_cmd                (cmd),
        .O_cmd_en             (cmd_en),
        .O_addr               (addr),
        .I_wr_data_rdy        (wr_data_rdy),
        .O_wr_data_en         (wr_data_en),
        .O_wr_data_end        (wr_data_end),
        .O_wr_data            (wr_data),
        .O_wr_data_mask       (wr_data_mask),
        .I_rd_data_valid      (rd_data_valid),
        .I_rd_data_end        (rd_data_end),
        .I_rd_data            (rd_data),
        .I_init_calib_complete(init_calib_complete)
    );

    DDR3_Memory_Interface_Top u_ddr3 (
        .clk                 (clk),
        .pll_stop            (),
        .memory_clk          (memory_clk),
        .pll_lock            (memory_pll_lock),
        .rst_n               (rst_n),
        .clk_out             (dma_clk),
        .ddr_rst             (),

        .init_calib_complete (init_calib_complete),
        .cmd_ready           (cmd_ready),
        .cmd                 (cmd),
        .cmd_en              (cmd_en),
        .addr                (addr),
        .wr_data_rdy         (wr_data_rdy),
        .wr_data             (wr_data),
        .wr_data_en          (wr_data_en),
        .wr_data_end         (wr_data_end),
        .wr_data_mask        (wr_data_mask),
        .rd_data             (rd_data),
        .rd_data_valid       (rd_data_valid),
        .rd_data_end         (rd_data_end),
        .sr_req              (1'b0),
        .ref_req             (1'b0),
        .sr_ack              (),
        .ref_ack             (),
        .burst               (1'b1),

        .O_ddr_addr          (ddr_addr),
        .O_ddr_ba            (ddr_bank),
        .O_ddr_cs_n          (ddr_cs),
        .O_ddr_ras_n         (ddr_ras),
        .O_ddr_cas_n         (ddr_cas),
        .O_ddr_we_n          (ddr_we),
        .O_ddr_clk           (ddr_ck),
        .O_ddr_clk_n         (ddr_ck_n),
        .O_ddr_cke           (ddr_cke),
        .O_ddr_odt           (ddr_odt),
        .O_ddr_reset_n       (ddr_reset_n),
        .O_ddr_dqm           (ddr_dm),
        .IO_ddr_dq           (ddr_dq),
        .IO_ddr_dqs          (ddr_dqs),
        .IO_ddr_dqs_n        (ddr_dqs_n)
    );

// ============================================================================
// 出力タイミング生成 (1280x720@60Hz) & フレームバッファ読出
// ============================================================================

    wire        out_hsync;
    wire        out_vsync;
    wire        out_de;

    wire        vout_den;
    wire [23:0] vout_data;

    vga_timing u_vga_timing (
        .clk    (clk_pixel),
        .rst    (~rst_pixel_n),
        .hsync  (out_hsync),
        .vsync  (out_vsync),
        .de     (out_de),
        .hcount (),
        .vcount ()
    );

// ============================================================================
// DVI TX (HDMI出力)
// ============================================================================

    wire [7:0] out_r, out_g, out_b;
    assign {out_r, out_g, out_b} = vout_den ? vout_data : 24'h000000;

    DVI_TX_Top u_dvi_tx (
        .I_rst_n       (rst_pixel_n),
        .I_serial_clk  (clk_5x),
        .I_rgb_clk     (clk_pixel),
        .I_rgb_vs      (out_vsync),
        .I_rgb_hs      (out_hsync),
        .I_rgb_de      (out_de),
        .I_rgb_r       (out_r),
        .I_rgb_g       (out_g),
        .I_rgb_b       (out_b),
        .O_tmds_clk_p  (tmds_tx_clk_p),
        .O_tmds_clk_n  (tmds_tx_clk_n),
        .O_tmds_data_p (tmds_tx_data_p),
        .O_tmds_data_n (tmds_tx_data_n)
    );

// ============================================================================
// デバッグ LED (state_led[5:0]) — 各段階の状態を表示
//   [5] vout_den 活動 (フレームバッファ読み出しデータ有効)
//   [4] frame_done (フレーム書き込み完了)
//   [3] sd_done    (SD画像読み出し完了)
//   [2] init_calib_complete (DDR3 初期化完了)
//   [1] memory_pll_lock (メモリPLLロック)
//   [0] pll_video_lock  (ビデオPLLロック)
//   点灯 = 正常にその段階まで到達
// ============================================================================

    // vout_den は clk_pixel ドメインの高速トグル信号なので、
    // 点灯確認用に clk ドメインへ粗く同期してレベルを出す
    reg  [23:0] den_watchdog;
    reg         den_active;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            den_watchdog <= 24'd0;
            den_active   <= 1'b0;
        end else begin
            if (vout_den) begin
                den_watchdog <= 24'd0;
                den_active   <= 1'b1;
            end else if (den_watchdog >= 24'd1_000_000) begin
                den_watchdog <= den_watchdog;
                den_active   <= 1'b0;
            end else begin
                den_watchdog <= den_watchdog + 24'd1;
            end
        end
    end

    // LED 割当:
    //   [5] den_active            (読出し活動中)
    //   [4:2] SD初期化フェーズ debug_stage[2:0]
    //         0=電源/ダミー  1=CMD0  2=CMD8  3=ACMD41ループ  4=完了
    //   [1] init_calib_complete  (DDR3 初期化)
    //   [0] memory_pll_lock
    //   ※ 負論理: 点灯=Low(0), 消灯=High(1)
    assign state_led[5] = den_active;
    assign state_led[4] = sd_debug_stage[2];
    assign state_led[3] = sd_debug_stage[1];
    assign state_led[2] = sd_debug_stage[0];
    assign state_led[1] = init_calib_complete;
    assign state_led[0] = memory_pll_lock;

endmodule
