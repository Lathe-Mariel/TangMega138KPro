module ddr3_controller #(
    parameter ADDR_W = 15,
    parameter BANK_W = 3
)(
    input  wire                  clk,
    input  wire                  rst_n,
    output reg  [ADDR_W-1:0]     ddr_addr,
    output reg  [BANK_W-1:0]     ddr_bank,
    output reg                   ddr_cs_n,
    output wire                  ddr_ras_n,
    output wire                  ddr_cas_n,
    output wire                  ddr_we_n,
    output reg                   ddr_cke,
    output reg                   ddr_odt,
    output reg                   ddr_reset_n,
    output reg  [3:0]            ddr_dm,
    inout  wire [31:0]           ddr_dq,
    output reg                   init_done
);

    localparam [2:0] CMD_NOP  = 3'b111;
    localparam [2:0] CMD_ACT  = 3'b011;
    localparam [2:0] CMD_READ = 3'b101;
    localparam [2:0] CMD_WR   = 3'b100;
    localparam [2:0] CMD_PRE  = 3'b010;
    localparam [2:0] CMD_REF  = 3'b001;
    localparam [2:0] CMD_MRS  = 3'b000;

    reg [2:0] cmd;

    reg [3:0] state;
    reg [19:0] timer;

    localparam S_RESET=4'd0, S_CKE=4'd1, S_MRS=4'd2, S_PRE=4'd3, S_REF=4'd4, S_READY=4'd5;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_RESET;
            timer        <= 20'd0;
            init_done    <= 1'b0;
            ddr_addr     <= {ADDR_W{1'b0}};
            ddr_bank     <= {BANK_W{1'b0}};
            ddr_cs_n     <= 1'b1;
            ddr_cke      <= 1'b0;
            ddr_odt      <= 1'b0;
            ddr_reset_n  <= 1'b0;
            ddr_dm       <= 4'b0;
            cmd          <= CMD_NOP;
        end else begin
            timer <= timer + 20'd1;
            case (state)
                S_RESET: begin
                    ddr_reset_n <= 1'b0;
                    ddr_cke     <= 1'b0;
                    cmd         <= CMD_NOP;
                    ddr_cs_n    <= 1'b1;
                    if (timer == 20'd1000) begin
                        ddr_reset_n <= 1'b1;
                        state <= S_CKE;
                        timer <= 20'd0;
                    end
                end
                S_CKE: begin
                    ddr_cke <= 1'b1;
                    if (timer == 20'd500) begin
                        state <= S_MRS;
                        timer <= 20'd0;
                    end
                end
                S_MRS: begin
                    ddr_cs_n <= 1'b0;
                    cmd      <= CMD_MRS;
                    ddr_bank <= 3'b0;
                    ddr_addr <= {ADDR_W{1'b0}};
                    if (timer == 20'd10) begin
                        cmd      <= CMD_NOP;
                        ddr_cs_n <= 1'b1;
                        state    <= S_PRE;
                        timer    <= 20'd0;
                    end
                end
                S_PRE: begin
                    ddr_cs_n <= 1'b0;
                    cmd      <= CMD_PRE;
                    ddr_addr[10] <= 1'b1;
                    if (timer == 20'd10) begin
                        cmd      <= CMD_NOP;
                        ddr_cs_n <= 1'b1;
                        state    <= S_REF;
                        timer    <= 20'd0;
                    end
                end
                S_REF: begin
                    ddr_cs_n <= 1'b0;
                    cmd      <= CMD_REF;
                    if (timer == 20'd10) begin
                        cmd      <= CMD_NOP;
                        ddr_cs_n <= 1'b1;
                        init_done <= 1'b1;
                        state     <= S_READY;
                        timer     <= 20'd0;
                    end
                end
                S_READY: begin
                    ddr_cs_n <= 1'b1;
                    cmd      <= CMD_NOP;
                    init_done <= 1'b1;
                end
                default: state <= S_RESET;
            endcase
        end
    end

    assign ddr_ras_n = cmd[2];
    assign ddr_cas_n = cmd[1];
    assign ddr_we_n  = cmd[0];
    assign ddr_dq     = 32'bz;
endmodule