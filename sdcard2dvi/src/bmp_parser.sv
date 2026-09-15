// ============================================================================
//  bmp_parser.sv
//  SDカードから読み出したバイトストリームから BMP (無圧縮 24bit) を解釈する
//
//  【機能】
//   ・BITMAPFILEHEADER (14byte) と BITMAPINFOHEADER (40byte) をパース
//   ・画像の幅・高さ・ビット深度・データオフセットを抽出
//   ・画像データ部を 24bit (R,G,B) ピクセルとして出力する
//
//  【入出力】
//   入力  in_data      : SDリーダからのバイト (data)
//   入力  in_valid     : SDリーダからの有効信号 (data_valid)
//   出力  px_x         : 出力ピクセルの X座標 (0..WIDTH-1)
//   出力  px_y         : 出力ピクセルの Y座標 (0..HEIGHT-1)
//   出力  px_r/g/b     : ピクセル色 (各8bit)
//   出力  px_valid     : ピクセル有効 (1クロックパルス)
//   出力  img_ready    : ヘッダパース完了 (幅/高さ確定)
//   出力  width        : 画像の幅
//   出力  height       : 画像の高さ
//
//  ※ BMP はボトムアップ (下の行から格納) なので、Y座標は反転して出力する。
//  ※ 各行は4バイト境界にパディングされる (row_padding)。
// ============================================================================
module bmp_parser (
    input  logic        clk,
    input  logic        rst_n,

    // 入力バイトストリーム
    input  logic [7:0]  in_data,
    input  logic        in_valid,

    // 出力ピクセル
    output logic [15:0] px_x,
    output logic [15:0] px_y,
    output logic [7:0]  px_r,
    output logic [7:0]  px_g,
    output logic [7:0]  px_b,
    output logic        px_valid,

    // ヘッダ情報
    output logic        img_ready,
    output logic [15:0] width,
    output logic [15:0] height
);

    // ========================================================================
    // バイトカウンタ (ストリーム先頭からの位置)
    // ========================================================================
    logic [31:0] byte_pos;   // 0-based

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            byte_pos <= 32'd0;
        end else if (in_valid) begin
            byte_pos <= byte_pos + 32'd1;
        end
    end

    // ========================================================================
    // ヘッダ情報レジスタ
    // ========================================================================
    // BITMAPFILEHEADER (14byte)
    //   0..1   : 'BM' (0x42 0x4D)
    //   2..5   : ファイルサイズ
    //   6..9   : 予約
    //   10..13 : データオフセット (LE)
    // BITMAPINFOHEADER (40byte, オフセット14から)
    //   14..17 : ヘッダサイズ (40)
    //   18..21 : 幅 (LE)
    //   22..25 : 高さ (LE)
    //   26..27 : プレーン数 (1)
    //   28..29 : ビット深度 (24)
    //   30..33 : 圧縮 (0=無圧縮)
    //   34..37 : 画像データサイズ
    //   38..53 : 解像度・パレットなど
    logic [31:0] data_offset;   // 画像データ先頭オフセット
    logic [31:0] img_width;     // 幅
    logic [31:0] img_height;    // 高さ
    logic [15:0] bit_depth;     // ビット深度

    // リトルエンディアンのバイトを順次受けて32bitに組み立てる
    logic [31:0] offset_sh;
    logic [31:0] width_sh;
    logic [31:0] height_sh;
    logic [15:0] depth_sh;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            offset_sh <= 32'd0;
            width_sh  <= 32'd0;
            height_sh <= 32'd0;
            depth_sh  <= 16'd0;
        end else if (in_valid) begin
            case (byte_pos)
                32'd10: offset_sh <= {in_data, 24'd0};
                32'd11: offset_sh <= {in_data, offset_sh[31:8]};
                32'd12: offset_sh <= {in_data, offset_sh[31:8]};
                32'd13: begin
                    offset_sh <= {in_data, offset_sh[31:8]};
                    data_offset <= {in_data, offset_sh[31:8]};
                end

                32'd18: width_sh <= {in_data, 24'd0};
                32'd19: width_sh <= {in_data, width_sh[31:8]};
                32'd20: width_sh <= {in_data, width_sh[31:8]};
                32'd21: begin
                    width_sh <= {in_data, width_sh[31:8]};
                    img_width <= {in_data, width_sh[31:8]};
                end

                32'd22: height_sh <= {in_data, 24'd0};
                32'd23: height_sh <= {in_data, height_sh[31:8]};
                32'd24: height_sh <= {in_data, height_sh[31:8]};
                32'd25: begin
                    height_sh <= {in_data, height_sh[31:8]};
                    img_height <= {in_data, height_sh[31:8]};
                end

                32'd28: depth_sh <= {in_data, 8'd0};
                32'd29: begin
                    depth_sh <= {in_data, depth_sh[15:8]};
                    bit_depth <= {in_data, depth_sh[15:8]};
                end

                default: ; // 何もしない
            endcase
        end
    end

    // ヘッダパース完了 (データオフセットに到達)
    assign img_ready = (byte_pos == data_offset) && (data_offset != 32'd0);
    assign width     = img_width[15:0];
    assign height    = img_height[15:0];

    // ========================================================================
    // ピクセルデータ抽出
    // ========================================================================
    // 行のバイト数 = 幅 * 3 (24bit) → 4バイト境界に丸める
    logic [31:0] row_bytes_raw;
    logic [31:0] row_bytes;     // パディング込みの行バイト数
    logic [15:0] row_pad;

    assign row_bytes_raw = img_width * 3;
    assign row_bytes     = (row_bytes_raw + 3) & 32'hFFFFFFFC;
    assign row_pad       = row_bytes[15:0] - row_bytes_raw[15:0];

    // 画像データ内での位置 (データオフセットからの相対バイト)
    logic [31:0] rel_pos;
    logic [31:0] rel_pos_next;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rel_pos <= 32'd0;
        else if (in_valid && byte_pos >= data_offset)
            rel_pos <= rel_pos + 32'd1;
        else if (byte_pos < data_offset)
            rel_pos <= 32'd0;
    end

    // 現在のピクセル内バイト位相 (0,1,2 = B,G,R)
    logic [1:0] px_phase;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            px_phase <= 2'd0;
        else if (in_valid && byte_pos >= data_offset)
            px_phase <= (px_phase == 2'd2) ? 2'd0 : px_phase + 2'd1;
    end

    // 行内 X と 行番号 Y
    logic [15:0] x_cnt;
    logic [15:0] y_cnt;     // ボトムアップ (下から)

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt <= 16'd0;
            y_cnt <= 16'd0;
        end else if (in_valid && byte_pos >= data_offset) begin
            if (px_phase == 2'd2) begin
                // 1ピクセル完了
                if (x_cnt == img_width[15:0] - 1) begin
                    x_cnt <= 16'd0;
                    y_cnt <= y_cnt + 16'd1;
                end else begin
                    x_cnt <= x_cnt + 16'd1;
                end
            end
        end
    end

    // ピクセル色の組み立て (B → G → R の順)
    logic [7:0] px_blue, px_green, px_red;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            px_blue  <= 8'd0;
            px_green <= 8'd0;
            px_red   <= 8'd0;
        end else if (in_valid && byte_pos >= data_offset) begin
            case (px_phase)
                2'd0: px_blue  <= in_data;
                2'd1: px_green <= in_data;
                2'd2: px_red   <= in_data;
            endcase
        end
    end

    // ピクセル出力 (Y座標をトップアップに反転)
    assign px_x = x_cnt;
    assign px_y = img_height[15:0] - 1 - y_cnt;
    assign px_r = px_red;
    assign px_g = px_green;
    assign px_b = px_blue;

    // px_valid: ピクセルの3バイト目 (R) が揃った時
    logic px_3rd_byte;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            px_3rd_byte <= 1'b0;
        else
            px_3rd_byte <= in_valid && (byte_pos >= data_offset) && (px_phase == 2'd2);
    end
    assign px_valid = px_3rd_byte;

endmodule
