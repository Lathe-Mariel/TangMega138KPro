module gw_gao(
    sd_cmd,
    sd_dat,
    sd_cs_n,
    \u_sd_reader/rx_byte_ready ,
    \u_sd_reader/state[3] ,
    \u_sd_reader/state[2] ,
    \u_sd_reader/state[1] ,
    \u_sd_reader/state[0] ,
    \u_sd_reader/cmd_sent ,
    \u_sd_reader/read_req ,
    \u_sd_reader/rx_byte[7] ,
    \u_sd_reader/rx_byte[6] ,
    \u_sd_reader/rx_byte[5] ,
    \u_sd_reader/rx_byte[4] ,
    \u_sd_reader/rx_byte[3] ,
    \u_sd_reader/rx_byte[2] ,
    \u_sd_reader/rx_byte[1] ,
    \u_sd_reader/rx_byte[0] ,
    \u_sd_reader/data_mode ,
    \u_sd_reader/r1_mode ,
    \u_sd_reader/rx_sr[7] ,
    \u_sd_reader/rx_sr[6] ,
    \u_sd_reader/rx_sr[5] ,
    \u_sd_reader/rx_sr[4] ,
    \u_sd_reader/rx_sr[3] ,
    \u_sd_reader/rx_sr[2] ,
    \u_sd_reader/rx_sr[1] ,
    \u_sd_reader/rx_sr[0] ,
    \u_sd_reader/rx_flag ,
    \u_sd_reader/rx_bit_cnt[2] ,
    \u_sd_reader/rx_bit_cnt[1] ,
    \u_sd_reader/rx_bit_cnt[0] ,
    \u_sd_reader/cmd_bit_cnt[5] ,
    \u_sd_reader/cmd_bit_cnt[4] ,
    \u_sd_reader/cmd_bit_cnt[3] ,
    \u_sd_reader/cmd_bit_cnt[2] ,
    \u_sd_reader/cmd_bit_cnt[1] ,
    \u_sd_reader/cmd_bit_cnt[0] ,
    \u_sd_reader/send_active ,
    \u_ddr3/init_calib_complete ,
    clk,
    tms_pad_i,
    tck_pad_i,
    tdi_pad_i,
    tdo_pad_o
);

input sd_cmd;
input sd_dat;
input sd_cs_n;
input \u_sd_reader/rx_byte_ready ;
input \u_sd_reader/state[3] ;
input \u_sd_reader/state[2] ;
input \u_sd_reader/state[1] ;
input \u_sd_reader/state[0] ;
input \u_sd_reader/cmd_sent ;
input \u_sd_reader/read_req ;
input \u_sd_reader/rx_byte[7] ;
input \u_sd_reader/rx_byte[6] ;
input \u_sd_reader/rx_byte[5] ;
input \u_sd_reader/rx_byte[4] ;
input \u_sd_reader/rx_byte[3] ;
input \u_sd_reader/rx_byte[2] ;
input \u_sd_reader/rx_byte[1] ;
input \u_sd_reader/rx_byte[0] ;
input \u_sd_reader/data_mode ;
input \u_sd_reader/r1_mode ;
input \u_sd_reader/rx_sr[7] ;
input \u_sd_reader/rx_sr[6] ;
input \u_sd_reader/rx_sr[5] ;
input \u_sd_reader/rx_sr[4] ;
input \u_sd_reader/rx_sr[3] ;
input \u_sd_reader/rx_sr[2] ;
input \u_sd_reader/rx_sr[1] ;
input \u_sd_reader/rx_sr[0] ;
input \u_sd_reader/rx_flag ;
input \u_sd_reader/rx_bit_cnt[2] ;
input \u_sd_reader/rx_bit_cnt[1] ;
input \u_sd_reader/rx_bit_cnt[0] ;
input \u_sd_reader/cmd_bit_cnt[5] ;
input \u_sd_reader/cmd_bit_cnt[4] ;
input \u_sd_reader/cmd_bit_cnt[3] ;
input \u_sd_reader/cmd_bit_cnt[2] ;
input \u_sd_reader/cmd_bit_cnt[1] ;
input \u_sd_reader/cmd_bit_cnt[0] ;
input \u_sd_reader/send_active ;
input \u_ddr3/init_calib_complete ;
input clk;
input tms_pad_i;
input tck_pad_i;
input tdi_pad_i;
output tdo_pad_o;

wire sd_cmd;
wire sd_dat;
wire sd_cs_n;
wire \u_sd_reader/rx_byte_ready ;
wire \u_sd_reader/state[3] ;
wire \u_sd_reader/state[2] ;
wire \u_sd_reader/state[1] ;
wire \u_sd_reader/state[0] ;
wire \u_sd_reader/cmd_sent ;
wire \u_sd_reader/read_req ;
wire \u_sd_reader/rx_byte[7] ;
wire \u_sd_reader/rx_byte[6] ;
wire \u_sd_reader/rx_byte[5] ;
wire \u_sd_reader/rx_byte[4] ;
wire \u_sd_reader/rx_byte[3] ;
wire \u_sd_reader/rx_byte[2] ;
wire \u_sd_reader/rx_byte[1] ;
wire \u_sd_reader/rx_byte[0] ;
wire \u_sd_reader/data_mode ;
wire \u_sd_reader/r1_mode ;
wire \u_sd_reader/rx_sr[7] ;
wire \u_sd_reader/rx_sr[6] ;
wire \u_sd_reader/rx_sr[5] ;
wire \u_sd_reader/rx_sr[4] ;
wire \u_sd_reader/rx_sr[3] ;
wire \u_sd_reader/rx_sr[2] ;
wire \u_sd_reader/rx_sr[1] ;
wire \u_sd_reader/rx_sr[0] ;
wire \u_sd_reader/rx_flag ;
wire \u_sd_reader/rx_bit_cnt[2] ;
wire \u_sd_reader/rx_bit_cnt[1] ;
wire \u_sd_reader/rx_bit_cnt[0] ;
wire \u_sd_reader/cmd_bit_cnt[5] ;
wire \u_sd_reader/cmd_bit_cnt[4] ;
wire \u_sd_reader/cmd_bit_cnt[3] ;
wire \u_sd_reader/cmd_bit_cnt[2] ;
wire \u_sd_reader/cmd_bit_cnt[1] ;
wire \u_sd_reader/cmd_bit_cnt[0] ;
wire \u_sd_reader/send_active ;
wire \u_ddr3/init_calib_complete ;
wire clk;
wire tms_pad_i;
wire tck_pad_i;
wire tdi_pad_i;
wire tdo_pad_o;
wire tms_i_c;
wire tck_i_c;
wire tdi_i_c;
wire tdo_o_c;
wire [9:0] control0;
wire gao_jtag_tck;
wire gao_jtag_reset;
wire run_test_idle_er1;
wire run_test_idle_er2;
wire shift_dr_capture_dr;
wire update_dr;
wire pause_dr;
wire enable_er1;
wire enable_er2;
wire gao_jtag_tdi;
wire tdo_er1;

IBUF tms_ibuf (
    .I(tms_pad_i),
    .O(tms_i_c)
);

IBUF tck_ibuf (
    .I(tck_pad_i),
    .O(tck_i_c)
);

IBUF tdi_ibuf (
    .I(tdi_pad_i),
    .O(tdi_i_c)
);

OBUF tdo_obuf (
    .I(tdo_o_c),
    .O(tdo_pad_o)
);

GW_JTAG  u_gw_jtag(
    .tms_pad_i(tms_i_c),
    .tck_pad_i(tck_i_c),
    .tdi_pad_i(tdi_i_c),
    .tdo_pad_o(tdo_o_c),
    .tck_o(gao_jtag_tck),
    .test_logic_reset_o(gao_jtag_reset),
    .run_test_idle_er1_o(run_test_idle_er1),
    .run_test_idle_er2_o(run_test_idle_er2),
    .shift_dr_capture_dr_o(shift_dr_capture_dr),
    .update_dr_o(update_dr),
    .pause_dr_o(pause_dr),
    .enable_er1_o(enable_er1),
    .enable_er2_o(enable_er2),
    .tdi_o(gao_jtag_tdi),
    .tdo_er1_i(tdo_er1),
    .tdo_er2_i(1'b0)
);

gw_con_top  u_icon_top(
    .tck_i(gao_jtag_tck),
    .tdi_i(gao_jtag_tdi),
    .tdo_o(tdo_er1),
    .rst_i(gao_jtag_reset),
    .control0(control0[9:0]),
    .enable_i(enable_er1),
    .shift_dr_capture_dr_i(shift_dr_capture_dr),
    .update_dr_i(update_dr)
);

ao_top_0  u_la0_top(
    .control(control0[9:0]),
    .trig0_i(\u_ddr3/init_calib_complete ),
    .trig2_i({\u_sd_reader/state[3] ,\u_sd_reader/state[2] ,\u_sd_reader/state[1] ,\u_sd_reader/state[0] }),
    .data_i({sd_cmd,sd_dat,sd_cs_n,\u_sd_reader/rx_byte_ready ,\u_sd_reader/state[3] ,\u_sd_reader/state[2] ,\u_sd_reader/state[1] ,\u_sd_reader/state[0] ,\u_sd_reader/cmd_sent ,\u_sd_reader/read_req ,\u_sd_reader/rx_byte[7] ,\u_sd_reader/rx_byte[6] ,\u_sd_reader/rx_byte[5] ,\u_sd_reader/rx_byte[4] ,\u_sd_reader/rx_byte[3] ,\u_sd_reader/rx_byte[2] ,\u_sd_reader/rx_byte[1] ,\u_sd_reader/rx_byte[0] ,\u_sd_reader/data_mode ,\u_sd_reader/r1_mode ,\u_sd_reader/rx_sr[7] ,\u_sd_reader/rx_sr[6] ,\u_sd_reader/rx_sr[5] ,\u_sd_reader/rx_sr[4] ,\u_sd_reader/rx_sr[3] ,\u_sd_reader/rx_sr[2] ,\u_sd_reader/rx_sr[1] ,\u_sd_reader/rx_sr[0] ,\u_sd_reader/rx_flag ,\u_sd_reader/rx_bit_cnt[2] ,\u_sd_reader/rx_bit_cnt[1] ,\u_sd_reader/rx_bit_cnt[0] ,\u_sd_reader/cmd_bit_cnt[5] ,\u_sd_reader/cmd_bit_cnt[4] ,\u_sd_reader/cmd_bit_cnt[3] ,\u_sd_reader/cmd_bit_cnt[2] ,\u_sd_reader/cmd_bit_cnt[1] ,\u_sd_reader/cmd_bit_cnt[0] ,\u_sd_reader/send_active }),
    .clk_i(clk)
);

endmodule
