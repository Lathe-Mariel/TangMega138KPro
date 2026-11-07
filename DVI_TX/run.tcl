create_project -name DVI_TX -dir impl -pn GW5AST-LV138FPG676AC1/I0 -device_version C -force
add_file H:/git/TangMega138KPro/DVI_TX/src/top.sv
add_file H:/git/TangMega138KPro/DVI_TX/src/dvi_tx.v
add_file H:/git/TangMega138KPro/DVI_TX/src/gowin_pll_dvi/gowin_pll_dvi.v
add_file H:/git/TangMega138KPro/DVI_TX/src/gowin_pll_dvi/gowin_pll_dvi_mod.v
add_file H:/git/TangMega138KPro/DVI_TX/src/gowin_clkdiv/gowin_clkdiv.v
add_file H:/git/TangMega138KPro/DVI_TX/src/DVI.cst
run syn
