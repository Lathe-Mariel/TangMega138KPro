module gw_gao(
    pll_phase_lock,
    \pll_phase[3] ,
    \pll_phase[2] ,
    \pll_phase[1] ,
    \pll_phase[0] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/Align_sta[3] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/Align_sta[2] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/Align_sta[1] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/Align_sta[0] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/pllps[3] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/pllps[2] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/pllps[1] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/pllps[0] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[15] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[14] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[13] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[12] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[11] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[10] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[9] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[8] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[7] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[6] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[5] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[4] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[3] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[2] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[1] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[0] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/judge_cnt[4] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/judge_cnt[3] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/judge_cnt[2] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/judge_cnt[1] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/judge_cnt[0] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_flag ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_flag_d1 ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start[3] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start[2] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start[1] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start[0] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start_r[3] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start_r[2] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start_r[1] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start_r[0] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_diff[3] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_diff[2] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_diff[1] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_diff[0] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/confim_phase[3] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/confim_phase[2] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/confim_phase[1] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/confim_phase[0] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_cnt[3] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_cnt[2] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_cnt[1] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_cnt[0] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_num[3] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_num[2] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_num[1] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_num[0] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/seam_cnt[2] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/seam_cnt[1] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/seam_cnt[0] ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/ali_match ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/ali_match_d1 ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/ali_match_d2 ,
    \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/HDMI_CLK ,
    tms_pad_i,
    tck_pad_i,
    tdi_pad_i,
    tdo_pad_o
);

input pll_phase_lock;
input \pll_phase[3] ;
input \pll_phase[2] ;
input \pll_phase[1] ;
input \pll_phase[0] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/Align_sta[3] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/Align_sta[2] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/Align_sta[1] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/Align_sta[0] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/pllps[3] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/pllps[2] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/pllps[1] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/pllps[0] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[15] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[14] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[13] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[12] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[11] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[10] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[9] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[8] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[7] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[6] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[5] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[4] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[3] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[2] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[1] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[0] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/judge_cnt[4] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/judge_cnt[3] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/judge_cnt[2] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/judge_cnt[1] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/judge_cnt[0] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_flag ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_flag_d1 ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start[3] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start[2] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start[1] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start[0] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start_r[3] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start_r[2] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start_r[1] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start_r[0] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_diff[3] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_diff[2] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_diff[1] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_diff[0] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/confim_phase[3] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/confim_phase[2] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/confim_phase[1] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/confim_phase[0] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_cnt[3] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_cnt[2] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_cnt[1] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_cnt[0] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_num[3] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_num[2] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_num[1] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_num[0] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/seam_cnt[2] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/seam_cnt[1] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/seam_cnt[0] ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/ali_match ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/ali_match_d1 ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/ali_match_d2 ;
input \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/HDMI_CLK ;
input tms_pad_i;
input tck_pad_i;
input tdi_pad_i;
output tdo_pad_o;

wire pll_phase_lock;
wire \pll_phase[3] ;
wire \pll_phase[2] ;
wire \pll_phase[1] ;
wire \pll_phase[0] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/Align_sta[3] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/Align_sta[2] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/Align_sta[1] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/Align_sta[0] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/pllps[3] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/pllps[2] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/pllps[1] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/pllps[0] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[15] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[14] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[13] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[12] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[11] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[10] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[9] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[8] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[7] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[6] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[5] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[4] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[3] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[2] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[1] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[0] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/judge_cnt[4] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/judge_cnt[3] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/judge_cnt[2] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/judge_cnt[1] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/judge_cnt[0] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_flag ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_flag_d1 ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start[3] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start[2] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start[1] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start[0] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start_r[3] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start_r[2] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start_r[1] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start_r[0] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_diff[3] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_diff[2] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_diff[1] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_diff[0] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/confim_phase[3] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/confim_phase[2] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/confim_phase[1] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/confim_phase[0] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_cnt[3] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_cnt[2] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_cnt[1] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_cnt[0] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_num[3] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_num[2] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_num[1] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_num[0] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/seam_cnt[2] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/seam_cnt[1] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/seam_cnt[0] ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/ali_match ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/ali_match_d1 ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/ali_match_d2 ;
wire \DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/HDMI_CLK ;
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
    .trig0_i({\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/Align_sta[3] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/Align_sta[2] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/Align_sta[1] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/Align_sta[0] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/pllps[3] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/pllps[2] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/pllps[1] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/pllps[0] }),
    .trig1_i({\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/ali_match ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/ali_match_d1 ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/ali_match_d2 ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/seam_cnt[2] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/seam_cnt[1] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/seam_cnt[0] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_cnt[3] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_cnt[2] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_cnt[1] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_cnt[0] }),
    .data_i({pll_phase_lock,\pll_phase[3] ,\pll_phase[2] ,\pll_phase[1] ,\pll_phase[0] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/Align_sta[3] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/Align_sta[2] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/Align_sta[1] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/Align_sta[0] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/pllps[3] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/pllps[2] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/pllps[1] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/pllps[0] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[15] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[14] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[13] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[12] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[11] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[10] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[9] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[8] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[7] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[6] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[5] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[4] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[3] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[2] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[1] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_flag[0] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/judge_cnt[4] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/judge_cnt[3] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/judge_cnt[2] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/judge_cnt[1] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/judge_cnt[0] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_flag ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_flag_d1 ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start[3] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start[2] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start[1] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start[0] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start_r[3] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start_r[2] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start_r[1] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phs_start_r[0] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_diff[3] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_diff[2] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_diff[1] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/phase_diff[0] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/confim_phase[3] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/confim_phase[2] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/confim_phase[1] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/confim_phase[0] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_cnt[3] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_cnt[2] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_cnt[1] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_cnt[0] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_num[3] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_num[2] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_num[1] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/align_num[0] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/seam_cnt[2] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/seam_cnt[1] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/seam_cnt[0] ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/ali_match ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/ali_match_d1 ,\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/ali_match_d2 }),
    .clk_i(\DVI_RX_Top_inst/dvi2rgb_inst/u_Data_Aligning_Auto/HDMI_CLK )
);

endmodule
