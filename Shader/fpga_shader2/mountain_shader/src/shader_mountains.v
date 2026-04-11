// ============================================================
// shader_mountains.v
// Mountains + Sky flight shader for FPGA DVI output
//
// 実装方針:
//   - initial ブロック不使用 (LUTはcase文functionで実装)
//   - $signed 不使用 (符号付き演算はすべて符号なし2の補数で記述)
//
// パイプライン: 7 段レジスタ → 7サイクルレイテンシ
//
//   Stage 0  : 座標正規化 (hcount/vcount → nx/ny, 2の補数)
//   Stage 1  : fBm ノイズ評価 → 地形高さ th_raw
//   Stage 2  : 空/地形 判定，height_diff 計算
//   Stage 3a : LUT読み出し (sin/noise)，比較，雪判定
//   Stage 3b : 乗算・加算 (霧ブレンド，太陽グロウ)
//   Stage 4  : MUX (sky / terrain 切り替え)
//   Stage 5  : 出力レジスタ (DEブランク)
//
// $signed 除去の変換方針:
//   符号付き値はすべて「符号なしレジスタ + MSBを符号ビットとして解釈」
//   で統一する。比較・差分は以下のルールで変換する:
//
//   ① 符号付き減算 (A - B, 結果負あり):
//        符号なし減算でそのまま計算。2の補数表現で等価。
//        負かどうかは結果の MSB で判定。
//
//   ② 符号付き比較 (A > B, A < 0 など):
//        A, B を同一ビット幅に揃えた上で
//        差分 D = A - B の MSB が 0 → A >= B (正)
//                              1 → A <  B (負)
//        "A < 0" は A の MSB で直接判定。
//
//   ③ 符号付き値の絶対値:
//        MSB=1 (負) なら ~val + 1、MSB=0 (正) なら val そのまま。
// ============================================================
module shader_mountains (
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] hcount,
    input  wire [10:0] vcount,
    input  wire        de,
    input  wire [23:0] frame_cnt,
    output reg  [ 7:0] r,
    output reg  [ 7:0] g,
    output reg  [ 7:0] b
);

// ════════════════════════════════════════════════════════════
// LUT functions (initial ブロック・$signed 不使用)
// ════════════════════════════════════════════════════════════
function [7:0] noise_lut_f;
    input [7:0] addr;
    case (addr)
        8'd0: noise_lut_f = 8'h00;
        8'd1: noise_lut_f = 8'hEA;
        8'd2: noise_lut_f = 8'hFF;
        8'd3: noise_lut_f = 8'h69;
        8'd4: noise_lut_f = 8'h11;
        8'd5: noise_lut_f = 8'h46;
        8'd6: noise_lut_f = 8'hC2;
        8'd7: noise_lut_f = 8'h7B;
        8'd8: noise_lut_f = 8'hB8;
        8'd9: noise_lut_f = 8'hF9;
        8'd10: noise_lut_f = 8'h34;
        8'd11: noise_lut_f = 8'h50;
        8'd12: noise_lut_f = 8'hFE;
        8'd13: noise_lut_f = 8'h46;
        8'd14: noise_lut_f = 8'h08;
        8'd15: noise_lut_f = 8'hC1;
        8'd16: noise_lut_f = 8'hBE;
        8'd17: noise_lut_f = 8'hDD;
        8'd18: noise_lut_f = 8'h32;
        8'd19: noise_lut_f = 8'hA8;
        8'd20: noise_lut_f = 8'hCD;
        8'd21: noise_lut_f = 8'h42;
        8'd22: noise_lut_f = 8'h13;
        8'd23: noise_lut_f = 8'hD5;
        8'd24: noise_lut_f = 8'hE0;
        8'd25: noise_lut_f = 8'h0B;
        8'd26: noise_lut_f = 8'hF7;
        8'd27: noise_lut_f = 8'h00;
        8'd28: noise_lut_f = 8'hA1;
        8'd29: noise_lut_f = 8'h33;
        8'd30: noise_lut_f = 8'h94;
        8'd31: noise_lut_f = 8'hE4;
        8'd32: noise_lut_f = 8'h8C;
        8'd33: noise_lut_f = 8'h8D;
        8'd34: noise_lut_f = 8'hE3;
        8'd35: noise_lut_f = 8'h05;
        8'd36: noise_lut_f = 8'hE2;
        8'd37: noise_lut_f = 8'hAF;
        8'd38: noise_lut_f = 8'hA3;
        8'd39: noise_lut_f = 8'h85;
        8'd40: noise_lut_f = 8'h58;
        8'd41: noise_lut_f = 8'h6C;
        8'd42: noise_lut_f = 8'h6D;
        8'd43: noise_lut_f = 8'hEF;
        8'd44: noise_lut_f = 8'h67;
        8'd45: noise_lut_f = 8'h90;
        8'd46: noise_lut_f = 8'h7A;
        8'd47: noise_lut_f = 8'h9C;
        8'd48: noise_lut_f = 8'hE7;
        8'd49: noise_lut_f = 8'hD4;
        8'd50: noise_lut_f = 8'h14;
        8'd51: noise_lut_f = 8'h6A;
        8'd52: noise_lut_f = 8'h0F;
        8'd53: noise_lut_f = 8'hDA;
        8'd54: noise_lut_f = 8'h12;
        8'd55: noise_lut_f = 8'h18;
        8'd56: noise_lut_f = 8'hF8;
        8'd57: noise_lut_f = 8'hDB;
        8'd58: noise_lut_f = 8'hE1;
        8'd59: noise_lut_f = 8'h7B;
        8'd60: noise_lut_f = 8'hC2;
        8'd61: noise_lut_f = 8'h59;
        8'd62: noise_lut_f = 8'h6F;
        8'd63: noise_lut_f = 8'hC3;
        8'd64: noise_lut_f = 8'h70;
        8'd65: noise_lut_f = 8'hE3;
        8'd66: noise_lut_f = 8'hDD;
        8'd67: noise_lut_f = 8'h18;
        8'd68: noise_lut_f = 8'hE4;
        8'd69: noise_lut_f = 8'h10;
        8'd70: noise_lut_f = 8'h42;
        8'd71: noise_lut_f = 8'h80;
        8'd72: noise_lut_f = 8'h5D;
        8'd73: noise_lut_f = 8'hE0;
        8'd74: noise_lut_f = 8'hC9;
        8'd75: noise_lut_f = 8'hC7;
        8'd76: noise_lut_f = 8'hE6;
        8'd77: noise_lut_f = 8'hCC;
        8'd78: noise_lut_f = 8'h51;
        8'd79: noise_lut_f = 8'h47;
        8'd80: noise_lut_f = 8'h9C;
        8'd81: noise_lut_f = 8'hFF;
        8'd82: noise_lut_f = 8'hF8;
        8'd83: noise_lut_f = 8'h47;
        8'd84: noise_lut_f = 8'hD8;
        8'd85: noise_lut_f = 8'hEE;
        8'd86: noise_lut_f = 8'hDF;
        8'd87: noise_lut_f = 8'hE2;
        8'd88: noise_lut_f = 8'h21;
        8'd89: noise_lut_f = 8'h8B;
        8'd90: noise_lut_f = 8'h25;
        8'd91: noise_lut_f = 8'h87;
        8'd92: noise_lut_f = 8'hE7;
        8'd93: noise_lut_f = 8'hAC;
        8'd94: noise_lut_f = 8'h1A;
        8'd95: noise_lut_f = 8'h24;
        8'd96: noise_lut_f = 8'h7E;
        8'd97: noise_lut_f = 8'hD3;
        8'd98: noise_lut_f = 8'h32;
        8'd99: noise_lut_f = 8'hA9;
        8'd100: noise_lut_f = 8'hAD;
        8'd101: noise_lut_f = 8'h00;
        8'd102: noise_lut_f = 8'h37;
        8'd103: noise_lut_f = 8'hA5;
        8'd104: noise_lut_f = 8'h7F;
        8'd105: noise_lut_f = 8'h36;
        8'd106: noise_lut_f = 8'hB7;
        8'd107: noise_lut_f = 8'h9E;
        8'd108: noise_lut_f = 8'hB3;
        8'd109: noise_lut_f = 8'hE3;
        8'd110: noise_lut_f = 8'h4E;
        8'd111: noise_lut_f = 8'hBB;
        8'd112: noise_lut_f = 8'h27;
        8'd113: noise_lut_f = 8'h82;
        8'd114: noise_lut_f = 8'h5F;
        8'd115: noise_lut_f = 8'h86;
        8'd116: noise_lut_f = 8'h2C;
        8'd117: noise_lut_f = 8'hAD;
        8'd118: noise_lut_f = 8'h01;
        8'd119: noise_lut_f = 8'h3D;
        8'd120: noise_lut_f = 8'hB6;
        8'd121: noise_lut_f = 8'h9B;
        8'd122: noise_lut_f = 8'hAB;
        8'd123: noise_lut_f = 8'h88;
        8'd124: noise_lut_f = 8'h5A;
        8'd125: noise_lut_f = 8'h6A;
        8'd126: noise_lut_f = 8'h36;
        8'd127: noise_lut_f = 8'h42;
        8'd128: noise_lut_f = 8'h6F;
        8'd129: noise_lut_f = 8'hCF;
        8'd130: noise_lut_f = 8'h5C;
        8'd131: noise_lut_f = 8'hB0;
        8'd132: noise_lut_f = 8'h9B;
        8'd133: noise_lut_f = 8'hAE;
        8'd134: noise_lut_f = 8'h26;
        8'd135: noise_lut_f = 8'hF9;
        8'd136: noise_lut_f = 8'h42;
        8'd137: noise_lut_f = 8'hC9;
        8'd138: noise_lut_f = 8'h3A;
        8'd139: noise_lut_f = 8'h22;
        8'd140: noise_lut_f = 8'h93;
        8'd141: noise_lut_f = 8'h4C;
        8'd142: noise_lut_f = 8'h59;
        8'd143: noise_lut_f = 8'h7E;
        8'd144: noise_lut_f = 8'h1F;
        8'd145: noise_lut_f = 8'hF3;
        8'd146: noise_lut_f = 8'h87;
        8'd147: noise_lut_f = 8'hA4;
        8'd148: noise_lut_f = 8'hFC;
        8'd149: noise_lut_f = 8'hAB;
        8'd150: noise_lut_f = 8'hCB;
        8'd151: noise_lut_f = 8'h82;
        8'd152: noise_lut_f = 8'hE8;
        8'd153: noise_lut_f = 8'h84;
        8'd154: noise_lut_f = 8'h93;
        8'd155: noise_lut_f = 8'h3E;
        8'd156: noise_lut_f = 8'hC2;
        8'd157: noise_lut_f = 8'h3E;
        8'd158: noise_lut_f = 8'hAD;
        8'd159: noise_lut_f = 8'h76;
        8'd160: noise_lut_f = 8'h92;
        8'd161: noise_lut_f = 8'h39;
        8'd162: noise_lut_f = 8'h94;
        8'd163: noise_lut_f = 8'h9F;
        8'd164: noise_lut_f = 8'hE4;
        8'd165: noise_lut_f = 8'h0F;
        8'd166: noise_lut_f = 8'h75;
        8'd167: noise_lut_f = 8'hB3;
        8'd168: noise_lut_f = 8'hDB;
        8'd169: noise_lut_f = 8'h24;
        8'd170: noise_lut_f = 8'hAC;
        8'd171: noise_lut_f = 8'hEE;
        8'd172: noise_lut_f = 8'hBE;
        8'd173: noise_lut_f = 8'hD5;
        8'd174: noise_lut_f = 8'h3F;
        8'd175: noise_lut_f = 8'hAC;
        8'd176: noise_lut_f = 8'h36;
        8'd177: noise_lut_f = 8'hC4;
        8'd178: noise_lut_f = 8'h0C;
        8'd179: noise_lut_f = 8'hD8;
        8'd180: noise_lut_f = 8'h77;
        8'd181: noise_lut_f = 8'h4F;
        8'd182: noise_lut_f = 8'hC5;
        8'd183: noise_lut_f = 8'h52;
        8'd184: noise_lut_f = 8'h65;
        8'd185: noise_lut_f = 8'h08;
        8'd186: noise_lut_f = 8'h4E;
        8'd187: noise_lut_f = 8'h3D;
        8'd188: noise_lut_f = 8'hAD;
        8'd189: noise_lut_f = 8'h68;
        8'd190: noise_lut_f = 8'hC9;
        8'd191: noise_lut_f = 8'hC1;
        8'd192: noise_lut_f = 8'h9D;
        8'd193: noise_lut_f = 8'hF7;
        8'd194: noise_lut_f = 8'h50;
        8'd195: noise_lut_f = 8'hEB;
        8'd196: noise_lut_f = 8'hB9;
        8'd197: noise_lut_f = 8'h69;
        8'd198: noise_lut_f = 8'h52;
        8'd199: noise_lut_f = 8'h01;
        8'd200: noise_lut_f = 8'h1B;
        8'd201: noise_lut_f = 8'hD3;
        8'd202: noise_lut_f = 8'hC0;
        8'd203: noise_lut_f = 8'h76;
        8'd204: noise_lut_f = 8'h70;
        8'd205: noise_lut_f = 8'hEA;
        8'd206: noise_lut_f = 8'h87;
        8'd207: noise_lut_f = 8'h2C;
        8'd208: noise_lut_f = 8'h71;
        8'd209: noise_lut_f = 8'h61;
        8'd210: noise_lut_f = 8'h0C;
        8'd211: noise_lut_f = 8'h4B;
        8'd212: noise_lut_f = 8'h13;
        8'd213: noise_lut_f = 8'h14;
        8'd214: noise_lut_f = 8'h6C;
        8'd215: noise_lut_f = 8'hAE;
        8'd216: noise_lut_f = 8'h4C;
        8'd217: noise_lut_f = 8'hCC;
        8'd218: noise_lut_f = 8'hBD;
        8'd219: noise_lut_f = 8'hBC;
        8'd220: noise_lut_f = 8'h61;
        8'd221: noise_lut_f = 8'h1E;
        8'd222: noise_lut_f = 8'h6C;
        8'd223: noise_lut_f = 8'h24;
        8'd224: noise_lut_f = 8'h63;
        8'd225: noise_lut_f = 8'h67;
        8'd226: noise_lut_f = 8'h0F;
        8'd227: noise_lut_f = 8'h7E;
        8'd228: noise_lut_f = 8'hB6;
        8'd229: noise_lut_f = 8'h1C;
        8'd230: noise_lut_f = 8'h5B;
        8'd231: noise_lut_f = 8'h67;
        8'd232: noise_lut_f = 8'h47;
        8'd233: noise_lut_f = 8'hED;
        8'd234: noise_lut_f = 8'h85;
        8'd235: noise_lut_f = 8'h8D;
        8'd236: noise_lut_f = 8'h23;
        8'd237: noise_lut_f = 8'h1E;
        8'd238: noise_lut_f = 8'hED;
        8'd239: noise_lut_f = 8'hEE;
        8'd240: noise_lut_f = 8'h40;
        8'd241: noise_lut_f = 8'h66;
        8'd242: noise_lut_f = 8'h3F;
        8'd243: noise_lut_f = 8'hF9;
        8'd244: noise_lut_f = 8'hF8;
        8'd245: noise_lut_f = 8'h09;
        8'd246: noise_lut_f = 8'h59;
        8'd247: noise_lut_f = 8'hA6;
        8'd248: noise_lut_f = 8'h3E;
        8'd249: noise_lut_f = 8'h70;
        8'd250: noise_lut_f = 8'h73;
        8'd251: noise_lut_f = 8'hD2;
        8'd252: noise_lut_f = 8'h4D;
        8'd253: noise_lut_f = 8'h63;
        8'd254: noise_lut_f = 8'hBA;
        8'd255: noise_lut_f = 8'h01;
        default: noise_lut_f = 8'h00;
    endcase
endfunction

function [7:0] sin_lut_f;
    input [7:0] addr;
    case (addr)
        8'd0: sin_lut_f = 8'h00;
        8'd1: sin_lut_f = 8'h03;
        8'd2: sin_lut_f = 8'h06;
        8'd3: sin_lut_f = 8'h09;
        8'd4: sin_lut_f = 8'h0C;
        8'd5: sin_lut_f = 8'h10;
        8'd6: sin_lut_f = 8'h13;
        8'd7: sin_lut_f = 8'h16;
        8'd8: sin_lut_f = 8'h19;
        8'd9: sin_lut_f = 8'h1C;
        8'd10: sin_lut_f = 8'h1F;
        8'd11: sin_lut_f = 8'h22;
        8'd12: sin_lut_f = 8'h25;
        8'd13: sin_lut_f = 8'h28;
        8'd14: sin_lut_f = 8'h2B;
        8'd15: sin_lut_f = 8'h2E;
        8'd16: sin_lut_f = 8'h31;
        8'd17: sin_lut_f = 8'h33;
        8'd18: sin_lut_f = 8'h36;
        8'd19: sin_lut_f = 8'h39;
        8'd20: sin_lut_f = 8'h3C;
        8'd21: sin_lut_f = 8'h3F;
        8'd22: sin_lut_f = 8'h41;
        8'd23: sin_lut_f = 8'h44;
        8'd24: sin_lut_f = 8'h47;
        8'd25: sin_lut_f = 8'h49;
        8'd26: sin_lut_f = 8'h4C;
        8'd27: sin_lut_f = 8'h4E;
        8'd28: sin_lut_f = 8'h51;
        8'd29: sin_lut_f = 8'h53;
        8'd30: sin_lut_f = 8'h55;
        8'd31: sin_lut_f = 8'h58;
        8'd32: sin_lut_f = 8'h5A;
        8'd33: sin_lut_f = 8'h5C;
        8'd34: sin_lut_f = 8'h5E;
        8'd35: sin_lut_f = 8'h60;
        8'd36: sin_lut_f = 8'h62;
        8'd37: sin_lut_f = 8'h64;
        8'd38: sin_lut_f = 8'h66;
        8'd39: sin_lut_f = 8'h68;
        8'd40: sin_lut_f = 8'h6A;
        8'd41: sin_lut_f = 8'h6B;
        8'd42: sin_lut_f = 8'h6D;
        8'd43: sin_lut_f = 8'h6F;
        8'd44: sin_lut_f = 8'h70;
        8'd45: sin_lut_f = 8'h71;
        8'd46: sin_lut_f = 8'h73;
        8'd47: sin_lut_f = 8'h74;
        8'd48: sin_lut_f = 8'h75;
        8'd49: sin_lut_f = 8'h76;
        8'd50: sin_lut_f = 8'h78;
        8'd51: sin_lut_f = 8'h79;
        8'd52: sin_lut_f = 8'h7A;
        8'd53: sin_lut_f = 8'h7A;
        8'd54: sin_lut_f = 8'h7B;
        8'd55: sin_lut_f = 8'h7C;
        8'd56: sin_lut_f = 8'h7D;
        8'd57: sin_lut_f = 8'h7D;
        8'd58: sin_lut_f = 8'h7E;
        8'd59: sin_lut_f = 8'h7E;
        8'd60: sin_lut_f = 8'h7E;
        8'd61: sin_lut_f = 8'h7F;
        8'd62: sin_lut_f = 8'h7F;
        8'd63: sin_lut_f = 8'h7F;
        8'd64: sin_lut_f = 8'h7F;
        8'd65: sin_lut_f = 8'h7F;
        8'd66: sin_lut_f = 8'h7F;
        8'd67: sin_lut_f = 8'h7F;
        8'd68: sin_lut_f = 8'h7E;
        8'd69: sin_lut_f = 8'h7E;
        8'd70: sin_lut_f = 8'h7E;
        8'd71: sin_lut_f = 8'h7D;
        8'd72: sin_lut_f = 8'h7D;
        8'd73: sin_lut_f = 8'h7C;
        8'd74: sin_lut_f = 8'h7B;
        8'd75: sin_lut_f = 8'h7A;
        8'd76: sin_lut_f = 8'h7A;
        8'd77: sin_lut_f = 8'h79;
        8'd78: sin_lut_f = 8'h78;
        8'd79: sin_lut_f = 8'h76;
        8'd80: sin_lut_f = 8'h75;
        8'd81: sin_lut_f = 8'h74;
        8'd82: sin_lut_f = 8'h73;
        8'd83: sin_lut_f = 8'h71;
        8'd84: sin_lut_f = 8'h70;
        8'd85: sin_lut_f = 8'h6F;
        8'd86: sin_lut_f = 8'h6D;
        8'd87: sin_lut_f = 8'h6B;
        8'd88: sin_lut_f = 8'h6A;
        8'd89: sin_lut_f = 8'h68;
        8'd90: sin_lut_f = 8'h66;
        8'd91: sin_lut_f = 8'h64;
        8'd92: sin_lut_f = 8'h62;
        8'd93: sin_lut_f = 8'h60;
        8'd94: sin_lut_f = 8'h5E;
        8'd95: sin_lut_f = 8'h5C;
        8'd96: sin_lut_f = 8'h5A;
        8'd97: sin_lut_f = 8'h58;
        8'd98: sin_lut_f = 8'h55;
        8'd99: sin_lut_f = 8'h53;
        8'd100: sin_lut_f = 8'h51;
        8'd101: sin_lut_f = 8'h4E;
        8'd102: sin_lut_f = 8'h4C;
        8'd103: sin_lut_f = 8'h49;
        8'd104: sin_lut_f = 8'h47;
        8'd105: sin_lut_f = 8'h44;
        8'd106: sin_lut_f = 8'h41;
        8'd107: sin_lut_f = 8'h3F;
        8'd108: sin_lut_f = 8'h3C;
        8'd109: sin_lut_f = 8'h39;
        8'd110: sin_lut_f = 8'h36;
        8'd111: sin_lut_f = 8'h33;
        8'd112: sin_lut_f = 8'h31;
        8'd113: sin_lut_f = 8'h2E;
        8'd114: sin_lut_f = 8'h2B;
        8'd115: sin_lut_f = 8'h28;
        8'd116: sin_lut_f = 8'h25;
        8'd117: sin_lut_f = 8'h22;
        8'd118: sin_lut_f = 8'h1F;
        8'd119: sin_lut_f = 8'h1C;
        8'd120: sin_lut_f = 8'h19;
        8'd121: sin_lut_f = 8'h16;
        8'd122: sin_lut_f = 8'h13;
        8'd123: sin_lut_f = 8'h10;
        8'd124: sin_lut_f = 8'h0C;
        8'd125: sin_lut_f = 8'h09;
        8'd126: sin_lut_f = 8'h06;
        8'd127: sin_lut_f = 8'h03;
        8'd128: sin_lut_f = 8'h00;
        8'd129: sin_lut_f = 8'hFD;
        8'd130: sin_lut_f = 8'hFA;
        8'd131: sin_lut_f = 8'hF7;
        8'd132: sin_lut_f = 8'hF4;
        8'd133: sin_lut_f = 8'hF0;
        8'd134: sin_lut_f = 8'hED;
        8'd135: sin_lut_f = 8'hEA;
        8'd136: sin_lut_f = 8'hE7;
        8'd137: sin_lut_f = 8'hE4;
        8'd138: sin_lut_f = 8'hE1;
        8'd139: sin_lut_f = 8'hDE;
        8'd140: sin_lut_f = 8'hDB;
        8'd141: sin_lut_f = 8'hD8;
        8'd142: sin_lut_f = 8'hD5;
        8'd143: sin_lut_f = 8'hD2;
        8'd144: sin_lut_f = 8'hCF;
        8'd145: sin_lut_f = 8'hCD;
        8'd146: sin_lut_f = 8'hCA;
        8'd147: sin_lut_f = 8'hC7;
        8'd148: sin_lut_f = 8'hC4;
        8'd149: sin_lut_f = 8'hC1;
        8'd150: sin_lut_f = 8'hBF;
        8'd151: sin_lut_f = 8'hBC;
        8'd152: sin_lut_f = 8'hB9;
        8'd153: sin_lut_f = 8'hB7;
        8'd154: sin_lut_f = 8'hB4;
        8'd155: sin_lut_f = 8'hB2;
        8'd156: sin_lut_f = 8'hAF;
        8'd157: sin_lut_f = 8'hAD;
        8'd158: sin_lut_f = 8'hAB;
        8'd159: sin_lut_f = 8'hA8;
        8'd160: sin_lut_f = 8'hA6;
        8'd161: sin_lut_f = 8'hA4;
        8'd162: sin_lut_f = 8'hA2;
        8'd163: sin_lut_f = 8'hA0;
        8'd164: sin_lut_f = 8'h9E;
        8'd165: sin_lut_f = 8'h9C;
        8'd166: sin_lut_f = 8'h9A;
        8'd167: sin_lut_f = 8'h98;
        8'd168: sin_lut_f = 8'h96;
        8'd169: sin_lut_f = 8'h95;
        8'd170: sin_lut_f = 8'h93;
        8'd171: sin_lut_f = 8'h91;
        8'd172: sin_lut_f = 8'h90;
        8'd173: sin_lut_f = 8'h8F;
        8'd174: sin_lut_f = 8'h8D;
        8'd175: sin_lut_f = 8'h8C;
        8'd176: sin_lut_f = 8'h8B;
        8'd177: sin_lut_f = 8'h8A;
        8'd178: sin_lut_f = 8'h88;
        8'd179: sin_lut_f = 8'h87;
        8'd180: sin_lut_f = 8'h86;
        8'd181: sin_lut_f = 8'h86;
        8'd182: sin_lut_f = 8'h85;
        8'd183: sin_lut_f = 8'h84;
        8'd184: sin_lut_f = 8'h83;
        8'd185: sin_lut_f = 8'h83;
        8'd186: sin_lut_f = 8'h82;
        8'd187: sin_lut_f = 8'h82;
        8'd188: sin_lut_f = 8'h82;
        8'd189: sin_lut_f = 8'h81;
        8'd190: sin_lut_f = 8'h81;
        8'd191: sin_lut_f = 8'h81;
        8'd192: sin_lut_f = 8'h81;
        8'd193: sin_lut_f = 8'h81;
        8'd194: sin_lut_f = 8'h81;
        8'd195: sin_lut_f = 8'h81;
        8'd196: sin_lut_f = 8'h82;
        8'd197: sin_lut_f = 8'h82;
        8'd198: sin_lut_f = 8'h82;
        8'd199: sin_lut_f = 8'h83;
        8'd200: sin_lut_f = 8'h83;
        8'd201: sin_lut_f = 8'h84;
        8'd202: sin_lut_f = 8'h85;
        8'd203: sin_lut_f = 8'h86;
        8'd204: sin_lut_f = 8'h86;
        8'd205: sin_lut_f = 8'h87;
        8'd206: sin_lut_f = 8'h88;
        8'd207: sin_lut_f = 8'h8A;
        8'd208: sin_lut_f = 8'h8B;
        8'd209: sin_lut_f = 8'h8C;
        8'd210: sin_lut_f = 8'h8D;
        8'd211: sin_lut_f = 8'h8F;
        8'd212: sin_lut_f = 8'h90;
        8'd213: sin_lut_f = 8'h91;
        8'd214: sin_lut_f = 8'h93;
        8'd215: sin_lut_f = 8'h95;
        8'd216: sin_lut_f = 8'h96;
        8'd217: sin_lut_f = 8'h98;
        8'd218: sin_lut_f = 8'h9A;
        8'd219: sin_lut_f = 8'h9C;
        8'd220: sin_lut_f = 8'h9E;
        8'd221: sin_lut_f = 8'hA0;
        8'd222: sin_lut_f = 8'hA2;
        8'd223: sin_lut_f = 8'hA4;
        8'd224: sin_lut_f = 8'hA6;
        8'd225: sin_lut_f = 8'hA8;
        8'd226: sin_lut_f = 8'hAB;
        8'd227: sin_lut_f = 8'hAD;
        8'd228: sin_lut_f = 8'hAF;
        8'd229: sin_lut_f = 8'hB2;
        8'd230: sin_lut_f = 8'hB4;
        8'd231: sin_lut_f = 8'hB7;
        8'd232: sin_lut_f = 8'hB9;
        8'd233: sin_lut_f = 8'hBC;
        8'd234: sin_lut_f = 8'hBF;
        8'd235: sin_lut_f = 8'hC1;
        8'd236: sin_lut_f = 8'hC4;
        8'd237: sin_lut_f = 8'hC7;
        8'd238: sin_lut_f = 8'hCA;
        8'd239: sin_lut_f = 8'hCD;
        8'd240: sin_lut_f = 8'hCF;
        8'd241: sin_lut_f = 8'hD2;
        8'd242: sin_lut_f = 8'hD5;
        8'd243: sin_lut_f = 8'hD8;
        8'd244: sin_lut_f = 8'hDB;
        8'd245: sin_lut_f = 8'hDE;
        8'd246: sin_lut_f = 8'hE1;
        8'd247: sin_lut_f = 8'hE4;
        8'd248: sin_lut_f = 8'hE7;
        8'd249: sin_lut_f = 8'hEA;
        8'd250: sin_lut_f = 8'hED;
        8'd251: sin_lut_f = 8'hF0;
        8'd252: sin_lut_f = 8'hF4;
        8'd253: sin_lut_f = 8'hF7;
        8'd254: sin_lut_f = 8'hFA;
        8'd255: sin_lut_f = 8'hFD;
        default: sin_lut_f = 8'h00;
    endcase
endfunction

// ════════════════════════════════════════════════════════════
// バイリニア補間ノイズ (Q4.4 座標入力)
// ════════════════════════════════════════════════════════════
function [7:0] noise_bilerp;
    input [3:0] ux; input [3:0] fx;
    input [3:0] uy; input [3:0] fy;
    reg [7:0]  n00, n10, n01, n11;
    reg [11:0] t0, t1;
    begin
        n00 = noise_lut_f({uy,        ux});
        n10 = noise_lut_f({uy,        ux + 4'h1});
        n01 = noise_lut_f({uy + 4'h1, ux});
        n11 = noise_lut_f({uy + 4'h1, ux + 4'h1});
        t0 = n00 * (4'd15 - fx) + n10 * fx;
        t1 = n01 * (4'd15 - fx) + n11 * fx;
        noise_bilerp = ((t0 * (4'd15 - fy) + t1 * fy) >> 8) & 8'hFF;
    end
endfunction

// ════════════════════════════════════════════════════════════
// fBm 3オクターブ (振幅: 0.5 + 0.25 + 0.125)
// ════════════════════════════════════════════════════════════
function [7:0] fbm3;
    input [7:0] px;
    input [7:0] py;
    reg [7:0] n0, n1, n2;
    reg [7:0] p1x, p1y, p2x, p2y;
    begin
        n0  = noise_bilerp(px[7:4], px[3:0], py[7:4], py[3:0]);
        p1x = {px[6:0], 1'b0};
        p1y = {py[6:0], 1'b0};
        n1  = noise_bilerp(p1x[7:4], p1x[3:0], p1y[7:4], p1y[3:0]);
        p2x = {px[5:0], 2'b00};
        p2y = {py[5:0], 2'b00};
        n2  = noise_bilerp(p2x[7:4], p2x[3:0], p2y[7:4], p2y[3:0]);
        fbm3 = (n0 >> 1) + (n1 >> 2) + (n2 >> 3);
    end
endfunction

// ════════════════════════════════════════════════════════════
// パイプラインレジスタ宣言
// 符号付き値はすべて符号なし reg で保持し、
// MSB を符号ビットとして各ステージで解釈する。
// ════════════════════════════════════════════════════════════

// ── Stage 0 → 1 ─────────────────────────────────────────────
// nx: 12bit 2の補数  hcount(0..1919) - 960 → -960..+959
// ny: 11bit 2の補数  vcount(0..1079) - 540 → -540..+539
reg [11:0] s1_nx;   // MSB=符号ビット (1=負)
reg [10:0] s1_ny;   // MSB=符号ビット (1=負)
reg [23:0] s1_time;
reg        s1_de;

// ── Stage 1 → 2 ─────────────────────────────────────────────
reg [7:0]  s2_terrain_h;
reg [10:0] s2_ny;   // 2の補数
reg [11:0] s2_nx;   // 2の補数
reg [23:0] s2_time;
reg        s2_de;

// ── Stage 2 → 3a ─────────────────────────────────────────────
reg        s3a_is_terrain;
reg [7:0]  s3a_height_diff;
reg [11:0] s3a_nx;   // 2の補数
reg [10:0] s3a_ny;   // 2の補数
reg [7:0]  s3a_terrain_h;
reg [23:0] s3a_time;
reg        s3a_de;

// ── Stage 3a → 3b ─────────────────────────────────────────────
reg [7:0]  s3b_sky_t;
reg [7:0]  s3b_sun_dist;
reg [7:0]  s3b_rock_r;
reg [7:0]  s3b_rock_g;
reg [7:0]  s3b_rock_b;
reg [7:0]  s3b_height_diff;
reg        s3b_is_terrain;
reg        s3b_de;

// ── Stage 3b → 4 ──────────────────────────────────────────────
reg [7:0] s4_sky_r, s4_sky_g, s4_sky_b;
reg [7:0] s4_fog_r, s4_fog_g, s4_fog_b;
reg       s4_is_terrain;
reg       s4_de;

// ── Stage 4 → 5 ───────────────────────────────────────────────
reg [7:0] s5_r, s5_g, s5_b;
reg       s5_de;

// ════════════════════════════════════════════════════════════
// Stage 0: 座標正規化
//
// nx = hcount - 960  (12bit 2の補数)
// ny = vcount - 540  (11bit 2の補数)
//
// 変換: $signed 不使用の場合、符号なし減算の結果は
//       2の補数表現として等価なので、そのまま代入する。
//       hcount は11bit(0..1919) → {1'b0, hcount} で12bitゼロ拡張後に減算。
// ════════════════════════════════════════════════════════════
always @(posedge clk or posedge rst) begin
    if (rst) begin
        s1_nx <= 12'd0; s1_ny <= 11'd0; s1_time <= 24'd0; s1_de <= 1'b0;
    end else begin
        // 符号なし減算 → 下位ビットは2の補数と同一
        s1_nx   <= {1'b0, hcount[10:0]} - 12'd960;  // 結果MSBが符号ビット
        s1_ny   <= {1'b0, vcount} - 11'd540;  // 結果MSBが符号ビット
        s1_time <= frame_cnt;
        s1_de   <= de;
    end
end

// ════════════════════════════════════════════════════════════
// Stage 1: fBm地形高さ
// col_x: nx の上位9bit(符号+整数部)のうち整数8bit(nx[10:3])を取り、
//        +128 してUオフセット (0..255 の無符号座標へ変換)
// ════════════════════════════════════════════════════════════
wire [7:0] fly_z  = s1_time[10:3];
wire [7:0] col_x  = (s1_nx[10:6] + 8'd128) & 8'hFF;
wire [7:0] th_raw = fbm3(col_x, fly_z);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        s2_terrain_h <= 8'd0; s2_ny <= 11'd0; s2_nx <= 12'd0;
        s2_time <= 24'd0; s2_de <= 1'b0;
    end else begin
        s2_terrain_h <= th_raw;
        s2_ny        <= s1_ny;
        s2_nx        <= s1_nx;
        s2_time      <= s1_time;
        s2_de        <= s1_de;
    end
end

// ════════════════════════════════════════════════════════════
// Stage 2: 空/地形 判定
//
// horizon_ny = terrain_h[7:1] - 80  (11bit 2の補数)
//   terrain_h[7:1] は 0..127。80を引くと -80..+47 の範囲になる。
//   符号なし減算でそのまま2の補数を得る。
//
// is_terrain_w: s2_ny > horizon_ny の符号付き比較
//   差分 D = s2_ny - horizon_ny を11bitで計算し、
//   D == 0 でなく D の MSB が 0 なら s2_ny > horizon_ny (正の差)
//   ただし D == 0 は等号なので is_terrain は偽。
//
// hd_wide: is_terrain のとき s2_ny - horizon_ny の正の差分
//   上記 D がそのまま使える (MSB=0 のとき正の値)
// ════════════════════════════════════════════════════════════
wire [10:0] horizon_ny  = {3'b000, s2_terrain_h[7:1]} - 11'd80;
//   D = s2_ny - horizon_ny (11bit 符号なし演算 = 2の補数演算)
wire [10:0] ny_minus_h  = s2_ny - horizon_ny;
//   ny > horizon: D の MSB が 0 かつ D != 0
wire        is_terrain_w = ~ny_minus_h[10] & (ny_minus_h != 11'd0);
//   height_diff = D (is_terrainのとき正値, 最大255でクランプ)
wire [7:0]  hd_raw       = is_terrain_w
                           ? ((ny_minus_h > 11'd255) ? 8'hFF : ny_minus_h[7:0])
                           : 8'd0;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        s3a_is_terrain <= 1'b0; s3a_height_diff <= 8'd0;
        s3a_nx <= 12'd0; s3a_ny <= 11'd0; s3a_terrain_h <= 8'd0;
        s3a_time <= 24'd0; s3a_de <= 1'b0;
    end else begin
        s3a_is_terrain  <= is_terrain_w;
        s3a_height_diff <= hd_raw;
        s3a_nx          <= s2_nx;
        s3a_ny          <= s2_ny;
        s3a_terrain_h   <= s2_terrain_h;
        s3a_time        <= s2_time;
        s3a_de          <= s2_de;
    end
end

// ════════════════════════════════════════════════════════════
// Stage 3a: LUT読み出し・比較・雪判定
//
// クリティカルパス: case LUT (≈3段) + 減算 + 絶対値 + 比較
// ════════════════════════════════════════════════════════════

// 空グラデーション: ny < 0 (MSB=1) のとき空、地形側は 0
// ny が負値のとき、その大きさ (絶対値) = ~ny + 1 の上位ビット
// sky_t は 0..127 の正値
//   ny[10] == 1 → ny は負 → sky 側
//   sky_t = 127 - |ny|>>3
//         = 127 - (~ny + 1)[9:3]   (負値の絶対値の上位7bit)
// 簡略化: ny が11bit 2の補数のとき、
//         ~ny[9:3] + 1 は |ny| の上位7bit (オーバフローしないことを確認済み)
wire        s3a_ny_neg  = s3a_ny[10];              // 1 のとき ny < 0
wire [9:0]  s3a_ny_abs  = s3a_ny_neg              // |ny| の下位10bit
                          ? (~s3a_ny[9:0] + 10'd1)
                          : s3a_ny[9:0];
wire [7:0]  s3a_sky_t   = (!s3a_is_terrain && s3a_ny_neg)
                          ? (8'd127 - {1'b0, s3a_ny_abs[9:3]})
                          : 8'd0;

// 太陽水平位置: sin_lut_f → 8bit 2の補数 (-127..+127)
// sun_off_x のMSBが符号ビット (1=負)
wire [7:0] s3a_sun_ang   = s3a_time[9:2];
wire [7:0] s3a_sun_raw   = sin_lut_f(s3a_sun_ang); // 2の補数 8bit

// 太陽との水平距離 (絶対値)
// pixel_x = s3a_nx[8:1]  (11bitの上位8bit、2の補数)
// sun_x   = s3a_sun_raw  (8bit 2の補数)
// どちらも符号付き8bitとして扱い 9bit に符号拡張して減算する
// 符号拡張: A[8:1] の MSB を [8] に、sun_raw の MSB を [8] にコピー
wire [8:0] s3a_px_ext   = {s3a_nx[8], s3a_nx[8:1]};   // 符号拡張 (9bit 2の補数)
wire [8:0] s3a_sun_ext  = {s3a_sun_raw[7], s3a_sun_raw}; // 符号拡張 (9bit 2の補数)
wire [8:0] s3a_sun_dx   = s3a_px_ext - s3a_sun_ext;    // 9bit 2の補数減算
wire [8:0] s3a_sun_abs  = s3a_sun_dx[8]                // MSB=1 → 負 → 絶対値に変換
                          ? (~s3a_sun_dx + 9'd1)
                          : s3a_sun_dx;
wire [7:0] s3a_sun_dist = (s3a_sun_abs[8] || s3a_sun_abs > 9'd255)
                          ? 8'hFF : s3a_sun_abs[7:0];

// 岩石ノイズカラー
wire [7:0] s3a_rock_noise = noise_lut_f({s3a_nx[5:2], s3a_time[5:2]});

// 雪判定 + 岩石/雪カラー選択
wire       s3a_is_snow = (s3a_terrain_h > 8'd180);
wire [7:0] s3a_rock_r  = s3a_is_snow ? 8'd228
                        : (8'd90 + {3'b000, s3a_rock_noise[7:3]});
wire [7:0] s3a_rock_g  = s3a_is_snow ? 8'd234
                        : (8'd72 + {4'b0000, s3a_rock_noise[7:4]});
wire [7:0] s3a_rock_b  = s3a_is_snow ? 8'd244
                        : (8'd45 + {5'b00000, s3a_rock_noise[7:5]});

always @(posedge clk or posedge rst) begin
    if (rst) begin
        s3b_sky_t       <= 8'd0;
        s3b_sun_dist    <= 8'd0;
        s3b_rock_r      <= 8'd0; s3b_rock_g <= 8'd0; s3b_rock_b <= 8'd0;
        s3b_height_diff <= 8'd0;
        s3b_is_terrain  <= 1'b0;
        s3b_de          <= 1'b0;
    end else begin
        s3b_sky_t       <= s3a_sky_t;
        s3b_sun_dist    <= s3a_sun_dist;
        s3b_rock_r      <= s3a_rock_r;
        s3b_rock_g      <= s3a_rock_g;
        s3b_rock_b      <= s3a_rock_b;
        s3b_height_diff <= s3a_height_diff;
        s3b_is_terrain  <= s3a_is_terrain;
        s3b_de          <= s3a_de;
    end
end

// ════════════════════════════════════════════════════════════
// Stage 3b: 乗算・加算
//
// クリティカルパス: 8×8乗算 (DSP) + 16bit加算
// ════════════════════════════════════════════════════════════

// 太陽グロウ: dist < 12 → 191 - dist*12
wire [7:0] s3b_sun_glow = (!s3b_is_terrain && s3b_sun_dist < 8'd12)
                          ? (8'd191 - s3b_sun_dist * 8'd12)
                          : 8'd0;

// 空 RGB (9bit 演算 → クランプは次段で行う)
wire [8:0] s3b_sky_r9 = {1'b0, s3b_sky_t[7:1]} + {1'b0, s3b_sun_glow}      + 9'd12;
wire [8:0] s3b_sky_g9 = {1'b0, s3b_sky_t[6:0]} + {1'b0, s3b_sun_glow[7:1]} + 9'd28;
wire [8:0] s3b_sky_b9 = {1'b0, s3b_sky_t}                                   + 9'd80;

// 大気霧ブレンド: terrain * dist/255 + fogcol * (255-dist)/255
wire [7:0]  s3b_fog_amt = 8'd255 - s3b_height_diff;
wire [15:0] s3b_fog_r16 = s3b_rock_r * s3b_height_diff + 8'd140 * s3b_fog_amt;
wire [15:0] s3b_fog_g16 = s3b_rock_g * s3b_height_diff + 8'd160 * s3b_fog_amt;
wire [15:0] s3b_fog_b16 = s3b_rock_b * s3b_height_diff + 8'd185 * s3b_fog_amt;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        s4_sky_r <= 8'd0; s4_sky_g <= 8'd0; s4_sky_b <= 8'd0;
        s4_fog_r <= 8'd0; s4_fog_g <= 8'd0; s4_fog_b <= 8'd0;
        s4_is_terrain <= 1'b0; s4_de <= 1'b0;
    end else begin
        s4_sky_r <= s3b_sky_r9[8] ? 8'hFF : s3b_sky_r9[7:0];
        s4_sky_g <= s3b_sky_g9[8] ? 8'hFF : s3b_sky_g9[7:0];
        s4_sky_b <= s3b_sky_b9[8] ? 8'hFF : s3b_sky_b9[7:0];
        s4_fog_r <= s3b_fog_r16[15:8];
        s4_fog_g <= s3b_fog_g16[15:8];
        s4_fog_b <= s3b_fog_b16[15:8];
        s4_is_terrain <= s3b_is_terrain;
        s4_de         <= s3b_de;
    end
end

// ════════════════════════════════════════════════════════════
// Stage 4: sky/terrain MUX
// ════════════════════════════════════════════════════════════
always @(posedge clk or posedge rst) begin
    if (rst) begin
        s5_r <= 8'd0; s5_g <= 8'd0; s5_b <= 8'd0; s5_de <= 1'b0;
    end else begin
        s5_r  <= s4_is_terrain ? s4_fog_r : s4_sky_r;
        s5_g  <= s4_is_terrain ? s4_fog_g : s4_sky_g;
        s5_b  <= s4_is_terrain ? s4_fog_b : s4_sky_b;
        s5_de <= s4_de;
    end
end

// ════════════════════════════════════════════════════════════
// Stage 5: 出力レジスタ (DEブランク)
// ════════════════════════════════════════════════════════════
always @(posedge clk or posedge rst) begin
    if (rst) begin
        r <= 8'd0; g <= 8'd0; b <= 8'd0;
    end else begin
        r <= s5_de ? s5_r : 8'd0;
        g <= s5_de ? s5_g : 8'd0;
        b <= s5_de ? s5_b : 8'd0;
    end
end

endmodule