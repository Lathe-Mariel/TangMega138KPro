# DDR3 on Tang Mega 138K Pro (Gowin IP版)

自作 PHY は断念し、Gowin DDR3 Memory Interface IP を使用した構成に戻しました。

- `src/top.sv` : IP bring-up (LED で init_calib_complete 表示)
- `src/ddr3_memory_interface/` : Gowin DDR3 IF IP
- `src/gowin_pll/` : メモリ PLL

## 検証済み
- Gowin 合成: 成功
- IP は `CLK_RATIO=1:4` / 400MHz memory_clk 構成
EOF