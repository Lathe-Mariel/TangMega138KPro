`timescale 1ns/1ps
module tb;
    reg clk = 0;
    reg rst_n = 0;
    wire [14:0] ddr_addr;
    wire [2:0]  ddr_bank;
    wire ddr_cs_n, ddr_ras_n, ddr_cas_n, ddr_we_n, ddr_ck, ddr_ck_n, ddr_cke, ddr_odt, ddr_reset_n;
    wire [3:0] ddr_dm;
    wire [31:0] ddr_dq;
    wire [3:0] ddr_dqs, ddr_dqs_n;
    wire [5:0] state_led;

    // ddr_dq high-z external
    assign ddr_dq = 32'bz;
    assign ddr_dqs = 4'bz;
    assign ddr_dqs_n = 4'bz;

    top dut (
        .clk(clk), .rst_n(rst_n),
        .ddr_addr(ddr_addr), .ddr_bank(ddr_bank),
        .ddr_cs_n(ddr_cs_n), .ddr_ras_n(ddr_ras_n), .ddr_cas_n(ddr_cas_n), .ddr_we_n(ddr_we_n),
        .ddr_ck(ddr_ck), .ddr_ck_n(ddr_ck_n), .ddr_cke(ddr_cke), .ddr_odt(ddr_odt), .ddr_reset_n(ddr_reset_n),
        .ddr_dm(ddr_dm), .ddr_dq(ddr_dq), .ddr_dqs(ddr_dqs), .ddr_dqs_n(ddr_dqs_n), .state_led(state_led)
    );

    always #10 clk = ~clk; // 50MHz

    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
        #60000;
        $display("state_led=%b", state_led);
        $finish;
    end
endmodule