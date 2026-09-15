// TMDSエンコーダ (8bit → 10bit)
module tmds_encoder (
    input  logic       clk,
    input  logic       rst,
    input  logic [7:0] data_in,
    input  logic [1:0] control_in,   // {c1, c0}
    input  logic       blank_in,     // 1=ブランキング期間
    output logic [9:0] tmds_out
);

    logic [8:0] q_m;
    logic [3:0] n1_data;
    logic [3:0] n1_q_m;
    logic signed [5:0] n1_q_m_s;
    logic signed [5:0] cnt;

    assign n1_q_m_s = {2'b00, n1_q_m};  // 0〜8

    // 入力データの1の数を数える
    always_comb begin
        n1_data = 4'd0;
        for (int i = 0; i < 8; i++)
            n1_data = n1_data + data_in[i];
    end

    // ステージ1: 遷移最小化
    always_comb begin
        if (n1_data > 4'd4 || (n1_data == 4'd4 && data_in[0] == 1'b0)) begin
            q_m[0] = data_in[0];
            for (int i = 1; i < 8; i++)
                q_m[i] = q_m[i-1] ^ ~data_in[i];
            q_m[8] = 1'b0;
        end else begin
            q_m[0] = data_in[0];
            for (int i = 1; i < 8; i++)
                q_m[i] = q_m[i-1] ^ data_in[i];
            q_m[8] = 1'b1;
        end
    end

    // q_m[7:0] の1の数を数える
    always_comb begin
        n1_q_m = 4'd0;
        for (int i = 0; i < 8; i++)
            n1_q_m = n1_q_m + q_m[i];
    end

    // ステージ2: DCバランス調整
    always_ff @(posedge clk) begin
        if (rst) begin
            cnt <= 6'sd0;
            tmds_out <= 10'd0;
        end else if (blank_in) begin
            // 制御コード (DVI仕様)
            case (control_in)
                2'b00:   tmds_out <= 10'b1101010100;
                2'b01:   tmds_out <= 10'b0101010100;
                2'b10:   tmds_out <= 10'b0010101011;
                default: tmds_out <= 10'b1010101011;
            endcase
            cnt <= 6'sd0;
        end else begin
            if (cnt == 6'sd0 || n1_q_m == 4'd4) begin
                tmds_out[9] <= ~q_m[8];
                tmds_out[8] <= q_m[8];
                tmds_out[7:0] <= q_m[7:0];
                cnt <= cnt + (~q_m[8] ? (6'sd8 - 2*n1_q_m_s) : (2*n1_q_m_s - 6'sd8));
            end else if ((cnt > 6'sd0 && n1_q_m > 4'd4) || (cnt < 6'sd0 && n1_q_m < 4'd4)) begin
                tmds_out[9] <= 1'b1;
                tmds_out[8] <= q_m[8];
                tmds_out[7:0] <= ~q_m[7:0];
                cnt <= cnt + (2*q_m[8] + 2*n1_q_m_s - 6'sd8);
            end else begin
                tmds_out[9] <= 1'b0;
                tmds_out[8] <= q_m[8];
                tmds_out[7:0] <= q_m[7:0];
                cnt <= cnt + (6'sd8 - 2*n1_q_m_s - 2*~q_m[8]);
            end
        end
    end

endmodule