// =====================================================================
// rm_pkg : 固定小数点ユーティリティ + sin/exp ルックアップテーブル
//   元のGLSLレイマーチング山岳シェーダーをSystemVerilogに移植するための
//   共通パッケージ。Q12.20 (32bit signed、小数点以下20bit) を使用。
//   LUTはcase文によるROM関数として実装 (initialブロック不使用、合成安全)。
// =====================================================================
package rm_pkg;

    localparam int FRAC   = 20;
    localparam int WIDTH  = 32;
    typedef logic signed [WIDTH-1:0] fixed_t;

    localparam int SIN_N = 1024;
    localparam int EXP_N = 256;

    // ---- 定数 (Q12.20) --------------------------------------------
    localparam fixed_t ONE        = fixed_t'(1 <<< FRAC);
    localparam fixed_t HALF       = fixed_t'(1 <<< (FRAC-1));
    localparam fixed_t TWO        = fixed_t'(2 <<< FRAC);
    localparam fixed_t THREE      = fixed_t'(3 <<< FRAC);
    localparam fixed_t ZERO       = fixed_t'(0);

    // mat2 m2 = (0.8,-0.6 / 0.6,0.8) と 1.7倍スケール (mapのfbmループ用)
    localparam fixed_t M2_00      = fixed_t'(838861);    // 0.8
    localparam fixed_t M2_01      = -fixed_t'(629146);   // -0.6
    localparam fixed_t M2_10      = fixed_t'(629146);    // 0.6
    localparam fixed_t M2_11      = fixed_t'(838861);    // 0.8
    localparam fixed_t SCALE_1_7  = fixed_t'(1782579);   // 1.7

    localparam fixed_t PI           = fixed_t'(3294199);
    localparam fixed_t TWO_PI       = fixed_t'(6588397);
    localparam fixed_t HALF_PI      = fixed_t'(1647099);
    localparam fixed_t ONE_OVER_2PI = fixed_t'(166886);
    // SIN_N/(2*pi) : 角度(rad)をLUTインデックスへ変換するための定数
    localparam fixed_t N_OVER_2PI_CONST = fixed_t'(170891319);
    // (EXP_N-1)/EXP_Y_MAX : yをEXP_LUTインデックスへ変換するための定数
    localparam fixed_t EXP_STEP_INV     = fixed_t'(66846720);
    localparam fixed_t EXP_Y_MAX        = fixed_t'(4194304); // 4.0

    // ---- 基本演算 ----------------------------------------------------
    // 固定小数点乗算 (Q12.20 x Q12.20 -> Q12.20)、64bit中間結果で丸め(切り捨て)
    function automatic fixed_t fmul(input fixed_t a, input fixed_t b);
        logic signed [2*WIDTH-1:0] p;
        p = a * b;
        return fixed_t'(p >>> FRAC);
    endfunction

    function automatic fixed_t fabs_(input fixed_t a);
        return (a[WIDTH-1]) ? -a : a;
    endfunction

    function automatic fixed_t fmax(input fixed_t a, input fixed_t b);
        return (a > b) ? a : b;
    endfunction

    function automatic fixed_t fmin(input fixed_t a, input fixed_t b);
        return (a < b) ? a : b;
    endfunction

    function automatic fixed_t fclamp(input fixed_t a, input fixed_t lo, input fixed_t hi);
        return fmax(lo, fmin(hi, a));
    endfunction

    // ---- sin ROM (1024エントリ, 0..2*piをcase文で網羅, Q12.20) --------
`include "sin_lut.svh"

    // 任意角度(rad, Q12.20)を 0..2*pi に正規化してROM引き ("floor"は算術右シフトで実現)
    function automatic fixed_t sin_fx(input fixed_t angle);
        fixed_t n_frac, n_int, reduced;
        int unsigned idx;
        n_frac  = fmul(angle, ONE_OVER_2PI);      // angle/(2*pi) (実数値)
        n_int   = (n_frac >>> FRAC) <<< FRAC;     // floor()し、固定小数点表現に戻す
        reduced = angle - fmul(n_int, TWO_PI);    // 0..2*pi に正規化
        idx     = (fmul(reduced, N_OVER_2PI_CONST) >>> FRAC) & (SIN_N-1);
        return sin_lut_rom(idx);
    endfunction

    function automatic fixed_t cos_fx(input fixed_t angle);
        return sin_fx(angle + HALF_PI);
    endfunction

    // cosNoise(pos) = 0.5*(sin(pos.x)+sin(pos.y))  ※元コードの関数名はcosだが実装はsinを使用(元コード踏襲)
    function automatic fixed_t cos_noise(input fixed_t x, input fixed_t y);
        return fmul(HALF, sin_fx(x) + sin_fx(y));
    endfunction

    // ---- exp(-y) ROM (256エントリ, y=0..4.0, Q12.20) ------------------
`include "exp_lut.svh"

    function automatic fixed_t exp_neg_fx(input fixed_t y);
        fixed_t yc;
        int unsigned idx;
        yc  = fclamp(y, ZERO, EXP_Y_MAX);
        idx = fmul(yc, EXP_STEP_INV) >>> FRAC;
        if (idx > EXP_N-1) idx = EXP_N-1;
        return exp_lut_rom(idx);
    endfunction

endpackage : rm_pkg
