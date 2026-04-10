// ============================================================
// shader_mountains.v
// Mountains + Sky flight shader for FPGA DVI output
//
// LUT実装方針:
//   initial ブロックを一切使わず，全テーブルを純組合せ論理
//   (case文 function) で実装しているため FPGA 合成に適している．
//   ツールは case 関数を Block RAM または分散 LUT に推論する．
//
// パイプライン: 5 段レジスタ → 5サイクルレイテンシ
//   S0: 座標正規化
//   S1: fBm ノイズ → 地形高さ
//   S2: 空/地形 判定
//   S3: カラー合成 (岩・雪・霧・空)
//   S4: 出力レジスタ
// ============================================================
module shader_mountains (
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] hcount,      // 0..1919
    input  wire [10:0] vcount,      // 0..1079
    input  wire        de,
    input  wire [23:0] frame_cnt,   // 30Hz インクリメント
    output reg  [ 7:0] r,
    output reg  [ 7:0] g,
    output reg  [ 7:0] b
);

localparam CX = 960;
localparam CY = 540;

// ════════════════════════════════════════════════════════════
// ノイズ LUT — 組合せ論理 function (initial ブロック不使用)
// ════════════════════════════════════════════════════════════
// noise_lut_f: int(abs(sin(k*127.1+k*311.7)*43758.5)) % 256
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

// sin_lut_f: round(sin(2π·k/256)·127) & 0xFF (符号付き8bit, 2の補数)
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
// バイリニア補間ノイズ — 組合せ論理 function
// 入力: Q4.4 座標 (上位4bit=整数部, 下位4bit=小数部)
// ════════════════════════════════════════════════════════════
function [7:0] noise_bilerp;
    input [3:0] ux; input [3:0] fx;
    input [3:0] uy; input [3:0] fy;
    reg [7:0]  n00, n10, n01, n11;
    reg [11:0] t0, t1;
    begin
        n00 = noise_lut_f({uy,       ux});
        n10 = noise_lut_f({uy,       ux + 4'h1});
        n01 = noise_lut_f({uy + 4'h1, ux});
        n11 = noise_lut_f({uy + 4'h1, ux + 4'h1});
        t0 = n00 * (4'd15 - fx) + n10 * fx;
        t1 = n01 * (4'd15 - fx) + n11 * fx;
        noise_bilerp = ((t0 * (4'd15 - fy) + t1 * fy) >> 8) & 8'hFF;
    end
endfunction

// ════════════════════════════════════════════════════════════
// fBm 3オクターブ — 組合せ論理 function
// 振幅: oct0×0.5 + oct1×0.25 + oct2×0.125
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
// パイプラインレジスタ
// ════════════════════════════════════════════════════════════
// S0→S1
reg signed [11:0] s1_nx;
reg signed [10:0] s1_ny;
reg        [23:0] s1_time;
reg               s1_de;

// S1→S2
reg  [7:0]        s2_terrain_h;
reg signed [10:0] s2_ny;
reg signed [11:0] s2_nx;
reg        [23:0] s2_time;
reg               s2_de;

// S2→S3
reg               s3_is_terrain;
reg  [7:0]        s3_height_diff;
reg signed [11:0] s3_nx;
reg signed [10:0] s3_ny;
reg  [7:0]        s3_terrain_h;
reg        [23:0] s3_time;
reg               s3_de;

// S3→S4
reg [7:0] s4_r, s4_g, s4_b;
reg       s4_de;

// ════════════════════════════════════════════════════════════
// Stage 0: 座標正規化
// ════════════════════════════════════════════════════════════
always @(posedge clk or posedge rst) begin
    if (rst) begin
        s1_nx <= 0; s1_ny <= 0; s1_time <= 0; s1_de <= 0;
    end else begin
        s1_nx  <= $signed({1'b0, hcount}) - $signed(12'd960);
        s1_ny  <= $signed({1'b0, vcount}) - $signed(11'd540);
        s1_time <= frame_cnt;
        s1_de  <= de;
    end
end

// ════════════════════════════════════════════════════════════
// Stage 1: fBm地形高さ計算
//   fly_z = frame_cnt[10:3]  Z方向スクロール (30Hz/8 ≒ 3.75Hz)
//   col_x = nx>>3 + 128      列をQ4.4座標 (0..255) へマップ
// ════════════════════════════════════════════════════════════
wire [7:0] fly_z  = s1_time[10:3];
wire [7:0] col_x  = (s1_nx[10:3] + 8'd128) & 8'hFF;
wire [7:0] th_raw = fbm3(col_x, fly_z);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        s2_terrain_h <= 0; s2_ny <= 0; s2_nx <= 0;
        s2_time <= 0; s2_de <= 0;
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
//   horizon_ny: 地平線のスクリーンY (CYからの符号付きオフセット)
//   height_diff: 地平線より何ピクセル下か (0=地平線, 255=手前)
// ════════════════════════════════════════════════════════════
wire signed [10:0] horizon_ny  = $signed({3'b000, s2_terrain_h[7:1]}) - 11'sd80;
wire               is_terrain_w = ($signed(s2_ny) > horizon_ny);
wire        [10:0] hd_wide     = is_terrain_w
                                 ? ($signed(s2_ny) - horizon_ny)
                                 : 11'd0;
wire        [7:0]  hd_raw      = (hd_wide > 11'd255) ? 8'hFF : hd_wide[7:0];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        s3_is_terrain <= 0; s3_height_diff <= 0;
        s3_nx <= 0; s3_ny <= 0; s3_terrain_h <= 0;
        s3_time <= 0; s3_de <= 0;
    end else begin
        s3_is_terrain  <= is_terrain_w;
        s3_height_diff <= hd_raw;
        s3_nx          <= s2_nx;
        s3_ny          <= s2_ny;
        s3_terrain_h   <= s2_terrain_h;
        s3_time        <= s2_time;
        s3_de          <= s2_de;
    end
end

// ════════════════════════════════════════════════════════════
// Stage 3: カラー合成 (組合せ論理)
// ════════════════════════════════════════════════════════════

// ── 空グラデーション ─────────────────────────────────────────
// ny < 0 = 画面上半分 (空) → sky_t: 地平線=0, 最上部=127
wire [7:0] sky_t = (!s3_is_terrain && $signed(s3_ny) < 11'sd0)
                   ? (8'd127 - {1'b0, s3_ny[9:3]})
                   : 8'd0;

// ── 太陽位置・グロウ ─────────────────────────────────────────
// sin_lut で水平スイープ (時間インデックス → 横位置)
wire [7:0]        sun_ang     = s3_time[9:2];
wire signed [7:0] sun_off_x   = $signed(sin_lut_f(sun_ang));
wire signed [9:0] sun_dx_s    = $signed(s3_nx[8:1]) - $signed({1'b0, sun_off_x});
wire [8:0]        sun_dx_abs  = sun_dx_s[9] ? (~sun_dx_s[8:0] + 9'd1) : sun_dx_s[8:0];
wire [7:0]        sun_dist    = (sun_dx_abs > 9'd255) ? 8'hFF : sun_dx_abs[7:0];
wire [7:0]        sun_glow    = (!s3_is_terrain && sun_dist < 8'd12)
                                ? (8'd191 - sun_dist * 8'd12)
                                : 8'd0;

// 空 RGB (9bit演算 → 8bit クランプ)
wire [8:0] sky_r9 = {1'b0, sky_t[7:1]} + {1'b0, sun_glow}      + 9'd12;
wire [8:0] sky_g9 = {1'b0, sky_t[6:0]} + {1'b0, sun_glow[7:1]} + 9'd28;
wire [8:0] sky_b9 = {1'b0, sky_t}                               + 9'd80;
wire [7:0] sky_r  = sky_r9[8] ? 8'hFF : sky_r9[7:0];
wire [7:0] sky_g  = sky_g9[8] ? 8'hFF : sky_g9[7:0];
wire [7:0] sky_b  = sky_b9[8] ? 8'hFF : sky_b9[7:0];

// ── 地形ベースカラー (岩石 + ノイズ色調) ─────────────────────
wire [7:0] rock_noise = noise_lut_f({s3_nx[5:2], s3_time[5:2]});
wire [7:0] trr = 8'd90 + {3'b000, rock_noise[7:3]};   // 90..121
wire [7:0] trg = 8'd72 + {4'b0000, rock_noise[7:4]};  // 72..87
wire [7:0] trb = 8'd45 + {5'b00000, rock_noise[7:5]}; // 45..52

// ── 雪 (高い地形 = 白) ───────────────────────────────────────
wire        is_snow   = (s3_terrain_h > 8'd180);
wire [7:0]  terrain_r = is_snow ? 8'd228 : trr;
wire [7:0]  terrain_g = is_snow ? 8'd234 : trg;
wire [7:0]  terrain_b = is_snow ? 8'd244 : trb;

// ── 大気霧 ───────────────────────────────────────────────────
// height_diff=0(遠方) → fog最大, height_diff=255(手前) → fog最小
wire [7:0]  fog_amt = 8'd255 - s3_height_diff;
wire [15:0] fog_r16 = terrain_r * s3_height_diff + 8'd140 * fog_amt;
wire [15:0] fog_g16 = terrain_g * s3_height_diff + 8'd160 * fog_amt;
wire [15:0] fog_b16 = terrain_b * s3_height_diff + 8'd185 * fog_amt;
wire [7:0]  fogged_r = fog_r16[15:8];
wire [7:0]  fogged_g = fog_g16[15:8];
wire [7:0]  fogged_b = fog_b16[15:8];

// ── 最終ピクセル ─────────────────────────────────────────────
wire [7:0] fr = s3_is_terrain ? fogged_r : sky_r;
wire [7:0] fg = s3_is_terrain ? fogged_g : sky_g;
wire [7:0] fb = s3_is_terrain ? fogged_b : sky_b;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        s4_r <= 0; s4_g <= 0; s4_b <= 0; s4_de <= 0;
    end else begin
        s4_r <= fr; s4_g <= fg; s4_b <= fb; s4_de <= s3_de;
    end
end

// ════════════════════════════════════════════════════════════
// Stage 4: 出力レジスタ (アクティブ期間外はブランク)
// ════════════════════════════════════════════════════════════
always @(posedge clk or posedge rst) begin
    if (rst) begin
        r <= 0; g <= 0; b <= 0;
    end else begin
        r <= s4_de ? s4_r : 8'd0;
        g <= s4_de ? s4_g : 8'd0;
        b <= s4_de ? s4_b : 8'd0;
    end
end

endmodule