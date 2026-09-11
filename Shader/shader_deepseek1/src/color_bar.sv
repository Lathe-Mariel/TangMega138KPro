// 7色カラーバー生成 (白・黄・シアン・緑・マゼンタ・赤・青)
module color_bar (
    input  logic [11:0] hcount,
    output logic [7:0] r,
    output logic [7:0] g,
    output logic [7:0] b
);

    logic [2:0] bar_index;

    // 1280ピクセルを7分割: 183×6 + 182 = 1280
    always_comb begin
        if      (hcount < 183) bar_index = 3'd0;  // 白
        else if (hcount < 366) bar_index = 3'd1;  // 黄
        else if (hcount < 549) bar_index = 3'd2;  // シアン
        else if (hcount < 732) bar_index = 3'd3;  // 緑
        else if (hcount < 915) bar_index = 3'd4;  // マゼンタ
        else if (hcount < 1098) bar_index = 3'd5; // 赤
        else                   bar_index = 3'd6;  // 青
    end

    always_comb begin
        case (bar_index)
            3'd0: begin r = 8'hFF; g = 8'hFF; b = 8'hFF; end  // 白
            3'd1: begin r = 8'hFF; g = 8'hFF; b = 8'h00; end  // 黄
            3'd2: begin r = 8'h00; g = 8'hFF; b = 8'hFF; end  // シアン
            3'd3: begin r = 8'h00; g = 8'hFF; b = 8'h00; end  // 緑
            3'd4: begin r = 8'hFF; g = 8'h00; b = 8'hFF; end  // マゼンタ
            3'd5: begin r = 8'hFF; g = 8'h00; b = 8'h00; end  // 赤
            3'd6: begin r = 8'h00; g = 8'h00; b = 8'hFF; end  // 青
            default: begin r = 8'h00; g = 8'h00; b = 8'h00; end
        endcase
    end

endmodule