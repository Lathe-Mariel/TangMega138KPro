// ============================================================================
//  sd_reader.sv
//  SDカード SPIモード ブロックリーダ
//
//  【機能】
//   ・SDカードを SPI モードで初期化 (CMD0 → CMD8 → ACMD41)
//   ・CMD17 (READ_SINGLE_BLOCK) で 512バイトのブロックを読み出す
//   ・読み出したバイトを "data / data_valid" で出力する
//
//  【インターフェース】
//   入力  clk        : システムクロック (50MHz想定)
//   入力  rst_n      : 非同期リセット (アクティブLow)
//   出力  sd_clk     : SPIクロック
//   出力  sd_cmd     : MOSI
//   入力  sd_dat     : MISO
//   出力  sd_cs_n    : チップセレクト (アクティブLow)
//   出力  data       : 読み出した1バイト
//   出力  data_valid : data が有効な間 High (1クロック)
//   出力  busy       : 読み出し中/初期化中
//
//  【使い方】
//   read_req を1クロック High にすると、block_addr から
//   1ブロック (512バイト) を読み出し、data/data_valid で順次出力する。
//
//  ※ SPIモード0 (CPOL=0, CPHA=0) を使用。CRC はダミー (0xFF)。
// ============================================================================
module sd_reader #(
    parameter int SYS_CLK_HZ   = 50_000_000,   // システムクロック周波数
    parameter int INIT_SPI_HZ  = 400_000,      // 初期化時の SPI クロック
    parameter int DATA_SPI_HZ  = 10_000_000    // 通常時の SPI クロック
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
    output logic        busy
);

    // ========================================================================
    // 状態定義
    // ========================================================================
    typedef enum logic [3:0] {
        ST_POWER_DELAY,   // 電源投入後のディレイ
        ST_INIT_CMD0,     // CMD0 送信
        ST_INIT_CMD8,     // CMD8 送信
        ST_INIT_ACMD55,   // CMD55 送信 (ACMD のプレフィックス)
        ST_INIT_ACMD41,   // ACMD41 送信
        ST_INIT_DONE,     // 初期化完了
        ST_IDLE,          // 待機
        ST_READ_CMD17,    // CMD17 送信
        ST_READ_WAIT,     // データトークン 0xFE 待ち
        ST_READ_DATA,     // 512バイト読み出し
        ST_READ_CRC       // CRC2バイト読み捨て
    } state_t;

    state_t state;
    state_t ret_state;    // コマンド送信後に戻る状態

    // ========================================================================
    // SPI クロック生成 (分周)
    // ========================================================================
    localparam int INIT_DIV = SYS_CLK_HZ / INIT_SPI_HZ / 2;
    localparam int DATA_DIV = SYS_CLK_HZ / DATA_SPI_HZ / 2;

    logic [15:0] div_cnt;
    logic        fast_clk;    // 1: 高速 SPI クロック
    logic        sp_clk;      // 内部 SPI クロック
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
    // SPI バイト転送シフトレジスタ
    // ========================================================================
    logic        byte_run;      // 1バイト転送中
    logic [7:0]  tx_sr;         // 送信シフトレジスタ
    logic [7:0]  rx_sr;         // 受信シフトレジスタ
    logic [2:0]  bit_cnt;       // 転送済みビット数 (0..7)
    logic [7:0]  rx_byte;       // 受信完了バイト
    logic        rx_byte_ready; // 受信完了 (1クロックパルス)

    // 送信開始 (外部状態機械から起動)
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
            sd_cmd        <= 1'b1;
        end else begin
            rx_byte_ready <= 1'b0;   // デフォルト: パルスは1クロックのみ

            if (!byte_run && byte_start) begin
                // 1バイト転送開始
                byte_run <= 1'b1;
                tx_sr    <= byte_tx;
                rx_sr    <= 8'h00;
                bit_cnt  <= 3'd0;
            end else if (byte_run) begin
                if (sp_rise) begin
                    // 立ち上がり: MISO をサンプル
                    rx_sr   <= {rx_sr[6:0], sd_dat};
                    bit_cnt <= bit_cnt + 3'd1;
                end else if (sp_fall) begin
                    // 立ち下がり: 次の MOSI ビットを出力 (SPIモード0)
                    tx_sr  <= {tx_sr[6:0], 1'b1};
                    sd_cmd <= tx_sr[7];
                end

                // 8ビット転送完了判定 (最後の立ち上がりで bit_cnt==7)
                if (sp_rise && bit_cnt == 3'd7) begin
                    byte_run      <= 1'b0;
                    rx_byte       <= {rx_sr[6:0], sd_dat};
                    rx_byte_ready <= 1'b1;
                end
            end
        end
    end

    // ========================================================================
    // コマンド送信ヘルパ
    // ========================================================================
    logic [2:0]  byte_idx;       // 送信中のコマンドバイト (0..5)
    logic [5:0]  cmd_index;
    logic [31:0] cmd_arg;

    // 各状態で送信するコマンド/引数/戻り先を決定
    always_comb begin
        cmd_index = 6'd0;
        cmd_arg   = 32'h0;
        ret_state = ST_IDLE;
        case (state)
            ST_INIT_CMD0:   begin cmd_index = 6'd0;  cmd_arg = 32'h00000000; ret_state = ST_INIT_CMD8;   end
            ST_INIT_CMD8:   begin cmd_index = 6'd8;  cmd_arg = 32'h000001AA; ret_state = ST_INIT_ACMD55; end
            ST_INIT_ACMD55: begin cmd_index = 6'd55; cmd_arg = 32'h00000000; ret_state = ST_INIT_ACMD41; end
            ST_INIT_ACMD41: begin cmd_index = 6'd41; cmd_arg = 32'h40000000; ret_state = ST_INIT_DONE;   end
            ST_READ_CMD17:  begin cmd_index = 6'd17; cmd_arg = block_addr;   ret_state = ST_READ_WAIT;   end
            default:        begin cmd_index = 6'd0;  cmd_arg = 32'h0;        ret_state = ST_IDLE;        end
        endcase
    end

    // 送信バイトの決定
    always_comb begin
        case (byte_idx)
            3'd0: byte_tx = {2'b01, cmd_index};   // 0x40 | cmd
            3'd1: byte_tx = cmd_arg[31:24];
            3'd2: byte_tx = cmd_arg[23:16];
            3'd3: byte_tx = cmd_arg[15:8];
            3'd4: byte_tx = cmd_arg[7:0];
            default: byte_tx = 8'hFF;             // CRC (ダミー)
        endcase
    end

    // ========================================================================
    // メイン状態機械
    // ========================================================================
    logic [23:0] timer;      // 汎用タイマ
    logic [9:0]  data_cnt;   // データバイトカウンタ (0..511)

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= ST_POWER_DELAY;
            timer     <= 24'd0;
            byte_idx  <= 3'd0;
            byte_start<= 1'b0;
            data_cnt  <= 10'd0;
            data      <= 8'h00;
            data_valid<= 1'b0;
            busy      <= 1'b1;
            fast_clk  <= 1'b0;
        end else begin
            // ---- デフォルト ----
            byte_start <= 1'b0;
            data_valid <= 1'b0;

            case (state)
                // 電源投入ディレイ (約20ms)
                ST_POWER_DELAY: begin
                    if (timer >= 24'd1_000_000) begin   // 50MHz x 20ms
                        state <= ST_INIT_CMD0;
                        timer <= 24'd0;
                    end else begin
                        timer <= timer + 24'd1;
                    end
                end

                // 初期化コマンド送信 (共通)
                ST_INIT_CMD0, ST_INIT_CMD8, ST_INIT_ACMD55, ST_INIT_ACMD41: begin
                    if (byte_idx < 3'd6) begin
                        if (!byte_run && !byte_start) begin
                            byte_start <= 1'b1;
                        end else if (rx_byte_ready) begin
                            byte_idx <= byte_idx + 3'd1;
                        end
                    end else begin
                        byte_idx <= 3'd0;
                        state    <= ret_state;
                    end
                end

                ST_INIT_DONE: begin
                    fast_clk <= 1'b1;   // 高速クロックへ切り替え
                    busy     <= 1'b0;
                    state    <= ST_IDLE;
                end

                // 待機
                ST_IDLE: begin
                    if (read_req) begin
                        busy     <= 1'b1;
                        byte_idx <= 3'd0;
                        state    <= ST_READ_CMD17;
                    end
                end

                // ブロック読み出し
                ST_READ_CMD17: begin
                    if (byte_idx < 3'd6) begin
                        if (!byte_run && !byte_start) begin
                            byte_start <= 1'b1;
                        end else if (rx_byte_ready) begin
                            byte_idx <= byte_idx + 3'd1;
                        end
                    end else begin
                        byte_idx <= 3'd0;
                        state    <= ST_READ_WAIT;
                        timer    <= 24'd0;
                    end
                end

                ST_READ_WAIT: begin
                    // データトークン 0xFE を待つ
                    if (rx_byte_ready && rx_byte == 8'hFE) begin
                        data_cnt <= 10'd0;
                        state    <= ST_READ_DATA;
                    end else if (timer >= 24'd100_000) begin
                        // タイムアウト: アイドルへ
                        state <= ST_IDLE;
                        busy  <= 1'b0;
                    end else begin
                        if (!byte_run && !byte_start)
                            byte_start <= 1'b1;   // ダミー0xFF を送る
                        if (rx_byte_ready)
                            timer <= timer + 24'd1;
                    end
                end

                ST_READ_DATA: begin
                    if (!byte_run && !byte_start) begin
                        byte_start <= 1'b1;   // 0xFF 送信して受信
                    end else if (rx_byte_ready) begin
                        data       <= rx_byte;
                        data_valid <= 1'b1;
                        if (data_cnt == 10'd511) begin
                            data_cnt <= 10'd0;
                            state    <= ST_READ_CRC;
                        end else begin
                            data_cnt <= data_cnt + 10'd1;
                        end
                    end
                end

                ST_READ_CRC: begin
                    // CRC2バイト読み捨て
                    if (rx_byte_ready) begin
                        if (data_cnt == 10'd1) begin
                            data_cnt <= 10'd0;
                            state    <= ST_IDLE;
                            busy     <= 1'b0;
                        end else begin
                            data_cnt <= data_cnt + 10'd1;
                        end
                    end else if (!byte_run && !byte_start) begin
                        byte_start <= 1'b1;
                    end
                end

                default: state <= ST_POWER_DELAY;
            endcase
        end
    end

    // ========================================================================
    // チップセレクト: 転送中は Low
    // ========================================================================
    assign sd_cs_n = (state == ST_IDLE || state == ST_POWER_DELAY) ? 1'b1 : 1'b0;

endmodule
