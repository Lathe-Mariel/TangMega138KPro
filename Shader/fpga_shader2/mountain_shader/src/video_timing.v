// ============================================================
// Video Timing Generator
// 1920×1080 @ 30 Hz  Pixel Clock: 148.5 MHz (÷2 from 297MHz)
//
// H: Active=1920  FP=88  Sync=44  BP=148  Total=2200
// V: Active=1080  FP=4   Sync=5   BP=36   Total=1125
// Hsync/Vsync polarity: positive
// ============================================================
module video_timing (
    input  wire        clk,
    input  wire        rst,
    output reg  [10:0] hcount,      // 0 .. H_TOTAL-1
    output reg  [10:0] vcount,      // 0 .. V_TOTAL-1
    output wire        hsync,
    output wire        vsync,
    output wire        de,           // data enable (active area)
    output reg         field_start   // one-cycle pulse at start of frame
);

// ── Timing parameters ──────────────────────────────────────
localparam H_ACTIVE = 1920;
localparam H_FP     = 88;
localparam H_SYNC   = 44;
localparam H_BP     = 148;
localparam H_TOTAL  = H_ACTIVE + H_FP + H_SYNC + H_BP; // 2200

localparam V_ACTIVE = 1080;
localparam V_FP     = 4;
localparam V_SYNC   = 5;
localparam V_BP     = 36;
localparam V_TOTAL  = V_ACTIVE + V_FP + V_SYNC + V_BP;  // 1125

// ── Sync windows ───────────────────────────────────────────
// HSync: after active + FP  (pixel 2008..2051)
localparam H_SYNC_START = H_ACTIVE + H_FP;              // 2008
localparam H_SYNC_END   = H_SYNC_START + H_SYNC;        // 2052

// VSync: after active + FP  (line 1084..1088)
localparam V_SYNC_START = V_ACTIVE + V_FP;              // 1084
localparam V_SYNC_END   = V_SYNC_START + V_SYNC;        // 1089

// ── Counters ───────────────────────────────────────────────
always @(posedge clk or posedge rst) begin
    if (rst) begin
        hcount      <= 0;
        vcount      <= 0;
        field_start <= 0;
    end else begin
        field_start <= 0;
        if (hcount == H_TOTAL - 1) begin
            hcount <= 0;
            if (vcount == V_TOTAL - 1) begin
                vcount      <= 0;
                field_start <= 1;
            end else begin
                vcount <= vcount + 1;
            end
        end else begin
            hcount <= hcount + 1;
        end
    end
end

// ── Output signals ─────────────────────────────────────────
assign hsync = (hcount >= H_BP) && (hcount < (H_BP + H_SYNC));
assign vsync = (vcount >= V_BP) && (vcount < (V_BP + V_SYNC));
assign de    = (hcount > (H_BP + H_SYNC)) && (hcount < (H_BP+H_SYNC + H_ACTIVE)) && (vcount > (V_BP + V_SYNC)) && (vcount < (V_BP + V_SYNC + V_ACTIVE));

endmodule
