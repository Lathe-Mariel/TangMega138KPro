// =====================================================================
// map_core : GLSLの map(vec3 pos) を移植したFSM
//   h = 0; s = 0.5; q = pos.xz*0.5;
//   for(i=0;i<NUM_OCTAVES;i++){ h += s*cosNoise(q); s*=0.5; q = m2*q*1.7; }
//   h *= 3.0;
//   return pos.y - h;
//
//   1オクターブ=1クロックのFSMで実装 (initialブロック不使用、同期リセット)。
// =====================================================================
module map_core
    import rm_pkg::*;
#(
    parameter int NUM_OCTAVES = 10
)(
    input  logic          clk,
    input  logic          rst_n,
    input  logic          start,      // posが有効、計算開始
    input  fixed_t         pos_x,
    input  fixed_t         pos_y,
    input  fixed_t         pos_z,
    output logic           busy,
    output logic           done,       // 1クロックパルス
    output fixed_t         result_h
);
    typedef enum logic [1:0] {S_IDLE, S_ITER, S_FINISH} state_t;
    state_t state;

    fixed_t qx, qy, h_acc, s_reg, pos_y_r;
    logic [$clog2(NUM_OCTAVES+1)-1:0] oct_cnt;

    fixed_t noise_val, new_qx, new_qy;

    always_comb begin
        noise_val = cos_noise(qx, qy);
        new_qx    = fmul(fmul(M2_00, qx) + fmul(M2_01, qy), SCALE_1_7);
        new_qy    = fmul(fmul(M2_10, qx) + fmul(M2_11, qy), SCALE_1_7);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            busy     <= 1'b0;
            done     <= 1'b0;
            qx       <= '0;
            qy       <= '0;
            h_acc    <= '0;
            s_reg    <= '0;
            oct_cnt  <= '0;
            pos_y_r  <= '0;
            result_h <= '0;
        end else begin
            done <= 1'b0;
            unique case (state)
                S_IDLE: begin
                    if (start) begin
                        qx      <= fmul(pos_x, HALF);   // q = pos.xz * 0.5
                        qy      <= fmul(pos_z, HALF);
                        h_acc   <= '0;
                        s_reg   <= HALF;                // s = 0.5
                        oct_cnt <= '0;
                        pos_y_r <= pos_y;
                        busy    <= 1'b1;
                        state   <= S_ITER;
                    end
                end

                S_ITER: begin
                    h_acc <= h_acc + fmul(s_reg, noise_val);
                    s_reg <= s_reg >>> 1;                // s *= 0.5
                    qx    <= new_qx;                     // q = m2*q*1.7
                    qy    <= new_qy;
                    if (oct_cnt == NUM_OCTAVES-1) begin
                        state <= S_FINISH;
                    end else begin
                        oct_cnt <= oct_cnt + 1'b1;
                    end
                end

                S_FINISH: begin
                    // h *= 3.0 は次サイクルで確定したh_accを使う必要があるため
                    // 1サイクル遅延させてから計算する
                    result_h <= pos_y_r - fmul(h_acc, THREE);
                    busy     <= 1'b0;
                    done     <= 1'b1;
                    state    <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
