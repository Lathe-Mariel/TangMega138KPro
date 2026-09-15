// ============================================================================
//  frame_writer.sv
//  bmp_parser から受け取ったピクセルを、Video_Frame_Buffer の書込ポート
//  (vs_n / de / data) の形に変換する。
//
//  【動作】
//   ・bmp_parser は画像サイズ分 (例: 1280x720) のピクセルを px_valid と共に
//      順次出力する (ラスタ順: 左上→右下)。
//   ・本モジュールはそれをそのまま VFB 書込ポートに流し込む。
//      - フレーム先頭で vs_n を Low (フレーム開始パルス)
//      - ピクセル有効期間は de=1, data={r,g,b}
//   ・1フレーム分 (WIDTH*HEIGHT) 書き終えたら de=0 に戻し、
//      wr_halt=1 で VFB の書込を停止、frame_done=1 を立てる。
//
//  ※ 書込クロックは SD 読み出しと同じ clk ドメイン (50MHz) を使う。
//     VFB 内部の FIFO が DMA クロックとの速度差を吸収する。
// ============================================================================
module frame_writer #(
    parameter int WIDTH  = 1280,
    parameter int HEIGHT = 720
) (
    input  logic        clk,
    input  logic        rst_n,

    // 入力ピクセル (bmp_parser から)
    input  logic [7:0]  px_r,
    input  logic [7:0]  px_g,
    input  logic [7:0]  px_b,
    input  logic        px_valid,

    // VFB 書込ポートへ
    output logic        vin_vs_n,     // フレーム開始 (アクティブLowパルス)
    output logic        vin_de,       // データイネーブル
    output logic [23:0] vin_data,     // {R,G,B} 各8bit

    // 制御
    output logic        wr_halt,      // 1: VFB 書込停止
    output logic        frame_done    // 1フレーム書込完了 (1クロックパルス)
);

    // ------------------------------------------------------------------------
    // ピクセルカウンタ (書込んだピクセル数)
    // ------------------------------------------------------------------------
    localparam int TOTAL_PX = WIDTH * HEIGHT;

    logic [31:0] px_cnt;

    // ------------------------------------------------------------------------
    // vs_n 生成: フレーム先頭で数クロック Low にする (VFB はフレーム境界を検出)
    // ------------------------------------------------------------------------
    logic [7:0] vs_pulse_cnt;
    logic       in_vsync;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            px_cnt       <= 32'd0;
            vs_pulse_cnt <= 8'd0;
            in_vsync     <= 1'b0;
            vin_vs_n     <= 1'b1;
            vin_de       <= 1'b0;
            wr_halt      <= 1'b0;
            frame_done   <= 1'b0;
        end else begin
            frame_done <= 1'b0;   // デフォルト: パルスは1クロック

            if (px_cnt == 0 && !in_vsync) begin
                // フレーム開始: vs_n を Low にして同期パルスを出す
                in_vsync     <= 1'b1;
                vs_pulse_cnt <= 8'd0;
                vin_vs_n     <= 1'b0;
            end else if (in_vsync) begin
                // vsync パルスを一定時間維持
                if (vs_pulse_cnt < 8'd10) begin
                    vs_pulse_cnt <= vs_pulse_cnt + 8'd1;
                end else begin
                    in_vsync <= 1'b0;
                    vin_vs_n <= 1'b1;
                end
            end

            // ピクセル書き込み
            if (px_valid && px_cnt < TOTAL_PX) begin
                vin_de <= 1'b1;
                px_cnt <= px_cnt + 32'd1;

                if (px_cnt == TOTAL_PX - 1) begin
                    // 最後のピクセル: フレーム完了
                    vin_de     <= 1'b0;
                    wr_halt    <= 1'b1;   // 以降の書込を停止
                    frame_done <= 1'b1;
                end
            end else if (px_cnt == TOTAL_PX) begin
                vin_de <= 1'b0;
            end
        end
    end

    // データ出力
    assign vin_data = {px_r, px_g, px_b};

endmodule
