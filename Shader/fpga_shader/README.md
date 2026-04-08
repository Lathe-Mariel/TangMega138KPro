# DVI 3D Space Tunnel Shader – Tang Mega 138K Pro Dock

リアルタイム3Dトンネル飛行シェーダーをFPGA上でDVI出力するデザインです。

## エフェクト概要

```
      ████████████████████
    ██  ░░░╔══════╗░░░  ██    ← ネオンリング（白フラッシュ）
   █  ░░╔══╝      ╚══╗░░  █
  █  ░╔═╝  ↑ 奥行き  ╚═╗░  █   ← 回転する色相グラデーション
  █  ╔╝    ██████████  ╚╗  █
  █  ║   ██ 中心=遠方██   ║  █   ← 擬似atan2アングル計算
  █  ╚╗    ██████████  ╔╝  █
  █  ░╚═╗  ↓ 近 い  ╔═╝░  █   ← 16スポーク グリッド
   █  ░░╚══╗      ╔══╝░░  █
    ██  ░░░╚══════╝░░░  ██    ← 深度逆数＝明るさ
      ████████████████████
```

## ファイル構成

```
dvi_shader/
├── src/
│   ├── top.v                # トップモジュール（クロック・接続）
│   ├── video_timing.v       # 1920×1080@30Hz タイミング生成
│   ├── shader_3d_tunnel.v   # シェーダーコア（3ステージパイプライン）
│   ├── tmds_encoder.v       # TMDS符号化（DVI 1.0準拠）
│   ├── tmds_serializer.v    # OSER10 + ELVDS_OBUF シリアライザ
│   └── pll_hdmi.v           # PLLVR ラッパー（27→148.5/742.5 MHz）
├── constraints/
│   ├── tang_mega138k.cst    # 物理ピン割当
│   └── timing.sdc           # タイミング制約
├── sim/
│   └── tb_top.v             # シミュレーションテストベンチ
└── dvi_shader.gprj          # Gowin IDE プロジェクトファイル
```

## ハードウェア仕様

| 項目 | 値 |
|------|-----|
| ボード | Tang Mega 138K Pro Dock |
| デバイス | GW5AST-LV138FPG676AES (Arora-V) |
| 解像度 | 1920×1080 @ 30Hz |
| ピクセルクロック | 148.5 MHz |
| TMDSシリアルクロック | 742.5 MHz (×5) |
| 色深度 | 24bit RGB |
| インターフェース | DVI/HDMI (TMDS LVDS) |

## タイミングパラメータ（CEA-861 1080p30）

```
水平: Active=1920  FP=88  Sync=44(+)  BP=148  Total=2200
垂直: Active=1080  FP=4   Sync=5(+)   BP=36   Total=1125
```

## シェーダーアルゴリズム

```
Stage 0 (1 cycle):
  nx = hcount - 960   (スクリーン中心からの変位)
  ny = vcount - 540

Stage 1 (1 cycle):
  r² = nx² + ny²                      (半径の2乗)
  angle = atan2近似(ny, nx) → 0..255 (擬似角度)
  depth = 256 >> (log2(r²) / 2)       (1/sqrt(r²) 近似)
  ring_phase = (depth + frame_cnt) & 0xFF  (スクロールするリング)

Stage 2 (1 cycle):
  hue = sin_lut[angle + time/4]       (回転する色相)
  bright = depth²/256                 (奥=暗い、手前=明るい)
  color = hue × bright                (ネオンカラー)
  + ring_flash (depth mod 32 < 3)     (白いリング)
  + spoke (angle mod 16 == 0)         (グリッドライン)
  + star (r² < 64)                    (中心の星)
```

## ビルド手順

### Gowin EDA (推奨)

1. Gowin FPGA Designer をインストール（v1.9.9以降）
2. `dvi_shader.gprj` を開く
3. **Synthesis** → **Place & Route** → **Generate Bitstream**
4. プログラマで `.fs` ファイルを書き込む

### IP Coreの確認

`pll_hdmi.v` の `PLLVR` パラメータはボードの実際の
クロック仕様に合わせて Gowin IP Core Generator で
再生成することを推奨：

```
Tools → IP Core Generator → Clock → PLLVR
  CLKIN = 27 MHz
  CLKOUT0 = 148.5 MHz (pixel)
  CLKOUT1 = 742.5 MHz (TMDS)
```

## シミュレーション

```bash
iverilog -g2012 -o sim/tb_top.vvp \
  src/video_timing.v src/shader_3d_tunnel.v src/tmds_encoder.v \
  sim/tb_top.v

vvp sim/tb_top.vvp
# → tb_top.vcd を GTKWave 等で確認
```

## ピン割当（要確認）

> ⚠️ **重要**: `constraints/tang_mega138k.cst` のピン番号は
> Sipeed公式スキマティック（Tang Mega 138K Pro Dock Rev.X）
> で必ず確認してください。誤ったLVDSピン配線はデバイス損傷の
> 原因になります。

| 信号 | ピン (P) | ピン (N) |
|------|----------|----------|
| TMDS CLK | K27 | K28 |
| TMDS D0 (B) | N27 | N28 |
| TMDS D1 (G) | M27 | M28 |
| TMDS D2 (R) | L27 | L28 |
| clk_27m | H11 | – |
| rst_n | T10 | – |

## 拡張アイデア

- **BRAM LUT**: sin/cosテーブルをBRAMに移してFmax向上
- **分割除算器**: atan2の除算をパイプライン化してfmax改善
- **音楽同期**: I²S入力で音のビートに反応するリング
- **パラメータUI**: UARTでリアルタイムにカラーパレット変更
