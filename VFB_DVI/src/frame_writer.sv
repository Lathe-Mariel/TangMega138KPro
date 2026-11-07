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
    localparam int AW = 11;   // ceil(log2(WIDTH)) = 11 (1280 -> 0..1279)

    // ------------------------------------------------------------------------
    // 水平反転 (左右ミラー) 用ラインバッファ (ピンポン方式)
    //  BMP は各行「左→右」のラスタ順で、bmp_parser/frame_writer は到着順のまま
    //  書き込むため、表示が左右反転してしまう。1 行分 (WIDTH ピクセル) を一旦
    //  バッファし、逆順 (右→左) に吐き出すことで補正する。
    //  入力は px_valid (約 3 クロックに 1 ピクセル) のバースト、出力は 1 クロック
    //  に 1 ピクセルのため、2 本のラインバッファを交互に使い読出しと書込みを分離する。
    // ------------------------------------------------------------------------
    reg [23:0] lb0 [0:WIDTH-1];
    reg [23:0] lb1 [0:WIDTH-1];

    reg          wbuf;          // 書込み中のバッファ (0/1)
    reg          rbuf;          // 読出し中のバッファ (0/1)
    reg [AW-1:0] wcnt;          // 書込みポインタ (0..WIDTH-1)
    reg [AW-1:0] rcnt;          // 読出しポインタ (0..WIDTH-1)
    reg          rd_active;     // 1行分を逆順に吐き出し中

    reg [31:0]   in_px;         // 受信した入力ピクセル数 (0..TOTAL_PX-1)
    reg [31:0]   out_px;        // 出力したピクセル数

    reg          frame_started; // 最初の行の出力開始済み (vs_n を打った)
    reg [3:0]    vs_cnt;        // vs_n パルス幅カウンタ

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wbuf          <= 1'b0;
            rbuf          <= 1'b0;
            wcnt          <= '0;
            rcnt          <= '0;
            rd_active     <= 1'b0;
            in_px         <= 32'd0;
            out_px        <= 32'd0;
            vin_vs_n      <= 1'b1;
            vin_de        <= 1'b0;
            vin_data      <= 24'd0;
            wr_halt       <= 1'b0;
            frame_done    <= 1'b0;
            frame_started <= 1'b0;
            vs_cnt        <= 4'd0;
        end else begin
            frame_done <= 1'b0;   // デフォルト: パルスは1クロック
            vin_de     <= 1'b0;

            // ================= 入力: ピクセルをラインバッファへ書込み =================
            if (px_valid && in_px < TOTAL_PX) begin
                if (wbuf == 1'b0)
                    lb0[wcnt] <= {px_r, px_g, px_b};
                else
                    lb1[wcnt] <= {px_r, px_g, px_b};

                in_px <= in_px + 32'd1;

                if (wcnt == WIDTH-1) begin
                    // 1行分完了: 書込みバッファを切替え、今埋めた行を逆順読出し開始
                    wcnt      <= '0;
                    wbuf      <= ~wbuf;
                    rbuf      <= wbuf;      // 今埋めたバッファ
                    rd_active <= 1'b1;
                    rcnt      <= '0;
                end else begin
                    wcnt <= wcnt + 1'b1;
                end
            end

            // ================= 出力: 1行分を逆順 (右→左) に吐き出し =================
            if (rd_active) begin
                vin_de <= 1'b1;
                if (rbuf == 1'b0)
                    vin_data <= lb0[WIDTH-1-rcnt];
                else
                    vin_data <= lb1[WIDTH-1-rcnt];

                if (rcnt == WIDTH-1) begin
                    rd_active <= 1'b0;
                    rcnt      <= '0;
                end else begin
                    rcnt <= rcnt + 1'b1;
                end

                out_px <= out_px + 32'd1;
                if (out_px == TOTAL_PX-1) begin
                    // 最後の出力ピクセル: フレーム完了
                    wr_halt    <= 1'b1;
                    frame_done <= 1'b1;
                end
            end

            // ================= vs_n: 最初の出力ピクセルに合わせてパルス =================
            if (!frame_started && rd_active) begin
                frame_started <= 1'b1;
                vs_cnt        <= 4'd1;
                vin_vs_n      <= 1'b0;
            end else if (vs_cnt != 4'd0) begin
                if (vs_cnt < 4'd10)
                    vs_cnt   <= vs_cnt + 1'b1;
                else begin
                    vs_cnt   <= 4'd0;
                    vin_vs_n <= 1'b1;
                end
            end
        end
    end

endmodule
