// =====================================================================
// pixel_render : mainImage() 本体を1ピクセルずつ計算するFSM
//   map_core / isqrt_fx / fixed_div を使い回しながら、
//   レイ生成 -> 地形レイマーチ -> 法線 -> ソフトシャドウ -> ライティング
//   -> フォグ -> ガンマ補正(sqrt) -> RGB565量子化 を順に実行する。
// =====================================================================
module pixel_render
    import rm_pkg::*;
#(
    parameter int NUM_OCTAVES  = 10,
    parameter int MARCH_STEPS  = 256,
    parameter int SHADOW_STEPS = 64
)(
    input  logic  clk,
    input  logic  rst_n,
    input  logic  start,      // qx_in/qy_in/time_inが有効、計算開始
    input  fixed_t qx_in,      // 画面空間座標 (アスペクト補正済み, -1..1相当)
    input  fixed_t qy_in,
    input  fixed_t time_in,    // iTime
    output logic   busy,
    output logic   done,       // 1クロックパルス
    output logic [15:0] rgb565
);
    // ---- シーン定数 (Q8.16) -------------------------------------
    localparam fixed_t CAM_Y     = fixed_t'(108134);    // 1.65
    localparam fixed_t LIGHT_X   = fixed_t'(58384);
    localparam fixed_t LIGHT_Y   = fixed_t'(5838);
    localparam fixed_t LIGHT_Z   = -fixed_t'(29192);
    localparam fixed_t SKY_R     = fixed_t'(45875);
    localparam fixed_t SKY_G     = fixed_t'(52429);
    localparam fixed_t SKY_B     = fixed_t'(65536);
    localparam fixed_t LCOL_R    = fixed_t'(131072);
    localparam fixed_t LCOL_G    = fixed_t'(98304);
    localparam fixed_t LCOL_B    = fixed_t'(65536);
    localparam fixed_t AMB_R     = fixed_t'(6554);
    localparam fixed_t AMB_G     = fixed_t'(13107);
    localparam fixed_t AMB_B     = fixed_t'(19661);
    localparam fixed_t MATE0_R   = fixed_t'(6554);
    localparam fixed_t MATE0_G   = fixed_t'(9830);
    localparam fixed_t MATE0_B   = fixed_t'(9830);
    localparam fixed_t MATE1_R   = fixed_t'(13107);
    localparam fixed_t MATE1_G   = fixed_t'(9830);
    localparam fixed_t MATE1_B   = fixed_t'(6554);
    localparam fixed_t FOG_R     = fixed_t'(32768);
    localparam fixed_t FOG_G     = fixed_t'(39322);
    localparam fixed_t FOG_B     = fixed_t'(45875);
    localparam fixed_t EPS       = fixed_t'(655);       // 0.01  (法線計算オフセット)
    localparam fixed_t HIT_EPS   = fixed_t'(66);         // 0.001 (march終了判定)
    localparam fixed_t TMAX      = fixed_t'(2621440);    // 40.0
    localparam fixed_t SMOOTH_RECIP = fixed_t'(327680);  // 1/(0.9-0.7)
    localparam fixed_t SS_E0     = fixed_t'(45875);      // 0.7
    localparam fixed_t SHADOW_T0 = fixed_t'(6554);       // 0.1
    localparam fixed_t SHADOW_RES_EPS = fixed_t'(7);     // 0.0001
    localparam fixed_t K0_002    = fixed_t'(131);        // 0.002
    localparam fixed_t K31       = fixed_t'(2031616);    // 31.0
    localparam fixed_t K63       = fixed_t'(4128768);    // 63.0
    // NOTE: 164.0 はQ8.16(整数部最大約127)に定数として収まらないため、
    //       fmul用の定数は用意せず、下のS_SHAD_WAIT内で
    //       「fixed_t × 整数164の広い中間結果 → 飽和変換」という
    //       専用の計算(sat_from_wide)を行う。

    // ---- 共有演算ユニット -------------------------------------------
    logic map_start, map_busy, map_done;
    fixed_t map_px, map_py, map_pz, map_h;
    map_core #(.NUM_OCTAVES(NUM_OCTAVES)) u_map (
        .clk, .rst_n, .start(map_start),
        .pos_x(map_px), .pos_y(map_py), .pos_z(map_pz),
        .busy(map_busy), .done(map_done), .result_h(map_h)
    );

    logic sqrt_start, sqrt_busy, sqrt_done;
    fixed_t sqrt_x, sqrt_result;
    isqrt_fx #(.NBITS(WIDTH)) u_sqrt (
        .clk, .rst_n, .start(sqrt_start),
        .x_in(sqrt_x), .busy(sqrt_busy), .done(sqrt_done), .result(sqrt_result)
    );

    logic div_start, div_busy, div_done, div_dbz;
    fixed_t div_a, div_b, div_q;
    fixed_div u_div (
        .clk, .rst_n, .start(div_start),
        .a(div_a), .b(div_b), .busy(div_busy), .done(div_done),
        .quotient(div_q), .div_by_zero(div_dbz)
    );

    // ---- レジスタ ----------------------------------------------------
    fixed_t ro_z, rd_x, rd_y, rd_z;
    fixed_t t_reg, h_reg;
    logic [$clog2(MARCH_STEPS+1)-1:0] march_cnt;
    logic hit;
    fixed_t hit_x, hit_y, hit_z;

    fixed_t nacc_x, nacc_y, nacc_z;      // 法線差分の蓄積
    fixed_t nor_x, nor_y, nor_z;
    logic [1:0] axis_cnt;                // 0,1,2 -> x,y,z
    logic       phase_plus;              // 1=+e, 0=-e
    fixed_t     h_plus;

    fixed_t sro_x, sro_y, sro_z;         // シャドウレイ原点
    fixed_t ts_reg, sres_reg;
    logic [$clog2(SHADOW_STEPS+1)-1:0] shadow_cnt;

    fixed_t dif_reg, sm_reg;
    fixed_t lig_r, lig_g, lig_b;
    fixed_t mate_r, mate_g, mate_b;
    fixed_t col_r, col_g, col_b;
    fixed_t sky_r, sky_g, sky_b;
    fixed_t fog_val;
    fixed_t rd_len_sq, nor_len_sq;
    fixed_t recip_val;

    // ---- 状態 ---------------------------------------------------------
    typedef enum logic [5:0] {
        S_IDLE, S_RDLEN_GO, S_RDLEN_WAIT, S_RDRECIP_GO, S_RDRECIP_WAIT, S_RD_FIN,
        S_MARCH_GO, S_MARCH_WAIT, S_MARCH_EVAL,
        S_NORM_GO, S_NORM_WAIT, S_NORM_EVAL,
        S_NLEN_GO, S_NLEN_WAIT, S_NRECIP_GO, S_NRECIP_WAIT, S_NOR_FIN,
        S_SHAD_GO, S_SHAD_WAIT, S_SHAD_EVAL,
        S_LIGHT, S_LIGHT2, S_FOG1, S_FOG2,
        S_GAMMA_R_GO, S_GAMMA_R_WAIT, S_GAMMA_G_GO, S_GAMMA_G_WAIT,
        S_GAMMA_B_GO, S_GAMMA_B_WAIT,
        S_OUTPUT
    } state_t;
    state_t state;

    fixed_t march_pos_x, march_pos_y, march_pos_z;
    always_comb begin
        march_pos_x = fmul(rd_x, t_reg);
        march_pos_y = CAM_Y + fmul(rd_y, t_reg);
        march_pos_z = ro_z + fmul(rd_z, t_reg);
    end

    fixed_t dot_nl;
    always_comb dot_nl = fmul(nor_x, LIGHT_X) + fmul(nor_y, LIGHT_Y) + fmul(nor_z, LIGHT_Z);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; busy <= 1'b0; done <= 1'b0; rgb565 <= '0;
            map_start <= 1'b0; sqrt_start <= 1'b0; div_start <= 1'b0;
        end else begin
            done      <= 1'b0;
            map_start <= 1'b0;
            sqrt_start<= 1'b0;
            div_start <= 1'b0;

            unique case (state)
            // ---------------------------------------------------- レイ生成
            S_IDLE: begin
                if (start) begin
                    ro_z   <= -time_in;
                    sqrt_x <= fmul(qx_in,qx_in) + fmul(qy_in,qy_in) + ONE;
                    sqrt_start <= 1'b1;
                    busy   <= 1'b1;
                    state  <= S_RDLEN_WAIT;
                end
            end
            S_RDLEN_WAIT: begin
                if (sqrt_done) begin
                    div_a <= ONE; div_b <= sqrt_result; div_start <= 1'b1;
                    state <= S_RDRECIP_WAIT;
                end
            end
            S_RDRECIP_WAIT: begin
                if (div_done) begin
                    rd_x  <= fmul(qx_in, div_q);
                    rd_y  <= fmul(qy_in, div_q);
                    rd_z  <= fmul(-ONE, div_q);
                    state <= S_RD_FIN;
                end
            end
            S_RD_FIN: begin
                // sky color = (0.7,0.8,1.0) * (1 - 0.5*rd.y)
                sky_r <= fmul(SKY_R, ONE - fmul(HALF, fmul(qy_in, div_q)));
                sky_g <= fmul(SKY_G, ONE - fmul(HALF, fmul(qy_in, div_q)));
                sky_b <= fmul(SKY_B, ONE - fmul(HALF, fmul(qy_in, div_q)));
                t_reg <= ZERO;
                march_cnt <= '0;
                hit   <= 1'b0;
                state <= S_MARCH_GO;
            end

            // ---------------------------------------------------- 地形マーチ
            S_MARCH_GO: begin
                map_px <= march_pos_x; map_py <= march_pos_y; map_pz <= march_pos_z;
                map_start <= 1'b1;
                state <= S_MARCH_WAIT;
            end
            S_MARCH_WAIT: if (map_done) begin
                h_reg <= map_h;
                state <= S_MARCH_EVAL;
            end
            S_MARCH_EVAL: begin
                if (h_reg < HIT_EPS || t_reg > TMAX) begin
                    hit   <= (h_reg < HIT_EPS);
                    hit_x <= march_pos_x; hit_y <= march_pos_y; hit_z <= march_pos_z;
                    if (h_reg < HIT_EPS) begin
                        axis_cnt <= 2'd0; phase_plus <= 1'b1;
                        state <= S_NORM_GO;
                    end else begin
                        state <= S_GAMMA_R_GO; // ミス: sky色のままガンマへ
                        col_r <= sky_r; col_g <= sky_g; col_b <= sky_b;
                    end
                end else if (march_cnt == MARCH_STEPS-1) begin
                    // ステップ上限に達した(未ヒット扱い)
                    col_r <= sky_r; col_g <= sky_g; col_b <= sky_b;
                    state <= S_GAMMA_R_GO;
                end else begin
                    t_reg     <= t_reg + fmul(h_reg, HALF);
                    march_cnt <= march_cnt + 1'b1;
                    state     <= S_MARCH_GO;
                end
            end

            // ---------------------------------------------------- 法線
            S_NORM_GO: begin
                unique case (axis_cnt)
                    2'd0: begin
                        map_px <= phase_plus ? hit_x+EPS : hit_x-EPS;
                        map_py <= hit_y; map_pz <= hit_z;
                    end
                    2'd1: begin
                        map_px <= hit_x;
                        map_py <= phase_plus ? hit_y+EPS : hit_y-EPS;
                        map_pz <= hit_z;
                    end
                    default: begin
                        map_px <= hit_x; map_py <= hit_y;
                        map_pz <= phase_plus ? hit_z+EPS : hit_z-EPS;
                    end
                endcase
                map_start <= 1'b1;
                state <= S_NORM_WAIT;
            end
            S_NORM_WAIT: if (map_done) begin
                if (phase_plus) h_plus <= map_h;
                state <= S_NORM_EVAL;
            end
            S_NORM_EVAL: begin
                if (phase_plus) begin
                    phase_plus <= 1'b0;
                    state <= S_NORM_GO;
                end else begin
                    unique case (axis_cnt)
                        2'd0: nacc_x <= h_plus - map_h;
                        2'd1: nacc_y <= h_plus - map_h;
                        default: nacc_z <= h_plus - map_h;
                    endcase
                    if (axis_cnt == 2'd2) begin
                        state <= S_NLEN_GO;
                    end else begin
                        axis_cnt   <= axis_cnt + 1'b1;
                        phase_plus <= 1'b1;
                        state      <= S_NORM_GO;
                    end
                end
            end
            S_NLEN_GO: begin
                sqrt_x <= fmul(nacc_x,nacc_x) + fmul(nacc_y,nacc_y) + fmul(nacc_z,nacc_z);
                sqrt_start <= 1'b1;
                state <= S_NLEN_WAIT;
            end
            S_NLEN_WAIT: if (sqrt_done) begin
                div_a <= ONE; div_b <= (sqrt_result == 0) ? ONE : sqrt_result;
                div_start <= 1'b1;
                state <= S_NRECIP_WAIT;
            end
            S_NRECIP_WAIT: if (div_done) begin
                nor_x <= fmul(nacc_x, div_q);
                nor_y <= fmul(nacc_y, div_q);
                nor_z <= fmul(nacc_z, div_q);
                state <= S_NOR_FIN;
            end
            S_NOR_FIN: begin
                // シャドウレイ原点 = hit_pos + nor*0.1
                sro_x <= hit_x + fmul(nor_x, SHADOW_T0);
                sro_y <= hit_y + fmul(nor_y, SHADOW_T0);
                sro_z <= hit_z + fmul(nor_z, SHADOW_T0);
                ts_reg    <= SHADOW_T0;
                sres_reg  <= ONE;
                shadow_cnt <= '0;
                state <= S_SHAD_GO;
            end

            // ---------------------------------------------------- ソフトシャドウ
            S_SHAD_GO: begin
                map_px <= sro_x + fmul(ts_reg, LIGHT_X);
                map_py <= sro_y + fmul(ts_reg, LIGHT_Y);
                map_pz <= sro_z + fmul(ts_reg, LIGHT_Z);
                map_start <= 1'b1;
                state <= S_SHAD_WAIT;
            end
            S_SHAD_WAIT: if (map_done) begin
                logic signed [2*WIDTH-1:0] h164_wide;
                h_reg <= map_h;
                h164_wide = fmax(map_h, ZERO) * 164;   // 164.0はQ8.16に収まらないため整数乗算+飽和で計算
                div_a <= sat_from_wide(h164_wide);
                div_b <= ts_reg;
                div_start <= 1'b1;
                state <= S_SHAD_EVAL;
            end
            S_SHAD_EVAL: if (div_done) begin
                sres_reg <= fmin(sres_reg, div_q);
                if (fmin(sres_reg, div_q) < SHADOW_RES_EPS || shadow_cnt == SHADOW_STEPS-1) begin
                    state <= S_LIGHT;
                end else begin
                    ts_reg     <= ts_reg + fmul(h_reg, HALF);
                    shadow_cnt <= shadow_cnt + 1'b1;
                    state      <= S_SHAD_GO;
                end
            end

            // ---------------------------------------------------- ライティング
            S_LIGHT: begin
                dif_reg <= fmax(ZERO, fmin(ONE, dot_nl));
                state   <= S_FOG1;
            end
            S_FOG1: begin
                // lig = LCOL*dif*sha + AMB*nor.y*2.0
                lig_r <= fmul(fmul(LCOL_R, dif_reg), sres_reg) + fmul(fmul(AMB_R, nor_y), TWO);
                lig_g <= fmul(fmul(LCOL_G, dif_reg), sres_reg) + fmul(fmul(AMB_G, nor_y), TWO);
                lig_b <= fmul(fmul(LCOL_B, dif_reg), sres_reg) + fmul(fmul(AMB_B, nor_y), TWO);
                // smoothstep(0.7,0.9,nor.y)
                sm_reg <= fclamp(fmul(nor_y - SS_E0, SMOOTH_RECIP), ZERO, ONE);
                state  <= S_LIGHT2;
            end
            S_LIGHT2: begin
                // mate = mix(MATE0, MATE1, smoothstep(...)) , t*t*(3-2t)
                fixed_t sm2, mate_rr, mate_gg, mate_bb, ycalc, fog_r_pre, fog_g_pre, fog_b_pre;
                sm2 = fmul(fmul(sm_reg, sm_reg), THREE - fmul(TWO, sm_reg));
                mate_rr = MATE0_R + fmul(sm2, MATE1_R - MATE0_R);
                mate_gg = MATE0_G + fmul(sm2, MATE1_G - MATE0_G);
                mate_bb = MATE0_B + fmul(sm2, MATE1_B - MATE0_B);
                col_r <= fmul(lig_r, mate_rr);
                col_g <= fmul(lig_g, mate_gg);
                col_b <= fmul(lig_b, mate_bb);
                ycalc = fmul(fmul(K0_002, t_reg), t_reg);
                fog_val <= exp_neg_fx(ycalc);
                state <= S_FOG2;
            end
            S_FOG2: begin
                col_r <= fmul(col_r, fog_val) + fmul(ONE-fog_val, FOG_R);
                col_g <= fmul(col_g, fog_val) + fmul(ONE-fog_val, FOG_G);
                col_b <= fmul(col_b, fog_val) + fmul(ONE-fog_val, FOG_B);
                state <= S_GAMMA_R_GO;
            end

            // ---------------------------------------------------- ガンマ(sqrt)
            S_GAMMA_R_GO: begin
                sqrt_x <= fmax(col_r, ZERO); sqrt_start <= 1'b1; state <= S_GAMMA_R_WAIT;
            end
            S_GAMMA_R_WAIT: if (sqrt_done) begin
                col_r <= sqrt_result; state <= S_GAMMA_G_GO;
            end
            S_GAMMA_G_GO: begin
                sqrt_x <= fmax(col_g, ZERO); sqrt_start <= 1'b1; state <= S_GAMMA_G_WAIT;
            end
            S_GAMMA_G_WAIT: if (sqrt_done) begin
                col_g <= sqrt_result; state <= S_GAMMA_B_GO;
            end
            S_GAMMA_B_GO: begin
                sqrt_x <= fmax(col_b, ZERO); sqrt_start <= 1'b1; state <= S_GAMMA_B_WAIT;
            end
            S_GAMMA_B_WAIT: if (sqrt_done) begin
                col_b <= sqrt_result; state <= S_OUTPUT;
            end

            // ---------------------------------------------------- RGB565出力
            S_OUTPUT: begin
                fixed_t rc, gc, bc;
                logic [4:0] r5; logic [5:0] g6; logic [4:0] b5;
                rc = fclamp(col_r, ZERO, ONE);
                gc = fclamp(col_g, ZERO, ONE);
                bc = fclamp(col_b, ZERO, ONE);
                r5 = fmul(rc, K31)  >>> FRAC;
                g6 = fmul(gc, K63)  >>> FRAC;
                b5 = fmul(bc, K31)  >>> FRAC;
                rgb565 <= {r5, g6, b5};
                busy  <= 1'b0;
                done  <= 1'b1;
                state <= S_IDLE;
            end

            default: state <= S_IDLE;
            endcase
        end
    end
endmodule
