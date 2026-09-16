// =====================================================================
// rm_pkg : 固定小数点ユーティリティ + sin/exp ルックアップテーブル
//   元のGLSLレイマーチング山岳シェーダーをSystemVerilogに移植するための
//   共通パッケージ。Q8.16 (24bit signed、小数点以下16bit) を使用。
//   表現範囲: -128.0 .. +127.9999847  (Q12.20の約±2048から縮小)
//   LUTはcase文によるROM関数として実装 (initialブロック不使用、合成安全)。
// =====================================================================
package rm_pkg;

    localparam int FRAC   = 16;
    localparam int WIDTH  = 24;
    typedef logic signed [WIDTH-1:0] fixed_t;

    localparam int SIN_N   = 1024;              // 2^10
    localparam int SIN_BITS= 10;
    localparam int EXP_N   = 256;

    // ---- 定数 (Q8.16) --------------------------------------------
    localparam fixed_t ONE        = fixed_t'(1 <<< FRAC);
    localparam fixed_t HALF       = fixed_t'(1 <<< (FRAC-1));
    localparam fixed_t TWO        = fixed_t'(2 <<< FRAC);
    localparam fixed_t THREE      = fixed_t'(3 <<< FRAC);
    localparam fixed_t ZERO       = fixed_t'(0);

    // mat2 m2 = (0.8,-0.6 / 0.6,0.8) と 1.7倍スケール (mapのfbmループ用)
    localparam fixed_t M2_00      = fixed_t'(52429);    // 0.8
    localparam fixed_t M2_01      = -fixed_t'(39322);   // -0.6
    localparam fixed_t M2_10      = fixed_t'(39322);    // 0.6
    localparam fixed_t M2_11      = fixed_t'(52429);    // 0.8
    localparam fixed_t SCALE_1_7  = fixed_t'(111411);   // 1.7

    localparam fixed_t PI           = fixed_t'(205887);
    localparam fixed_t TWO_PI       = fixed_t'(411775);
    localparam fixed_t HALF_PI      = fixed_t'(102944);
    localparam fixed_t ONE_OVER_2PI = fixed_t'(10430);
    localparam fixed_t EXP_Y_MAX        = fixed_t'(262144);   // 4.0

    // ---- 基本演算 ----------------------------------------------------
    // 固定小数点乗算 (Q8.16 x Q8.16 -> Q8.16)、48bit中間結果で丸め(切り捨て)
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

    localparam fixed_t MAXVAL = fixed_t'((1 <<< (WIDTH-1)) - 1);
    localparam fixed_t MINVAL = fixed_t'(-(1 <<< (WIDTH-1)));

    // 2*WIDTH幅の中間値(乗算結果など)をfixed_tの表現範囲へ飽和させて変換する。
    // Q8.16は整数部が約±128しかないため、"定数×変数"の結果がこの範囲を
    // 超えうる箇所(calcShadowのh*164.0など)で使用する。
    function automatic fixed_t sat_from_wide(input logic signed [2*WIDTH-1:0] v);
        logic signed [2*WIDTH-1:0] maxv_w, minv_w;
        maxv_w = MAXVAL;   // 符号付き→符号付きの代入なので自動的に符号拡張される
        minv_w = MINVAL;
        if (v > maxv_w)      return MAXVAL;
        else if (v < minv_w) return MINVAL;
        else                 return fixed_t'(v);
    endfunction

    // ---- sin ROM (1024エントリ, 0..2*piをcase文で網羅, Q8.16) --------
`include "sin_lut.svh"

    // 任意角度(rad, Q8.16)をLUT引きする。
    // NOTE: 1024/(2*pi)≈163.97 はQ8.16(最大約128)に収まらないため、
    //       角度を明示的に0..2*piへ正規化してから定数倍する方式ではなく、
    //       「n_frac = angle/(2*pi) の小数部の上位SIN_BITSビット」を
    //       そのままLUTインデックスとして使うビット切り出し方式にしている。
    //       2の補数表現では (x - floor(x)) は x の下位FRACビットを
    //       符号なしとして読むだけで得られるため、減算や大きな定数を
    //       一切必要としない。
    function automatic fixed_t sin_fx(input fixed_t angle);
        fixed_t n_frac;
        logic [FRAC-1:0] frac_bits;
        int unsigned idx;
        n_frac   = fmul(angle, ONE_OVER_2PI);   // angle/(2*pi) (実数値)
        frac_bits= n_frac[FRAC-1:0];            // 小数部 (2の補数の性質上, floor基準で常に0..1の範囲)
        idx      = frac_bits[FRAC-1 -: SIN_BITS]; // 上位SIN_BITSビット = 0..SIN_N-1
        return sin_lut_rom(idx);
    endfunction

    function automatic fixed_t cos_fx(input fixed_t angle);
        return sin_fx(angle + HALF_PI);
    endfunction

    // cosNoise(pos) = 0.5*(sin(pos.x)+sin(pos.y))  ※元コードの関数名はcosだが実装はsinを使用(元コード踏襲)
    function automatic fixed_t cos_noise(input fixed_t x, input fixed_t y);
        return fmul(HALF, sin_fx(x) + sin_fx(y));
    endfunction

    // ---- exp(-y) ROM (256エントリ, y=0..4.0, Q8.16) -------------------
`include "exp_lut.svh"

    // NOTE: idx = floor(y * (EXP_N-1) / EXP_Y_MAX) を、fmul経由(=固定小数点
    //       同士の乗算)ではなく「fixed_t(y) * 整数(EXP_N-1)」という広い
    //       中間幅の乗算として計算する。fmulを使うと結果の実数値(最大255程度)
    //       がQ8.16(最大約128)に収まらずオーバーフローするため。
    //       EXP_Y_MAX=4.0=2^2 なので、割り算は (FRAC+2) ビットの右シフトで済む。
    function automatic fixed_t exp_neg_fx(input fixed_t y);
        fixed_t yc;
        logic signed [2*WIDTH-1:0] numer;
        int unsigned idx;
        yc    = fclamp(y, ZERO, EXP_Y_MAX);
        numer = yc * (EXP_N-1);
        idx   = numer >>> (FRAC+2);
        if (idx > EXP_N-1) idx = EXP_N-1;
        return exp_lut_rom(idx);
    endfunction

endpackage : rm_pkg
