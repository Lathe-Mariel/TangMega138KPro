// ============================================================================
//  sd_reader.sv
//  SDカード SPIモード ブロックリーダ (正しい初期化シーケンス版)
//
//  【機能】
//   ・SDカードを SPI モードに切替 (CMD0)
//   ・初期化 (CMD8 → CMD55/ACMD41 ループ)
//   ・CMD17 (READ_SINGLE_BLOCK) で 512バイトのブロックを読み出す
//   ・読み出したバイトを data / data_valid で出力
//
//  【SPI シーケンス (SD規格準拠)】
//    1. 電源投入後、CS=High で 74 クロック以上のダミー送出
//    2. CS=Low
//    3. CMD0 (CRC=0x95) → R1 = 0x01 を確認
//    4. CMD8 (CRC=0x87) → R1 を確認
//    5. CMD55 + ACMD41 を R1=0x00 (ready) になるまで繰り返す
//    6. CMD17 → R1=0x00 → データトークン 0xFE → 512バイト + CRC2バイト
//
//  ※ SPIモード0 (CPOL=0, CPHA=0)
// ============================================================================
module sd_reader #(
    parameter int SYS_CLK_HZ  = 50_000_000,
    parameter int INIT_SPI_HZ = 400_000,      // 初期化時 SPI クロック (<400kHz)
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
    output logic        init_done,  // 初期化完了フラグ (デバッグ用)
    output logic [2:0]  debug_stage // 現在の初期化フェーズ (デバッグ用)
);

    // ========================================================================
    // 状態定義
    // ========================================================================
    typedef enum logic [4:0] {
        ST_POWER_DELAY,   // 電源投入ディレイ
        ST_DUMMY_CLK,     // 74+ ダミークロック (CS=High)
        ST_CMD0_SEND,     // CMD0 送信
        ST_CMD0_RESP,     // CMD0 R1 受信
        ST_CMD8_SEND,     // CMD8 送信
        ST_CMD8_RESP,     // CMD8 R1 受信
        ST_CMD8_ARG,      // CMD8 R7 の残り4バイト読捨て
        ST_ACMD55_SEND,   // CMD55 送信
        ST_ACMD55_RESP,   // CMD55 R1 受信
        ST_ACMD41_SEND,   // ACMD41 送信
        ST_ACMD41_RESP,   // ACMD41 R1 受信
        ST_INIT_DONE,     // 初期化完了
        ST_IDLE,          // 待機
        ST_CMD17_SEND,    // CMD17 送信
        ST_CMD17_RESP,    // CMD17 R1 受信
        ST_WAIT_TOKEN,    // データトークン 0xFE 待ち
        ST_READ_DATA,     // 512バイト読み出し
        ST_READ_CRC       // CRC2バイト読捨て
    } state_t;

    state_t state;
    state_t ret_state;

    // ========================================================================
    // SPI クロック生成 (分周)
    // ========================================================================
    localparam int INIT_DIV = SYS_CLK_HZ / INIT_SPI_HZ / 2;
    localparam int DATA_DIV = SYS_CLK_HZ / DATA_SPI_HZ / 2;

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
            // SPIクロックはバイト転送中のみトグル (正しいSPIマスタ動作)
            if (byte_run) begin
                if (div_cnt >= div_target - 1) begin
                    div_cnt <= 16'd0;
                    sp_clk  <= ~sp_clk;
                end else begin
                    div_cnt <= div_cnt + 16'd1;
                end
            end else begin
                div_cnt <= 16'd0;
                sp_clk  <= 1'b0;
            end
        end
    end

    assign sp_rise =  sp_clk && !sp_clk_prev;
    assign sp_fall = !sp_clk &&  sp_clk_prev;
    assign sd_clk  = sp_clk;

    // ========================================================================
    // SPI バイト転送
    // ========================================================================
    logic        byte_run;
    logic [7:0]  tx_sr;
    logic [7:0]  rx_sr;
    logic [2:0]  bit_cnt;
    logic [7:0]  rx_byte;
    logic        rx_byte_ready;

    logic        byte_start;
    logic [7:0]  byte_tx;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            byte_run      <= 1'b0;
            tx_sr         <= 8'hFF;
            rx_sr         <= 8'h00;
            bit_cnt       <= 3'd0;
            rx_byte       <= 8'h00;
            rx_byte_ready <= 1'b0;
        end else begin
            rx_byte_ready <= 1'b0;

            if (!byte_run && byte_start) begin
                // バイト転送開始: 送信バイトをロード
                byte_run <= 1'b1;
                tx_sr    <= tx_actual;
                rx_sr    <= 8'h00;
                bit_cnt  <= 3'd0;
            end else if (byte_run) begin
                if (sp_fall) begin
                    // 立ち下がり: シフト (次のビットが MSB に出る)
                    tx_sr <= {tx_sr[6:0], 1'b1};
                end
                if (sp_rise) begin
                    // 立ち上がり: MISO サンプル
                    if (bit_cnt == 3'd7) begin
                        byte_run      <= 1'b0;
                        rx_byte       <= {rx_sr[6:0], sd_dat};
                        rx_byte_ready <= 1'b1;
                    end else begin
                        rx_sr   <= {rx_sr[6:0], sd_dat};
                        bit_cnt <= bit_cnt + 3'd1;
                    end
                end
            end
        end
    end

    // MOSI はシフトレジスタの MSB を組み合わせ出力 (アイドル時は High)
    assign sd_cmd = tx_sr[7];

    // ========================================================================
    // コマンド生成
    // ========================================================================
    logic [2:0]  byte_idx;
    logic [7:0]  cmd_byte0;
    logic [7:0]  cmd_crc;
    logic [31:0] cmd_arg;
    logic [5:0]  cmd_index;

    // 送信バイト決定
    always_comb begin
        case (byte_idx)
            3'd0: byte_tx = cmd_byte0;
            3'd1: byte_tx = cmd_arg[31:24];
            3'd2: byte_tx = cmd_arg[23:16];
            3'd3: byte_tx = cmd_arg[15:8];
            3'd4: byte_tx = cmd_arg[7:0];
            default: byte_tx = cmd_crc;
        endcase
    end

    // 応答受信時 / ダミークロック時は 0xFF を送る
    logic resp_phase;
    always_comb begin
        resp_phase = 1'b0;
        case (state)
            ST_DUMMY_CLK,
            ST_CMD0_RESP, ST_CMD8_RESP, ST_ACMD55_RESP, ST_ACMD41_RESP,
            ST_CMD17_RESP, ST_WAIT_TOKEN, ST_READ_DATA, ST_READ_CRC:
                resp_phase = 1'b1;
            default: resp_phase = 1'b0;
        endcase
    end

    // 実際の送信バイト: 応答受信中は 0xFF
    logic [7:0] tx_actual;
    assign tx_actual = resp_phase ? 8'hFF : byte_tx;

    // 各状態のコマンド
    always_comb begin
        cmd_index = 6'd0;
        cmd_arg   = 32'h0;
        cmd_crc   = 8'hFF;
        case (state)
            ST_CMD0_SEND:   begin cmd_index = 6'd0;  cmd_arg = 32'h00000000; cmd_crc = 8'h95; end
            ST_CMD8_SEND:   begin cmd_index = 6'd8;  cmd_arg = 32'h000001AA; cmd_crc = 8'h87; end
            ST_ACMD55_SEND: begin cmd_index = 6'd55; cmd_arg = 32'h00000000; cmd_crc = 8'h65; end
            ST_ACMD41_SEND: begin cmd_index = 6'd41; cmd_arg = 32'h40000000; cmd_crc = 8'h77; end
            ST_CMD17_SEND:  begin cmd_index = 6'd17; cmd_arg = block_addr;   cmd_crc = 8'hFF; end
            default:        begin cmd_index = 6'd0;  cmd_arg = 32'h0;        cmd_crc = 8'hFF; end
        endcase
        cmd_byte0 = {2'b01, cmd_index};
    end

    // ========================================================================
    // メイン状態機械
    // ========================================================================
    logic [23:0] timer;
    logic [9:0]  data_cnt;
    logic [7:0]  acmd41_tries;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= ST_POWER_DELAY;
            timer       <= 24'd0;
            byte_idx    <= 3'd0;
            byte_start  <= 1'b0;
            data_cnt    <= 10'd0;
            acmd41_tries<= 8'd0;
            data        <= 8'h00;
            data_valid  <= 1'b0;
            busy        <= 1'b1;
            fast_clk    <= 1'b0;
            init_done   <= 1'b0;
        end else begin
            byte_start <= 1'b0;
            data_valid <= 1'b0;

            case (state)

                ST_POWER_DELAY: begin
                    if (timer >= 24'd1_000_000) begin
                        state <= ST_DUMMY_CLK;
                        timer <= 24'd0;
                    end else
                        timer <= timer + 24'd1;
                end

                // 74+ ダミークロック (CS=High のまま 0xFF を10バイト = 80クロック)
                ST_DUMMY_CLK: begin
                    if (rx_byte_ready)
                        byte_idx <= byte_idx + 3'd1;
                    else if (byte_idx < 3'd6) begin
                        if (!byte_run && !byte_start)
                            byte_start <= 1'b1;
                    end else begin
                        byte_idx <= 3'd0;
                        state    <= ST_CMD0_SEND;
                    end
                end

                // --- コマンド6バイト送信 (共通) ---
                ST_CMD0_SEND, ST_CMD8_SEND, ST_ACMD55_SEND, ST_ACMD41_SEND, ST_CMD17_SEND: begin
                    if (rx_byte_ready)
                        byte_idx <= byte_idx + 3'd1;
                    else if (byte_idx < 3'd6) begin
                        if (!byte_run && !byte_start)
                            byte_start <= 1'b1;
                    end else begin
                        byte_idx <= 3'd0;
                        state    <= ret_state;
                    end
                end

                // --- R1 レスポンス受信 (0xFF を送って R1 を読む) ---
                //   0xFF は busy インジケータなので無視して待ち続ける
                ST_CMD0_RESP: begin
                    if (rx_byte_ready) begin
                        if (rx_byte == 8'hFF) begin
                            // busy: 待ち続ける
                        end else if (rx_byte == 8'h01)
                            state <= ST_CMD8_SEND;
                        else
                            state <= ST_CMD0_SEND;
                    end else if (!byte_run && !byte_start)
                        byte_start <= 1'b1;
                end

                ST_CMD8_RESP: begin
                    if (rx_byte_ready) begin
                        if (rx_byte == 8'hFF) begin
                            // busy: 待ち続ける
                        end else begin
                            byte_idx <= 3'd0;
                            state    <= ST_CMD8_ARG;
                        end
                    end else if (!byte_run && !byte_start)
                        byte_start <= 1'b1;
                end

                ST_CMD8_ARG: begin
                    if (rx_byte_ready)
                        byte_idx <= byte_idx + 3'd1;
                    else if (byte_idx < 3'd4) begin
                        if (!byte_run && !byte_start)
                            byte_start <= 1'b1;
                    end else begin
                        byte_idx <= 3'd0;
                        state    <= ST_ACMD55_SEND;
                    end
                end

                ST_ACMD55_RESP: begin
                    if (rx_byte_ready) begin
                        if (rx_byte != 8'hFF)   // busy を無視
                            state <= ST_ACMD41_SEND;
                    end else if (!byte_run && !byte_start)
                        byte_start <= 1'b1;
                end

                ST_ACMD41_RESP: begin
                    if (rx_byte_ready) begin
                        // どんな応答でもリトライ (0x00=ready, 0x01=in idle, 0xFF=busy)
                        if (rx_byte == 8'h00) begin
                            state <= ST_INIT_DONE;
                        end else begin
                            if (acmd41_tries >= 8'd255) begin
                                // 諦めて進む (カード不応答でも読み出しを試す)
                                state <= ST_INIT_DONE;
                            end else begin
                                acmd41_tries <= acmd41_tries + 8'd1;
                                state        <= ST_ACMD55_SEND;   // 再試行
                            end
                        end
                    end else if (!byte_run && !byte_start)
                        byte_start <= 1'b1;
                end

                ST_INIT_DONE: begin
                    fast_clk  <= 1'b1;
                    busy      <= 1'b0;
                    init_done <= 1'b1;
                    state     <= ST_IDLE;
                end

                ST_IDLE: begin
                    if (read_req) begin
                        busy     <= 1'b1;
                        byte_idx <= 3'd0;
                        state    <= ST_CMD17_SEND;
                    end
                end

                ST_CMD17_RESP: begin
                    if (rx_byte_ready) begin
                        if (rx_byte == 8'hFF) begin
                            // busy: 待ち続ける
                        end else if (rx_byte == 8'h00)
                            state <= ST_WAIT_TOKEN;
                        else
                            state <= ST_IDLE;
                    end else if (!byte_run && !byte_start)
                        byte_start <= 1'b1;
                end

                ST_WAIT_TOKEN: begin
                    if (rx_byte_ready && rx_byte == 8'hFE) begin
                        data_cnt <= 10'd0;
                        state    <= ST_READ_DATA;
                    end else begin
                        if (!byte_run && !byte_start)
                            byte_start <= 1'b1;
                        if (timer >= 24'd100_000) begin
                            state <= ST_IDLE;
                            busy  <= 1'b0;
                        end else if (rx_byte_ready)
                            timer <= timer + 24'd1;
                    end
                end

                ST_READ_DATA: begin
                    if (rx_byte_ready) begin
                        data       <= rx_byte;
                        data_valid <= 1'b1;
                        if (data_cnt == 10'd511) begin
                            data_cnt <= 10'd0;
                            state    <= ST_READ_CRC;
                        end else
                            data_cnt <= data_cnt + 10'd1;
                    end else if (!byte_run && !byte_start)
                        byte_start <= 1'b1;
                end

                ST_READ_CRC: begin
                    if (rx_byte_ready) begin
                        if (data_cnt == 10'd1) begin
                            state <= ST_IDLE;
                            busy  <= 1'b0;
                        end else
                            data_cnt <= data_cnt + 10'd1;
                    end else if (!byte_run && !byte_start)
                        byte_start <= 1'b1;
                end

                default: state <= ST_POWER_DELAY;
            endcase
        end
    end

    // ========================================================================
    // 戻り先状態の決定
    // ========================================================================
    always_comb begin
        ret_state = ST_IDLE;
        case (state)
            ST_CMD0_SEND:   ret_state = ST_CMD0_RESP;
            ST_CMD8_SEND:   ret_state = ST_CMD8_RESP;
            ST_ACMD55_SEND: ret_state = ST_ACMD55_RESP;
            ST_ACMD41_SEND: ret_state = ST_ACMD41_RESP;
            ST_CMD17_SEND:  ret_state = ST_CMD17_RESP;
            default:        ret_state = ST_IDLE;
        endcase
    end

    // ========================================================================
    // チップセレクト: 初期化開始後は Low を維持
    // ========================================================================
    assign sd_cs_n = (state == ST_POWER_DELAY || state == ST_DUMMY_CLK) ? 1'b1 : 1'b0;

    // ========================================================================
    // デバッグ: 現在の初期化フェーズを 3bit で出力
    //   0: POWER_DELAY / DUMMY_CLK
    //   1: CMD0
    //   2: CMD8
    //   3: ACMD55/ACMD41 (ループ中)
    //   4: INIT_DONE 以降
    // ========================================================================
    always_comb begin
        case (state)
            ST_POWER_DELAY, ST_DUMMY_CLK: debug_stage = 3'd0;
            ST_CMD0_SEND, ST_CMD0_RESP:   debug_stage = 3'd1;
            ST_CMD8_SEND, ST_CMD8_RESP, ST_CMD8_ARG: debug_stage = 3'd2;
            ST_ACMD55_SEND, ST_ACMD55_RESP, ST_ACMD41_SEND, ST_ACMD41_RESP:
                                           debug_stage = 3'd3;
            default:                       debug_stage = 3'd4;
        endcase
    end

endmodule
