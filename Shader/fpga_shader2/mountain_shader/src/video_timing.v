// ============================================================
// Video Timing Generator
// 1280×720 @ 30 Hz  Pixel Clock: 37.125 MHz
//
// CEA-861 720p ブランキング (30 Hz = 60 Hz の半フレームレート)
// H: Active=1280  FP=110  Sync=40(+)  BP=220  Total=1650
// V: Active=720   FP=5    Sync=5(+)   BP=20   Total=750
// Pixel clock: 37.125 MHz
// Frame rate:  37.125 MHz / (1650 × 750) = 30.000 Hz
// Hsync/Vsync polarity: positive
// ============================================================
module video_timing (
    input  wire        clk,
    input  wire        rst,
    output reg  [11:0] hcount,      // 0 .. H_TOTAL-1  (max 1649, 11bit)
    output reg  [10:0] vcount,      // 0 .. V_TOTAL-1  (max 749,  10bit)
    output wire        hsync,
    output wire        vsync,
    output wire        de,           // data enable (active area)
    output reg         field_start   // one-cycle pulse at start of frame
);

// ── Timing parameters ──────────────────────────────────────
localparam H_ACTIVE = 1280;
localparam H_FP     = 110;
localparam H_SYNC   = 40;
localparam H_BP     = 220;
localparam H_TOTAL  = H_ACTIVE + H_FP + H_SYNC + H_BP; // 1650

localparam V_ACTIVE = 720;
localparam V_FP     = 5;
localparam V_SYNC   = 5;
localparam V_BP     = 20;
localparam V_TOTAL  = V_ACTIVE + V_FP + V_SYNC + V_BP;  // 750


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
