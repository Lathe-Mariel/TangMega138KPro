// ==========================================================================
//  Custom DDR3 controller scaffold (fully hand-written, no Gowin IP).
//  Target: GW5AST (Tang Mega 138K Pro).  Note: DDR3 DQS training and
//  board-level timing are NOT implemented; this is a structural/functional
//  starting point for synthesis, not a verified memory interface.
// ==========================================================================
module ddr3_controller #(
    parameter int ADDR_W = 15,
    parameter int BANK_W = 3
)(
    input  wire                  clk,
    input  wire                  rst_n,
    output reg  [ADDR_W-1:0]     ddr_addr,
    output reg  [BANK_W-1:0]     ddr_bank,
    output reg                   ddr_cs_n,
    output reg                   ddr_ras_n,
    output reg                   ddr_cas_n,
    output reg                   ddr_we_n,
    output reg                   ddr_cke,
    output reg                   ddr_odt,
    output reg                   ddr_reset_n,
    output reg  [3:0]            ddr_dm,
    inout  wire [31:0]           ddr_dq,
    output reg                   init_done
);

    // DDR3 command encoding (RAS,CAS,WE)
    localparam logic [2:0] CMD_NOP  = 3'b111;
    localparam logic [2:0] CMD_ACT  = 3'b011; // Activate
    localparam logic [2:0] CMD_READ = 3'b101;
    localparam logic [2:0] CMD_WR   = 3'b100;
    localparam logic [2:0] CMD_PRE  = 3'b010;
    localparam logic [2:0] CMD_REF  = 3'b001;
    localparam logic [2:0] CMD_MRS  = 3'b000;

    reg [2:0] cmd; // ras,cas,we
    assign {ddr_ras_n, ddr_cas_n, ddr_we_n} = cmd;

    // Simple init FSM
    typedef enum logic [3:0] {S_RESET, S_CKE, S_MRS, S_PRE, S_REF, S_READY} state_t;
    state_t state;
    reg [19:0] timer;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_RESET;
            timer        <= 20'd0;
            init_done    <= 1'b0;
            ddr_addr     <= '0;
            ddr_bank     <= '0;
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
                    if (timer == 20'd1000) begin // ~20us @ 50MHz
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
                    ddr_addr <= 15'b0; // MRS word could be refined
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
                    ddr_addr[10] <= 1'b1; // precharge all
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
                    // Idle refresh stub
                    ddr_cs_n <= 1'b1;
                    cmd      <= CMD_NOP;
                    init_done <= 1'b1;
                end
                default: state <= S_RESET;
            endcase
        end
    end

    // DQ handling left high-Z
    assign ddr_dq = 32'bz;
endmodule