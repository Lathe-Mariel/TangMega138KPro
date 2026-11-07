module top (
    input  wire clk,
    input  wire rst_n,
    output wire sd_clk,
    output wire sd_cmd,
    input  wire sd_dat,
    output wire sd_cs_n,
    output wire sd_dat1,
    output wire sd_dat2,
    output wire [5:0] state_led
);
    assign sd_dat1 = 1'b1;
    assign sd_dat2 = 1'b1;

    reg read_req;
    reg [31:0] block_addr = 0;
    wire [7:0] data;
    wire data_valid;
    wire busy;
    wire init_done;
    wire [2:0] debug_stage;

    sd_reader u_sd (
        .clk        (clk),
        .rst_n      (rst_n),
        .sd_clk     (sd_clk),
        .sd_cmd     (sd_cmd),
        .sd_dat     (sd_dat),
        .sd_cs_n    (sd_cs_n),
        .read_req   (read_req),
        .block_addr (block_addr),
        .data       (data),
        .data_valid (data_valid),
        .busy       (busy),
        .init_done  (init_done),
        .debug_stage(debug_stage)
    );

    // trigger one block read after SD init
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) read_req <= 0;
        else if (init_done && !busy) read_req <= 1;
        else read_req <= 0;
    end

    assign state_led = {init_done, busy, data_valid, debug_stage};
endmodule