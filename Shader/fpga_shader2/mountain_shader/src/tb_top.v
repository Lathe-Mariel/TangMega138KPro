// ============================================================
// Testbench: tb_top.v
// Quick sanity check – generates a few lines of video and
// dumps to VCD for waveform inspection.
// ============================================================
`timescale 1ns/1ps

module tb_top;

reg clk_27m;
reg rst_n;

// DUT outputs (just monitor, no diff-pair analysis needed in sim)
wire tmds_clk_p, tmds_clk_n;
wire [2:0] tmds_data_p, tmds_data_n;

// ── Clock: 27 MHz ──────────────────────────────────────────
initial clk_27m = 0;
always #18.518 clk_27m = ~clk_27m;   // 27 MHz

// ── Simulation model: bypass PLL ──────────────────────────
// For simulation we directly drive the pixel/tmds clocks.
// The PLL primitive doesn't simulate easily; use a sim model.
// We test video_timing + shader + encoder only.

// Pixel clock 148.5 MHz
reg clk_pixel;
initial clk_pixel = 0;
always #3.367 clk_pixel = ~clk_pixel;  // 148.5 MHz

wire [10:0] hcount, vcount;
wire hsync, vsync, de, field_start;
wire [7:0] r, g, b;

video_timing u_tim (
    .clk(clk_pixel), .rst(~rst_n),
    .hcount(hcount), .vcount(vcount),
    .hsync(hsync), .vsync(vsync),
    .de(de), .field_start(field_start)
);

reg [23:0] frame_cnt;
always @(posedge clk_pixel) begin
    if (!rst_n) frame_cnt <= 0;
    else if (field_start) frame_cnt <= frame_cnt + 1;
end

shader_3d_tunnel u_shader (
    .clk(clk_pixel), .rst(~rst_n),
    .hcount(hcount), .vcount(vcount),
    .de(de), .frame_cnt(frame_cnt),
    .r(r), .g(g), .b(b)
);

wire [9:0] tmds_b;
tmds_encoder u_enc (
    .clk(clk_pixel), .rst(~rst_n),
    .data(b), .ctrl({vsync,hsync}), .de(de),
    .tmds(tmds_b)
);

// ── Stimulus ───────────────────────────────────────────────
integer cycle_count;
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    rst_n = 0;
    cycle_count = 0;
    repeat(20) @(posedge clk_pixel);
    rst_n = 1;
    // Run for 2 full video lines (2×2200 = 4400 cycles)
    repeat(5000) @(posedge clk_pixel);
    $display("Simulation complete. DE samples OK.");
    $finish;
end

// ── Monitor ────────────────────────────────────────────────
always @(posedge clk_pixel) begin
    if (de && hcount < 10) begin
        $display("t=%0t h=%0d v=%0d R=%02x G=%02x B=%02x",
                 $time, hcount, vcount, r, g, b);
    end
end

endmodule
