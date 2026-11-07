create_project -name DDR3 -dir impl -pn GW5AST-LV138FPG676AC1/I0 -device_version C -force
add_file H:/git/TangMega138KPro/DDR3/src/top.sv
add_file H:/git/TangMega138KPro/DDR3/src/gowin_pll/gowin_pll.v
add_file H:/git/TangMega138KPro/DDR3/src/ddr3_memory_interface/ddr3_memory_interface.v
add_file H:/git/TangMega138KPro/DDR3/src/DDR3.cst
add_file H:/git/TangMega138KPro/DDR3/src/DDR3.sdc
run all
