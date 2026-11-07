create_project -name VFB_DVI -dir impl -pn GW5AST-LV138FPG676AC1/I0 -device_version C -force
add_file H:/git/TangMega138KPro/VFB_DVI/src/top.v
add_file H:/git/TangMega138KPro/VFB_DVI/src/sd_reader.sv
add_file H:/git/TangMega138KPro/VFB_DVI/src/bmp_parser.sv
add_file H:/git/TangMega138KPro/VFB_DVI/src/frame_writer.sv
add_file H:/git/TangMega138KPro/VFB_DVI/src/video_frame_buffer.v
add_file H:/git/TangMega138KPro/VFB_DVI/src/ddr3_memory_interface/ddr3_memory_interface.v
add_file H:/git/TangMega138KPro/VFB_DVI/src/gowin_pll/gowin_pll.v
add_file H:/git/TangMega138KPro/VFB_DVI/src/gowin_pll_dvi/gowin_pll_dvi.v
add_file H:/git/TangMega138KPro/VFB_DVI/src/gowin_pll_dvi/gowin_pll_dvi_mod.v
add_file H:/git/TangMega138KPro/VFB_DVI/src/gowin_clkdiv.v
add_file H:/git/TangMega138KPro/VFB_DVI/src/dvi_tx.v
add_file H:/git/TangMega138KPro/VFB_DVI/src/VFB_DVI.cst
run syn
