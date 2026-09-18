// ============================================================================
//  sd_reader.sv
//  SDカード SPIモード ブロックリーダ
//  Sipeed TangMega-138KPro-example (audio_music) の sd_init / sd_read の
//  動作実績あるロジックを参考に、1相クロック (50MHz) だけで実装した版。
//
//  【タイミング】 SPIモード0 (CPOL=0, CPHA=0)
//    MOSI 出力 : SPIクロックの立ち下がり (sp_fall) で更新
//    MISO 受信 : SPIクロックの立ち上がり (sp_rise) でサンプル
//
//  【Sipeed版との対応】
//    clk_ref の立ち上がり = sd_clk(180deg) の立ち下がり = 本実装の sp_fall
//    clk_ref_180deg の立ち上がり = sd_clk の立ち上がり = 本実装の sp_rise
// ============================================================================
module sd_reader #(
    parameter int SYS_CLK_HZ  = 50_000_000,
    parameter int INIT_SPI_HZ = 400_000,      // 初期化時 SPI クロック
    parameter int DATA_SPI_HZ = 10_000_000    // データ転送時 SPI クロック
) (
    input  logic        clk,
    input  logic        rst_n,

    // SDカード SPI インターフェース
    output logic        sd_clk,
    output logic        sd_cmd,     // MOSI
    input  logic        sd_dat,     // MISO
    output logic        sd_cs_n,

    // ブロック読み出し制御
    input  logic        read_req,
    input  logic [31:0] block_addr,

    // 読み出しデータ
    output logic [7:0]  data,
    output logic        data_valid,
    output logic        busy,
    output logic        init_done,  // 初期化完了フラグ
    output logic [2:0]  debug_stage // 初期化フェーズ
);

    // ========================================================================
    // SPI クロック生成 (フリーラン分周)
    // ========================================================================
    localparam int INIT_DIV = SYS_CLK_HZ / INIT_SPI_HZ / 2;   // 62
    localparam int DATA_DIV = SYS_CLK_HZ / DATA_SPI_HZ / 2;   // 2

    logic [15:0] div_cnt;
    logic        fast_clk;
    logic        sp_clk;
    logic        sp_clk_prev;
    wire         sp_rise;
    wire         sp_fall;

    wire [15:0] div_target = fast_clk ? DATA_DIV : INIT_DIV;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt     <= 16'd0;
            sp_clk      <= 1'b0;
            sp_clk_prev <= 1'b0;
        end else begin
            sp_clk_prev <= sp_clk;
            if (div_cnt >= div_target - 1) begin
                div_cnt <= 16'd0;
                sp_clk  <= ~sp_clk;
            end else begin
                div_cnt <= div_cnt + 16'd1;
            end
        end
    end

    assign sp_rise =  sp_clk && !sp_clk_prev;
    assign sp_fall = !sp_clk &&  sp_clk_prev;
    assign sd_clk  = sp_clk;

    // ========================================================================
    // 状態定義
    // ========================================================================
    typedef enum logic [3:0] {
        ST_IDLE,           // 上電安定待ち
        ST_SEND_CMD0,      // CMD0 送信
        ST_WAIT_CMD0,      // CMD0 応答待ち
        ST_SEND_CMD8,      // CMD8 送信
        ST_WAIT_CMD8,      // CMD8 応答待ち
        ST_SEND_CMD55,     // CMD55 送信
        ST_WAIT_CMD55,     // CMD55 応答待ち
        ST_SEND_ACMD41,    // ACMD41 送信
        ST_WAIT_ACMD41,    // ACMD41 応答待ち
        ST_INIT_DONE,      // 初期化完了
        ST_RD_IDLE,        // 読み出し待機
        ST_RD_SEND_CMD17,  // CMD17 送信
        ST_RD_WAIT_CMD17,  // CMD17 応答待ち
        ST_RD_WAIT_TOKEN,  // データトークン待ち
        ST_RD_DATA,        // データ読み出し
        ST_RD_CRC          // CRC 読捨て
    } state_t;

    state_t state;

    // コマンド定義 (48bit)
    localparam logic [47:0] CMD0   = {8'h40, 8'h00, 8'h00, 8'h00, 8'h00, 8'h95};
    localparam logic [47:0] CMD8   = {8'h48, 8'h00, 8'h00, 8'h01, 8'hAA, 8'h87};
    localparam logic [47:0] CMD55  = {8'h77, 8'h00, 8'h00, 8'h00, 8'h00, 8'hFF};
    localparam logic [47:0] ACMD41 = {8'h69, 8'h40, 8'h00, 8'h00, 8'h00, 8'hFF};

    logic [47:0] cmd_rd;   // CMD17 用 (アドレス可変)
    logic [47:0] cur_cmd;  // 現在送信中のコマンド

    always_comb begin
        case (state)
            ST_SEND_CMD0:    cur_cmd = CMD0;
            ST_SEND_CMD8:    cur_cmd = CMD8;
            ST_SEND_CMD55:   cur_cmd = CMD55;
            ST_SEND_ACMD41:  cur_cmd = ACMD41;
            ST_RD_SEND_CMD17: cur_cmd = cmd_rd;
            default:         cur_cmd = 48'hFFFFFFFFFFFF;
        endcase
    end

    // ========================================================================
    // コマンド送信: sp_fall (SPIクロック立ち下がり) で 1ビットずつ MSB から送信
    // ========================================================================
    logic        send_active;
    logic [5:0]  cmd_bit_cnt;
    logic        cmd_sent;      // 48ビット送信完了パルス
    logic        sd_mosi;

    always_comb begin
        send_active = (state == ST_SEND_CMD0)  || (state == ST_SEND_CMD8) ||
                      (state == ST_SEND_CMD55) || (state == ST_SEND_ACMD41) ||
                      (state == ST_RD_SEND_CMD17);
    end

    assign sd_cmd = sd_mosi;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cmd_bit_cnt <= 6'd0;
            sd_mosi     <= 1'b1;
            cmd_sent    <= 1'b0;
        end else begin
            cmd_sent <= 1'b0;
            if (send_active) begin
                if (sp_fall) begin
                    sd_mosi <= cur_cmd[47 - cmd_bit_cnt];
                    if (cmd_bit_cnt == 6'd47) begin
                        cmd_bit_cnt <= 6'd0;
                        cmd_sent    <= 1'b1;
                    end else begin
                        cmd_bit_cnt <= cmd_bit_cnt + 6'd1;
                    end
                end
            end else begin
                sd_mosi     <= 1'b1;
                cmd_bit_cnt <= 6'd0;
            end
        end
    end

    // ========================================================================
    // MISO 受信: sp_rise でサンプル。スタートビット(0)検出でバイト境界を合わせる
    // ========================================================================
    logic        rx_flag;
    logic [2:0]  rx_bit_cnt;
    logic [7:0]  rx_sr;
    logic [7:0]  rx_byte;
    logic        rx_byte_ready;
    logic        r1_mode;    // 1=R1応答(スタートビット検出), 0=データ(連続8bit)

    always_comb begin
        r1_mode = (state == ST_WAIT_CMD0)  || (state == ST_WAIT_CMD8) ||
                  (state == ST_WAIT_CMD55) || (state == ST_WAIT_ACMD41) ||
                  (state == ST_RD_WAIT_CMD17);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_flag       <= 1'b0;
            rx_bit_cnt    <= 3'd0;
            rx_sr         <= 8'd0;
            rx_byte       <= 8'd0;
            rx_byte_ready <= 1'b0;
        end else begin
            rx_byte_ready <= 1'b0;
            if (sp_rise) begin
                if (!rx_flag) begin
                    if (r1_mode) begin
                        // スタートビット (MISO=0) を待つ (カウントしない)
                        if (sd_dat == 1'b0) begin
                            rx_flag    <= 1'b1;
                            rx_sr      <= 8'd0;
                            rx_bit_cnt <= 3'd0;
                        end
                    end else begin
                        // データモード: 連続 8bit (スタートビットなし)
                        rx_flag    <= 1'b1;
                        rx_sr      <= {7'b0, sd_dat};
                        rx_bit_cnt <= 3'd1;
                    end
                end else begin
                    // 8データビット受信
                    rx_sr <= {rx_sr[6:0], sd_dat};
                    if (rx_bit_cnt == 3'd7) begin
                        rx_byte       <= {rx_sr[6:0], sd_dat};
                        rx_byte_ready <= 1'b1;
                        rx_flag       <= 1'b0;
                        rx_bit_cnt    <= 3'd0;
                    end else begin
                        rx_bit_cnt <= rx_bit_cnt + 3'd1;
                    end
                end
            end
        end
    end

    // ========================================================================
    // メイン状態機械 (50MHz クロックドメイン)
    // ========================================================================
    logic [7:0]  poweron_cnt;
    logic [23:0] over_time_cnt;
    logic [7:0]  acmd41_tries;
    logic [9:0]  data_cnt;
    logic [9:0]  crc_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_IDLE;
            poweron_cnt   <= 8'd0;
            over_time_cnt <= 24'd0;
            acmd41_tries  <= 8'd0;
            data_cnt      <= 10'd0;
            crc_cnt       <= 10'd0;
            sd_cs_n       <= 1'b1;
            cmd_rd        <= 48'd0;
            data          <= 8'h00;
            data_valid    <= 1'b0;
            busy          <= 1'b1;
            fast_clk      <= 1'b0;
            init_done     <= 1'b0;
        end else begin
            data_valid <= 1'b0;

            if (poweron_cnt < 8'd80)
                poweron_cnt <= poweron_cnt + 8'd1;

            case (state)
                // ---- 上電安定待ち ----
                ST_IDLE: begin
                    sd_cs_n <= 1'b1;
                    if (poweron_cnt >= 8'd80)
                        state <= ST_SEND_CMD0;
                end

                // ---- CMD0 送信 / 応答待ち ----
                ST_SEND_CMD0: begin
                    sd_cs_n <= 1'b0;
                    if (cmd_sent) begin
                        state         <= ST_WAIT_CMD0;
                        over_time_cnt <= 24'd0;
                    end
                end

                ST_WAIT_CMD0: begin
                    if (rx_byte_ready) begin
                        sd_cs_n <= 1'b1;
                        if (rx_byte == 8'h01)
                            state <= ST_SEND_CMD8;
                        else
                            state <= ST_SEND_CMD0;
                    end else if (over_time_cnt >= 24'd5_000_000) begin
                        state <= ST_SEND_CMD0;
                    end else
                        over_time_cnt <= over_time_cnt + 24'd1;
                end

                // ---- CMD8 送信 / 応答待ち ----
                ST_SEND_CMD8: begin
                    sd_cs_n <= 1'b0;
                    if (cmd_sent) begin
                        state         <= ST_WAIT_CMD8;
                        over_time_cnt <= 24'd0;
                    end
                end

                ST_WAIT_CMD8: begin
                    if (rx_byte_ready) begin
                        sd_cs_n <= 1'b1;
                        state    <= ST_SEND_CMD55;
                    end else if (over_time_cnt >= 24'd5_000_000) begin
                        state <= ST_SEND_CMD8;
                    end else
                        over_time_cnt <= over_time_cnt + 24'd1;
                end

                // ---- CMD55 送信 / 応答待ち ----
                ST_SEND_CMD55: begin
                    sd_cs_n <= 1'b0;
                    if (cmd_sent) begin
                        state         <= ST_WAIT_CMD55;
                        over_time_cnt <= 24'd0;
                    end
                end

                ST_WAIT_CMD55: begin
                    if (rx_byte_ready) begin
                        sd_cs_n <= 1'b1;
                        state    <= ST_SEND_ACMD41;
                    end else if (over_time_cnt >= 24'd5_000_000) begin
                        state <= ST_SEND_CMD55;
                    end else
                        over_time_cnt <= over_time_cnt + 24'd1;
                end

                // ---- ACMD41 送信 / 応答待ち ----
                ST_SEND_ACMD41: begin
                    sd_cs_n <= 1'b0;
                    if (cmd_sent) begin
                        state         <= ST_WAIT_ACMD41;
                        over_time_cnt <= 24'd0;
                    end
                end

                ST_WAIT_ACMD41: begin
                    if (rx_byte_ready) begin
                        sd_cs_n <= 1'b1;
                        if (rx_byte == 8'h00) begin
                            state <= ST_INIT_DONE;
                        end else begin
                            if (acmd41_tries >= 8'd255) begin
                                state <= ST_INIT_DONE;
                            end else begin
                                acmd41_tries <= acmd41_tries + 8'd1;
                                state        <= ST_SEND_CMD55;
                            end
                        end
                    end else if (over_time_cnt >= 24'd5_000_000) begin
                        state <= ST_SEND_CMD55;
                    end else
                        over_time_cnt <= over_time_cnt + 24'd1;
                end

                // ---- 初期化完了 → 読み出し待機 ----
                ST_INIT_DONE: begin
                    fast_clk  <= 1'b1;
                    busy      <= 1'b0;
                    init_done <= 1'b1;
                    sd_cs_n   <= 1'b1;
                    state     <= ST_RD_IDLE;
                end

                ST_RD_IDLE: begin
                    sd_cs_n <= 1'b1;
                    if (read_req) begin
                        cmd_rd <= {8'h51, block_addr, 8'hFF};
                        busy   <= 1'b1;
                        state  <= ST_RD_SEND_CMD17;
                    end
                end

                // ---- CMD17 送信 / 応答待ち ----
                ST_RD_SEND_CMD17: begin
                    sd_cs_n <= 1'b0;
                    if (cmd_sent) begin
                        state         <= ST_RD_WAIT_CMD17;
                        over_time_cnt <= 24'd0;
                    end
                end

                ST_RD_WAIT_CMD17: begin
                    if (rx_byte_ready) begin
                        sd_cs_n <= 1'b1;
                        if (rx_byte == 8'h00) begin
                            state         <= ST_RD_WAIT_TOKEN;
                            over_time_cnt <= 24'd0;
                        end else begin
                            state <= ST_RD_IDLE;
                            busy  <= 1'b0;
                        end
                    end else if (over_time_cnt >= 24'd5_000_000) begin
                        state <= ST_RD_IDLE;
                        busy  <= 1'b0;
                    end else
                        over_time_cnt <= over_time_cnt + 24'd1;
                end

                // ---- データトークン 0xFE 待ち ----
                ST_RD_WAIT_TOKEN: begin
                    if (rx_byte_ready) begin
                        if (rx_byte == 8'hFE) begin
                            data_cnt <= 10'd0;
                            state    <= ST_RD_DATA;
                        end
                    end else if (over_time_cnt >= 24'd5_000_000) begin
                        state <= ST_RD_IDLE;
                        busy  <= 1'b0;
                    end else
                        over_time_cnt <= over_time_cnt + 24'd1;
                end

                // ---- データ読み出し (512バイト) ----
                ST_RD_DATA: begin
                    if (rx_byte_ready) begin
                        data       <= rx_byte;
                        data_valid <= 1'b1;
                        if (data_cnt == 10'd511) begin
                            data_cnt <= 10'd0;
                            crc_cnt  <= 10'd0;
                            state    <= ST_RD_CRC;
                        end else
                            data_cnt <= data_cnt + 10'd1;
                    end
                end

                // ---- CRC 2バイト読捨て ----
                ST_RD_CRC: begin
                    if (rx_byte_ready) begin
                        if (crc_cnt == 10'd1) begin
                            sd_cs_n <= 1'b1;
                            busy    <= 1'b0;
                            state   <= ST_RD_IDLE;
                        end else
                            crc_cnt <= crc_cnt + 10'd1;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

    // ========================================================================
    // デバッグフェーズ出力
    // ========================================================================
    always_comb begin
        case (state)
            ST_IDLE:                              debug_stage = 3'd0;
            ST_SEND_CMD0, ST_WAIT_CMD0:           debug_stage = 3'd1;
            ST_SEND_CMD8, ST_WAIT_CMD8:           debug_stage = 3'd2;
            ST_SEND_CMD55, ST_WAIT_CMD55,
            ST_SEND_ACMD41, ST_WAIT_ACMD41:       debug_stage = 3'd3;
            default:                              debug_stage = 3'd4;
        endcase
    end

endmodule
