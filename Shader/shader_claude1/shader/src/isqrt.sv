// =====================================================================
// isqrt_fx : 固定小数点(Q12.20)の非負数 sqrt を求めるFSM
//   桁ごとの復元法(restoring digit-by-digit)による整数平方根を使用。
//   sqrt(x_real) の Q12.20表現を得るため、内部では (x_fixed << FRAC) の
//   64bit整数平方根(32bit結果)を32サイクルかけて計算する。
//   x<0 の場合は 0 を返す(GLSLのsqrtも未定義動作だが、ここでは安全側に倒す)。
// =====================================================================
module isqrt_fx
    import rm_pkg::*;
#(
    parameter int NBITS = 32     // 出力ビット幅 (root)。入力radicandは2*NBITSビットとして扱う
)(
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  fixed_t        x_in,     // Q12.20, sqrt(x_in)を求める
    output logic          busy,
    output logic          done,     // 1クロックパルス
    output fixed_t         result
);
    logic [2*NBITS-1:0] radicand;
    logic [NBITS-1:0]   q;
    logic [NBITS+1:0]   remainder;  // 桁あふれ防止のため+2bit
    logic [$clog2(NBITS+1)-1:0] i_cnt;

    typedef enum logic [1:0] {S_IDLE, S_LOAD, S_ITER, S_DONE} state_t;
    state_t state;

    logic [1:0] two_bits;
    logic [NBITS+1:0] rem_shifted, t_val;

    always_comb begin
        two_bits    = radicand[2*i_cnt +: 2];
        rem_shifted = {remainder[NBITS-1:0], two_bits};
        t_val       = {q, 2'b01};
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            busy      <= 1'b0;
            done      <= 1'b0;
            radicand  <= '0;
            q         <= '0;
            remainder <= '0;
            i_cnt     <= '0;
            result    <= '0;
        end else begin
            done <= 1'b0;
            unique case (state)
                S_IDLE: begin
                    if (start) begin
                        // 負数は0とみなす。x_in(Q12.20) << FRAC で 2*NBITS幅の整数被開平数を作る
                        radicand <= (x_in[WIDTH-1]) ? '0 : ({{(2*NBITS-WIDTH){1'b0}}, x_in} <<< FRAC);
                        q         <= '0;
                        remainder <= '0;
                        i_cnt     <= NBITS-1;
                        busy      <= 1'b1;
                        state     <= S_ITER;
                    end
                end

                S_ITER: begin
                    if (rem_shifted >= t_val) begin
                        remainder <= rem_shifted - t_val;
                        q         <= {q[NBITS-2:0], 1'b1};
                    end else begin
                        remainder <= rem_shifted;
                        q         <= {q[NBITS-2:0], 1'b0};
                    end
                    if (i_cnt == 0) begin
                        state <= S_DONE;
                    end else begin
                        i_cnt <= i_cnt - 1'b1;
                    end
                end

                S_DONE: begin
                    result <= fixed_t'(q);
                    busy   <= 1'b0;
                    done   <= 1'b1;
                    state  <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
