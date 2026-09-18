// ============================================================================
//  sd_reader.sv
//  SDカード SPIモード ブロックリーダ
//  Sipeed TangMega-138KPro-example (audio_music) の sd_init / sd_read の
//  ロジックを忠実に移植した版。
//
//  【クロック】 Sipeed版と同様、2相クロック方式
//    clk_ref       = clk (50MHz)          : MOSI を posedge で出力
//    clk_ref_180deg= !clk                  : sd_clk に接続
//    MISO は clk_ref_180deg の posedge (= sd_clk の立ち上がり) でラッチ
//
//  ※ SPIモード0 : sd_clk 立ち下がり(=clk_ref posedge)で MOSI 確定,
//                  sd_clk 立ち上がりで MISO サンプル
// ============================================================================
module sd_reader (
    input  logic        clk,          // 50MHz
    input  logic        rst_n,

    output logic        sd_clk,
    output logic        sd_cmd,       // MOSI
    input  logic        sd_dat,       // MISO
    output logic        sd_cs_n,

    input  logic        read_req,
    input  logic [31:0] block_addr,

    output logic [7:0]  data,
    output logic        data_valid,
    output logic        busy,
    output logic        init_done,
    output logic [2:0]  debug_stage
);

    // ---- 2相クロック ----
    wire clk_ref       = clk;
    wire clk_ref_180   = ~clk;
    assign sd_clk      = clk_ref_180;

    // ========================================================================
    // コマンド定義 (48bit)
    // ========================================================================
    localparam logic [47:0] CMD0   = {8'h40, 8'h00, 8'h00, 8'h00, 8'h00, 8'h95};
    localparam logic [47:0] CMD8   = {8'h48, 8'h00, 8'h00, 8'h01, 8'hAA, 8'h87};
    localparam logic [47:0] CMD55  = {8'h77, 8'h00, 8'h00, 8'h00, 8'h00, 8'hFF};
    localparam logic [47:0] ACMD41 = {8'h69, 8'h40, 8'h00, 8'h00, 8'h00, 8'hFF};

    // ========================================================================
    // 状態定義 (初期化 + 読み出しを統合)
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
        ST_RD_SEND,        // CMD17 送信
        ST_RD_WAIT_R1,     // CMD17 R1 応答待ち
        ST_RD_WAIT_TOKEN,  // データトークン待ち
        ST_RD_DATA,        // データ読み出し
        ST_RD_CRC          // CRC 読捨て
    } state_t;

    state_t state, next_state;

    // ========================================================================
    // 上電安定カウンタ
    // ========================================================================
    localparam POWER_ON_NUM = 74;
    logic [7:0] poweron_cnt;

    always_ff @(posedge clk_ref or negedge rst_n) begin
        if (!rst_n)
            poweron_cnt <= 8'd0;
        else if (poweron_cnt < POWER_ON_NUM + 3'd6)
            poweron_cnt <= poweron_cnt + 1'b1;
    end

    // ========================================================================
    // コマンド送信 (clk_ref の posedge = sd_clk の negedge で出力)
    // ========================================================================
    logic [5:0]  cmd_bit_cnt;
    logic        send_active;
    logic        cmd_sent;      // 48bit 送信完了パルス
    logic [47:0] cur_cmd;
    logic        sd_mosi;

    assign sd_cmd = sd_mosi;

    always_comb begin
        send_active = (state == ST_SEND_CMD0)  || (state == ST_SEND_CMD8) ||
                      (state == ST_SEND_CMD55) || (state == ST_SEND_ACMD41) ||
                      (state == ST_RD_SEND);
    end

    always_comb begin
        case (state)
            ST_SEND_CMD0:   cur_cmd = CMD0;
            ST_SEND_CMD8:   cur_cmd = CMD8;
            ST_SEND_CMD55:  cur_cmd = CMD55;
            ST_SEND_ACMD41: cur_cmd = ACMD41;
            ST_RD_SEND:     cur_cmd = {8'h51, block_addr, 8'hFF};
            default:        cur_cmd = 48'hFFFFFFFFFFFF;
        endcase
    end

    always_ff @(posedge clk_ref or negedge rst_n) begin
        if (!rst_n) begin
            cmd_bit_cnt <= 6'd0;
            sd_mosi     <= 1'b1;
            cmd_sent    <= 1'b0;
        end else begin
            cmd_sent <= 1'b0;
            if (send_active) begin
                sd_mosi <= cur_cmd[47 - cmd_bit_cnt];
                if (cmd_bit_cnt == 6'd47) begin
                    cmd_bit_cnt <= 6'd0;
                    cmd_sent    <= 1'b1;
                end else
                    cmd_bit_cnt <= cmd_bit_cnt + 1'b1;
            end else begin
                sd_mosi     <= 1'b1;
                cmd_bit_cnt <= 6'd0;
            end
        end
    end

    // ========================================================================
    // 応答受信 (clk_ref_180deg の posedge = sd_clk の立ち上がりでラッチ)
    //   初期化コマンド: R1 = 8bit。スタートビット(0)検出後、8bit 受信。
    // ========================================================================
    logic        rx_flag;
    logic [2:0]  rx_bit_cnt;
    logic [7:0]  rx_sr;
    logic [7:0]  rx_byte;
    logic        rx_byte_ready;
    logic        r1_mode;      // R1 受信 (スタートビット検出)
    logic        data_mode;    // データ連続受信

    always_comb begin
        r1_mode = (state == ST_WAIT_CMD0)  || (state == ST_WAIT_CMD8) ||
                  (state == ST_WAIT_CMD55) || (state == ST_WAIT_ACMD41) ||
                  (state == ST_RD_WAIT_R1);
        data_mode = (state == ST_RD_WAIT_TOKEN) || (state == ST_RD_DATA) ||
                    (state == ST_RD_CRC);
    end

    always_ff @(posedge clk_ref_180 or negedge rst_n) begin
        if (!rst_n) begin
            rx_flag       <= 1'b0;
            rx_bit_cnt    <= 3'd0;
            rx_sr         <= 8'd0;
            rx_byte       <= 8'd0;
            rx_byte_ready <= 1'b0;
        end else begin
            rx_byte_ready <= 1'b0;

            if (r1_mode || data_mode) begin
                if (!rx_flag) begin
                    if (r1_mode) begin
                        // スタートビット (MISO=0) を待つ (カウントしない)
                        if (sd_dat == 1'b0) begin
                            rx_flag    <= 1'b1;
                            rx_sr      <= 8'd0;
                            rx_bit_cnt <= 3'd0;
                        end
                    end else begin
                        // データモード: 連続 8bit
                        rx_flag    <= 1'b1;
                        rx_sr      <= {7'b0, sd_dat};
                        rx_bit_cnt <= 3'd1;
                    end
                end else begin
                    rx_sr <= {rx_sr[6:0], sd_dat};
                    if (rx_bit_cnt == 3'd7) begin
                        rx_byte       <= {rx_sr[6:0], sd_dat};
                        rx_byte_ready <= 1'b1;
                        rx_flag       <= 1'b0;
                        rx_bit_cnt    <= 3'd0;
                    end else
                        rx_bit_cnt <= rx_bit_cnt + 1'b1;
                end
            end else begin
                rx_flag    <= 1'b0;
                rx_bit_cnt <= 3'd0;
            end
        end
    end

    // ========================================================================
    // メイン状態機械
    // ========================================================================
    logic [24:0] over_time_cnt;
    logic [7:0]  acmd41_tries;
    logic [9:0]  data_cnt;
    logic [9:0]  crc_cnt;

    always_ff @(posedge clk_ref or negedge rst_n) begin
        if (!rst_n)
            state <= ST_IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            ST_IDLE: begin
                if (poweron_cnt == POWER_ON_NUM + 3'd6)
                    next_state = ST_SEND_CMD0;
            end

            ST_SEND_CMD0: begin
                if (cmd_sent)
                    next_state = ST_WAIT_CMD0;
            end

            ST_WAIT_CMD0: begin
                if (rx_byte_ready) begin
                    if (rx_byte == 8'h01)
                        next_state = ST_SEND_CMD8;
                    else
                        next_state = ST_SEND_CMD0;
                end else if (over_time_cnt == 25'd25_000_000)
                    next_state = ST_SEND_CMD0;
            end

            ST_SEND_CMD8: begin
                if (cmd_sent)
                    next_state = ST_WAIT_CMD8;
            end

            ST_WAIT_CMD8: begin
                if (rx_byte_ready)
                    next_state = ST_SEND_CMD55;
                else if (over_time_cnt == 25'd25_000_000)
                    next_state = ST_SEND_CMD8;
            end

            ST_SEND_CMD55: begin
                if (cmd_sent)
                    next_state = ST_WAIT_CMD55;
            end

            ST_WAIT_CMD55: begin
                if (rx_byte_ready)
                    next_state = ST_SEND_ACMD41;
                else if (over_time_cnt == 25'd25_000_000)
                    next_state = ST_SEND_CMD55;
            end

            ST_SEND_ACMD41: begin
                if (cmd_sent)
                    next_state = ST_WAIT_ACMD41;
            end

            ST_WAIT_ACMD41: begin
                if (rx_byte_ready) begin
                    if (rx_byte == 8'h00)
                        next_state = ST_INIT_DONE;
                    else
                        next_state = ST_SEND_CMD55;
                end else if (over_time_cnt == 25'd25_000_000)
                    next_state = ST_SEND_CMD55;
            end

            ST_INIT_DONE: next_state = ST_RD_IDLE;
            ST_RD_IDLE: begin
                if (read_req)
                    next_state = ST_RD_SEND;
            end
            ST_RD_SEND: begin
                if (cmd_sent)
                    next_state = ST_RD_WAIT_R1;
            end
            ST_RD_WAIT_R1: begin
                if (rx_byte_ready) begin
                    if (rx_byte == 8'h00)
                        next_state = ST_RD_WAIT_TOKEN;
                    else
                        next_state = ST_RD_IDLE;
                end
            end
            ST_RD_WAIT_TOKEN: begin
                if (rx_byte_ready && rx_byte == 8'hFE)
                    next_state = ST_RD_DATA;
            end
            ST_RD_DATA: begin
                if (rx_byte_ready && data_cnt == 10'd511)
                    next_state = ST_RD_CRC;
            end
            ST_RD_CRC: begin
                if (rx_byte_ready && crc_cnt == 10'd1)
                    next_state = ST_RD_IDLE;
            end
            default: next_state = ST_IDLE;
        endcase
    end

    // ---- 制御出力 (state に同期して更新) ----
    always_ff @(posedge clk_ref or negedge rst_n) begin
        if (!rst_n) begin
            over_time_cnt <= 25'd0;
            acmd41_tries  <= 8'd0;
            data_cnt      <= 10'd0;
            crc_cnt       <= 10'd0;
            sd_cs_n       <= 1'b1;
            data          <= 8'h00;
            data_valid    <= 1'b0;
            busy          <= 1'b1;
            init_done     <= 1'b0;
        end else begin
            data_valid <= 1'b0;

            // 送信中 / 応答待ちで CS を制御
            case (state)
                ST_SEND_CMD0, ST_SEND_CMD8, ST_SEND_CMD55, ST_SEND_ACMD41,
                ST_RD_SEND:
                    sd_cs_n <= 1'b0;

                ST_WAIT_CMD0, ST_WAIT_CMD8, ST_WAIT_CMD55, ST_WAIT_ACMD41,
                ST_RD_WAIT_R1, ST_RD_WAIT_TOKEN, ST_RD_DATA, ST_RD_CRC:
                    sd_cs_n <= 1'b0;

                default:
                    sd_cs_n <= 1'b1;
            endcase

            // タイムアウトカウンタ
            if (state == ST_WAIT_CMD0 || state == ST_WAIT_CMD8 ||
                state == ST_WAIT_CMD55 || state == ST_WAIT_ACMD41)
                over_time_cnt <= over_time_cnt + 1'b1;
            else
                over_time_cnt <= 25'd0;

            // 初期化完了
            if (state == ST_INIT_DONE) begin
                init_done <= 1'b1;
                busy      <= 1'b0;
            end

            // データ受信
            if (state == ST_RD_DATA && rx_byte_ready) begin
                data       <= rx_byte;
                data_valid <= 1'b1;
                if (data_cnt == 10'd511)
                    data_cnt <= 10'd0;
                else
                    data_cnt <= data_cnt + 1'b1;
            end

            if (state == ST_RD_CRC && rx_byte_ready) begin
                if (crc_cnt == 10'd1)
                    crc_cnt <= 10'd0;
                else
                    crc_cnt <= crc_cnt + 1'b1;
            end

            if (state == ST_RD_IDLE && read_req)
                busy <= 1'b1;
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
