// =====================================================================
// frame_scan : 画面全体をラスタスキャンしながら pixel_render を駆動する
//   トップモジュール。GLSLの p=fragCoord/iResolution; q=-1+2p; q.x*=1.777
//   に相当する座標生成を行い、1ピクセルずつ計算結果を pixel_valid/pixel_rgb565
//   として出力する。既存のILI9341/ST7789V SPIドライバ側でこれを受けて
//   フレームバッファまたはストリーミング書き込みを行う想定。
//
//   ※ 性能上の注意:
//   1ピクセルあたり最大で 数千クロック (地形にヒットした場合、march+法線+
//   シャドウ+ガンマで map_core呼び出しが300回超、fixed_div呼び出しも
//   数十回発生しうる) かかる。240x240=57600ピクセル換算では
//   1フレームに数億クロック規模となり、100MHz動作でも数秒/フレームという
//   オーダーになる。リアルタイム表示には
//     - MARCH_STEPS/SHADOW_STEPS/NUM_OCTAVESを削減する
//     - map_core / fixed_div を複数インスタンス化してピクセル並列化する
//     - map_core内のcos_noiseをパイプライン化して1オクターブ/サイクルより
//       高速化する
//   などの追加最適化が別途必要。本モジュールはまず機能的に正しいベースラインを
//   与えるものであり、そのままでは実写リアルタイム表示は想定していない。
// =====================================================================
module frame_scan
    import rm_pkg::*;
#(
    parameter int NUM_OCTAVES  = 10,
    parameter int MARCH_STEPS  = 256,
    parameter int SHADOW_STEPS = 64,
    parameter int H_RES = 320,
    parameter int V_RES = 240,
    parameter int TIME_STEP_PER_FRAME = 8738  // 1フレームあたりiTime増分(Q12.20, 例:約0.00833=1/120s)
)(
    input  logic clk,
    input  logic rst_n,
    input  logic frame_start,     // 1フレーム分のスキャン開始トリガ(パルス)
    output logic pixel_valid,     // 1クロックパルス: pixel_rgb565が確定
    output logic [$clog2(H_RES)-1:0] pixel_col,
    output logic [$clog2(V_RES)-1:0] pixel_row,
    output logic [15:0] pixel_rgb565,
    output logic frame_done       // 1クロックパルス: 1フレーム分完了
);
    localparam fixed_t ASPECT   = fixed_t'(1863320);   // 1.777
    localparam fixed_t TWO_C    = fixed_t'(2 <<< FRAC);
    localparam fixed_t INV_HRES = fixed_t'((1<<<FRAC) / H_RES);
    localparam fixed_t INV_VRES = fixed_t'((1<<<FRAC) / V_RES);

    logic [$clog2(H_RES)-1:0] col;
    logic [$clog2(V_RES)-1:0] row;
    fixed_t time_reg;

    logic pr_start, pr_busy, pr_done;
    fixed_t qx, qy;
    logic [15:0] rgb;

    pixel_render #(
        .NUM_OCTAVES(NUM_OCTAVES), .MARCH_STEPS(MARCH_STEPS), .SHADOW_STEPS(SHADOW_STEPS)
    ) u_pixel (
        .clk, .rst_n, .start(pr_start),
        .qx_in(qx), .qy_in(qy), .time_in(time_reg),
        .busy(pr_busy), .done(pr_done), .rgb565(rgb)
    );

    // p = (col+0.5)/H_RES, (row+0.5)/V_RES ; q = -1+2p ; q.x *= aspect
    always_comb begin
        fixed_t px, py;
        px = fmul({{(WIDTH-$clog2(H_RES)){1'b0}}, col} <<< FRAC, INV_HRES) + fmul(HALF, INV_HRES);
        py = fmul({{(WIDTH-$clog2(V_RES)){1'b0}}, row} <<< FRAC, INV_VRES) + fmul(HALF, INV_VRES);
        qx = fmul(-ONE + fmul(TWO_C, px), ASPECT);
        qy = -ONE + fmul(TWO_C, py);
    end

    typedef enum logic [1:0] {F_IDLE, F_RUN_GO, F_RUN_WAIT, F_ADVANCE} fstate_t;
    fstate_t fstate;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fstate       <= F_IDLE;
            col          <= '0;
            row          <= '0;
            time_reg     <= '0;
            pr_start     <= 1'b0;
            pixel_valid  <= 1'b0;
            pixel_col    <= '0;
            pixel_row    <= '0;
            pixel_rgb565 <= '0;
            frame_done   <= 1'b0;
        end else begin
            pr_start    <= 1'b0;
            pixel_valid <= 1'b0;
            frame_done  <= 1'b0;

            unique case (fstate)
                F_IDLE: begin
                    if (frame_start) begin
                        col   <= '0;
                        row   <= '0;
                        fstate <= F_RUN_GO;
                    end
                end
                F_RUN_GO: begin
                    pr_start <= 1'b1;
                    fstate   <= F_RUN_WAIT;
                end
                F_RUN_WAIT: begin
                    if (pr_done) begin
                        pixel_valid  <= 1'b1;
                        pixel_col    <= col;
                        pixel_row    <= row;
                        pixel_rgb565 <= rgb;
                        fstate       <= F_ADVANCE;
                    end
                end
                F_ADVANCE: begin
                    if (col == H_RES-1) begin
                        col <= '0;
                        if (row == V_RES-1) begin
                            row       <= '0;
                            time_reg  <= time_reg + fixed_t'(TIME_STEP_PER_FRAME);
                            frame_done<= 1'b1;
                            fstate    <= F_IDLE;
                        end else begin
                            row    <= row + 1'b1;
                            fstate <= F_RUN_GO;
                        end
                    end else begin
                        col    <= col + 1'b1;
                        fstate <= F_RUN_GO;
                    end
                end
                default: fstate <= F_IDLE;
            endcase
        end
    end
endmodule
