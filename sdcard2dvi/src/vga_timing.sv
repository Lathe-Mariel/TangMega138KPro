// 1280x720@60Hz タイミングジェネレータ (74.25MHz)
module vga_timing #(
    parameter H_ACTIVE = 1280,
    parameter H_FP     = 110,
    parameter H_SYNC   = 40,
    parameter H_BP     = 220,
    parameter V_ACTIVE = 720,
    parameter V_FP     = 5,
    parameter V_SYNC   = 5,
    parameter V_BP     = 20
) (
    input  logic       clk,
    input  logic       rst,
    output logic       hsync,
    output logic       vsync,
    output logic       de,
    output logic [11:0] hcount,
    output logic [11:0] vcount
);

    localparam H_TOTAL = H_ACTIVE + H_FP + H_SYNC + H_BP;  // 1650
    localparam V_TOTAL = V_ACTIVE + V_FP + V_SYNC + V_BP;  // 750

    logic [11:0] h_cnt;
    logic [11:0] v_cnt;

    always_ff @(posedge clk) begin
        if (rst) begin
            h_cnt <= 12'd0;
            v_cnt <= 12'd0;
        end else begin
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt <= 12'd0;
                if (v_cnt == V_TOTAL - 1)
                    v_cnt <= 12'd0;
                else
                    v_cnt <= v_cnt + 1'b1;
            end else begin
                h_cnt <= h_cnt + 1'b1;
            end
        end
    end

    // アクティブLowの同期信号
    assign hsync = ~(h_cnt >= H_ACTIVE + H_FP && h_cnt < H_ACTIVE + H_FP + H_SYNC);
    assign vsync = ~(v_cnt >= V_ACTIVE + V_FP && v_cnt < V_ACTIVE + V_FP + V_SYNC);

    // データ有効期間
    assign de = (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);

    assign hcount = h_cnt;
    assign vcount = v_cnt;

endmodule
