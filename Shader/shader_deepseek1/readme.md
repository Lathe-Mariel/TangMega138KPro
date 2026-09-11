tang_mega_138k_dvi/
├── src/
│   ├── top.sv           … トップモジュール
│   ├── pll.sv           … PLL (50MHz → 40MHz / 400MHz)
│   ├── vga_timing.sv    … タイミングジェネレータ (800x600@60Hz)
│   ├── color_bar.sv     … 7色カラーバー生成
│   ├── tmds_encoder.sv  … TMDSエンコーダ
│   ├── oser16_wrap.sv   … 10:1シリアライザ (OSER16)
│   └── dvi_tx.sv        … DVI送信 (シリアライズ+LVDS出力)
├── constraints/
│   └── tang_mega_138k_pro.cst
└── README.md