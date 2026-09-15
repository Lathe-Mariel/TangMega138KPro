// =====================================================================
// fixed_div : Q12.20 固定小数点の符号付き除算 (a/b) をFSMで計算
//   絶対値同士を2進復元法(restoring division)で (WIDTH+FRAC)サイクルかけ
//   て割り、最後に符号を復元する。b==0 の場合は div_by_zero を立てて 0 を返す。
//   quotient = floor((|a| << FRAC) / |b|) の下位WIDTHビットをQ12.20として返す
//   (a/bの実数値がQ12.20で表現できる範囲であることを前提とする)。
// =====================================================================
module fixed_div
    import rm_pkg::*;
#(
    parameter int NBITS = WIDTH + FRAC   // 52
)(
    input  logic  clk,
    input  logic  rst_n,
    input  logic  start,
    input  fixed_t a,          // 被除数
    input  fixed_t b,          // 除数
    output logic   busy,
    output logic   done,       // 1クロックパルス
    output fixed_t  quotient,
    output logic    div_by_zero
);
    typedef enum logic [1:0] {S_IDLE, S_ITER, S_DONE} state_t;
    state_t state;

    logic sign_a, sign_b;
    logic [NBITS-1:0] divd;           // 被除数(|a| << FRAC)を左シフトしていくレジスタ
    logic [WIDTH-1:0] divisor;        // |b|
    logic [WIDTH-1:0] remainder;      // |b| <= 32bitなので余りも32bitで足りる
    logic [NBITS-1:0] quot_r;
    logic [$clog2(NBITS+1)-1:0] i_cnt;

    logic [WIDTH-1:0] rem_shift;

    // 変数ビットインデックスは避け、divdを毎サイクル左シフトしてMSBを使う
    always_comb begin
        rem_shift = {remainder[WIDTH-2:0], divd[NBITS-1]};
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            busy         <= 1'b0;
            done         <= 1'b0;
            quotient     <= '0;
            div_by_zero  <= 1'b0;
            divd         <= '0;
            divisor      <= '0;
            remainder    <= '0;
            quot_r       <= '0;
            i_cnt        <= '0;
            sign_a       <= 1'b0;
            sign_b       <= 1'b0;
        end else begin
            done <= 1'b0;
            unique case (state)
                S_IDLE: begin
                    if (start) begin
                        sign_a <= a[WIDTH-1];
                        sign_b <= b[WIDTH-1];
                        if (b == '0) begin
                            div_by_zero <= 1'b1;
                            quotient    <= '0;
                            done        <= 1'b1;
                        end else begin
                            div_by_zero  <= 1'b0;
                            divd         <= {(a[WIDTH-1] ? -a : a), {(FRAC){1'b0}}};
                            divisor      <= b[WIDTH-1] ? -b : b;
                            remainder    <= '0;
                            quot_r       <= '0;
                            i_cnt        <= NBITS-1;
                            busy         <= 1'b1;
                            state        <= S_ITER;
                        end
                    end
                end

                S_ITER: begin
                    divd <= divd <<< 1;
                    if (rem_shift >= divisor) begin
                        remainder <= rem_shift - divisor;
                        quot_r    <= {quot_r[NBITS-2:0], 1'b1};
                    end else begin
                        remainder <= rem_shift;
                        quot_r    <= {quot_r[NBITS-2:0], 1'b0};
                    end
                    if (i_cnt == 0) state <= S_DONE;
                    else i_cnt <= i_cnt - 1'b1;
                end

                S_DONE: begin
                    quotient <= (sign_a ^ sign_b) ? -(fixed_t'(quot_r[WIDTH-1:0]))
                                                   :  fixed_t'(quot_r[WIDTH-1:0]);
                    busy     <= 1'b0;
                    done     <= 1'b1;
                    state    <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
