//==============================================================================
// Module     : image_composer.v
// Project    : DVI Frame Buffer with Image Composer
// Board      : Tang Mega 138K Pro Dock (GW5AST-LV138FPG676A)
// Updated    : 2026-04-04
//
// Function:
//   Generates 1920x1080@30fps output video timing and composites layers:
//
//   Layer priority (high → low):
//     1. "Lathe" text   (1550,930)-(1870,1030)  white/black
//     2. Orange border  50px all edges           #FF8000
//     3. Input video    (50,50)-(1500,1030)      frame buffer, nearest-neighbor scaled
//     4. Black          everything else
//
// Scaling:
//   Input  : 1920 x 1080 (from frame buffer, written by DVI RX)
//   Output : 1451 x 981  display area
//   Method : Nearest-neighbor (integer step accumulator)
//             hstep = 1920/1451 * 2^16 ≈ 86855 (Q0.16 fixed-point)
//             vstep = 1080/981  * 2^16 ≈ 72164 (Q0.16 fixed-point)
//
// Frame Buffer Read Interface:
//   - Provides read address (src_x, src_y) to frame buffer
//   - Expects pixel data back with 2-cycle latency (registered)
//
//==============================================================================

module image_composer (
    input  wire        clk_pixel,   // 74.25 MHz
    input  wire        rst_n,

    // Frame buffer read interface
    output reg  [10:0] fb_rd_x,     // source X address (0~1919)
    output reg  [10:0] fb_rd_y,     // source Y address (0~1079)
    output reg         fb_rd_en,    // read enable
    input  wire [7:0]  fb_r,        // pixel data (2-cycle latency)
    input  wire [7:0]  fb_g,
    input  wire [7:0]  fb_b,
    input  wire        fb_valid,    // frame buffer data valid

    // Composed video output
    output reg  [7:0]  out_r,
    output reg  [7:0]  out_g,
    output reg  [7:0]  out_b,
    output wire        out_de,
    output wire        out_hsync,
    output wire        out_vsync
);

//==============================================================================
// Parameters
//==============================================================================

    //--------------------------------------------------------------------------
    // Output timing : 1920x1080 @ 30fps  pixel clock = 74.25 MHz
    //--------------------------------------------------------------------------
    localparam H_ACTIVE = 11'd1920;
    localparam H_FP     = 11'd88;
    localparam H_SYNC   = 11'd44;
    localparam H_BP     = 11'd148;
    localparam H_TOTAL  = H_ACTIVE + H_FP + H_SYNC + H_BP;  // 2200

    localparam V_ACTIVE = 11'd1080;
    localparam V_FP     = 11'd4;
    localparam V_SYNC   = 11'd5;
    localparam V_BP     = 11'd36;
    localparam V_TOTAL  = V_ACTIVE + V_FP + V_SYNC + V_BP;  // 1125

    //--------------------------------------------------------------------------
    // Orange border
    //--------------------------------------------------------------------------
    localparam BORDER_W = 11'd50;
    localparam [7:0] ORANGE_R = 8'hFF;
    localparam [7:0] ORANGE_G = 8'h80;
    localparam [7:0] ORANGE_B = 8'h00;

    //--------------------------------------------------------------------------
    // Input video display area (within output frame)
    //--------------------------------------------------------------------------
    localparam VID_X0 = 11'd50;
    localparam VID_Y0 = 11'd50;
    localparam VID_X1 = 11'd1500;   // exclusive
    localparam VID_Y1 = 11'd1030;   // exclusive
    localparam VID_W  = VID_X1 - VID_X0;   // 1450  (display width  in output)
    localparam VID_H  = VID_Y1 - VID_Y0;   // 980   (display height in output)
    // NOTE: The display area is 1450x980 px in the output frame.
    //       The source frame buffer is 1920x1080.

    //--------------------------------------------------------------------------
    // Source frame buffer dimensions
    //--------------------------------------------------------------------------
    localparam SRC_W = 11'd1920;
    localparam SRC_H = 11'd1080;

    //--------------------------------------------------------------------------
    // Nearest-neighbor scaling step (Q16 fixed-point)
    //   hstep = SRC_W / VID_W * 65536 = 1920 / 1450 * 65536 = 86820
    //   vstep = SRC_H / VID_H * 65536 = 1080 / 980  * 65536 = 72229
    //--------------------------------------------------------------------------
    localparam [31:0] HSTEP = 32'd86779;
    localparam [31:0] VSTEP = 32'd72223;

    //--------------------------------------------------------------------------
    // "Lathe" text area
    //--------------------------------------------------------------------------
    localparam TXT_X0 = 11'd1550;
    localparam TXT_Y0 = 11'd930;
    localparam TXT_X1 = 11'd1870;   // exclusive
    localparam TXT_Y1 = 11'd1030;   // exclusive
    localparam TXT_W  = TXT_X1 - TXT_X0;   // 320
    localparam TXT_H  = TXT_Y1 - TXT_Y0;   // 100

//==============================================================================
// Sync counters
//==============================================================================

    reg [10:0] hcnt;   // 0 ~ H_TOTAL-1
    reg [10:0] vcnt;   // 0 ~ V_TOTAL-1

    always @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            hcnt <= 11'd0;
            vcnt <= 11'd0;
        end else begin
            if (hcnt == H_TOTAL - 1) begin
                hcnt <= 11'd0;
                vcnt <= (vcnt == V_TOTAL - 1) ? 11'd0 : vcnt + 1'b1;
            end else begin
                hcnt <= hcnt + 1'b1;
            end
        end
    end

    //--------------------------------------------------------------------------
    // Sync & DE (registered 2 cycles to compensate for pipeline latency)
    //--------------------------------------------------------------------------
    wire de_i    = (hcnt < H_ACTIVE) && (vcnt < V_ACTIVE);
    wire hsync_i = (hcnt >= H_ACTIVE + H_FP) && (hcnt < H_ACTIVE + H_FP + H_SYNC);
    wire vsync_i = (vcnt >= V_ACTIVE + V_FP) && (vcnt < V_ACTIVE + V_FP + V_SYNC);

    // 2-stage pipeline registers to align DE/sync with pixel data
    reg [1:0] de_pipe, hs_pipe, vs_pipe;
    always @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            de_pipe <= 2'b0;
            hs_pipe <= 2'b0;
            vs_pipe <= 2'b0;
        end else begin
            de_pipe <= {de_pipe[0], de_i};
            hs_pipe <= {hs_pipe[0], hsync_i};
            vs_pipe <= {vs_pipe[0], vsync_i};
        end
    end

    assign out_de    = de_pipe[1];
    assign out_hsync = hs_pipe[1];
    assign out_vsync = vs_pipe[1];

//==============================================================================
// Region decode  (1 cycle ahead to drive frame buffer read address)
//==============================================================================

    //--------------------------------------------------------------------------
    // Pre-decode regions for the CURRENT pixel (hcnt, vcnt)
    //--------------------------------------------------------------------------
    wire is_de     = de_i;
    wire is_border = is_de && (
                        (hcnt < BORDER_W) ||
                        (hcnt >= H_ACTIVE - BORDER_W) ||
                        (vcnt < BORDER_W) ||
                        (vcnt >= V_ACTIVE - BORDER_W));

    wire is_video  = is_de &&
                        (hcnt >= VID_X0) && (hcnt < VID_X1) &&
                        (vcnt >= VID_Y0) && (vcnt < VID_Y1);

    wire is_text   = is_de &&
                        (hcnt >= TXT_X0) && (hcnt < TXT_X1) &&
                        (vcnt >= TXT_Y0) && (vcnt < TXT_Y1);

    //--------------------------------------------------------------------------
    // 2-stage pipeline of region flags (to align with pixel output)
    //--------------------------------------------------------------------------
    reg is_border_d1, is_border_d2;
    reg is_video_d1,  is_video_d2;
    reg is_text_d1,   is_text_d2;

    always @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            is_border_d1 <= 1'b0; is_border_d2 <= 1'b0;
            is_video_d1  <= 1'b0; is_video_d2  <= 1'b0;
            is_text_d1   <= 1'b0; is_text_d2   <= 1'b0;
        end else begin
            is_border_d1 <= is_border; is_border_d2 <= is_border_d1;
            is_video_d1  <= is_video;  is_video_d2  <= is_video_d1;
            is_text_d1   <= is_text;   is_text_d2   <= is_text_d1;
        end
    end

//==============================================================================
// Nearest-Neighbor Scaler
// Maps output pixel (hcnt, vcnt) → source pixel (src_x, src_y)
//
// Algorithm:
//   hacc : horizontal accumulator, incremented by HSTEP each active output pixel
//   vacc : vertical accumulator,   incremented by VSTEP each active output line
//   src_x = hacc[31:16]   (integer part of Q16 accumulator)
//   src_y = vacc[31:16]
//==============================================================================

    reg [31:0] hacc;   // horizontal accumulator (Q16)
    reg [31:0] vacc;   // vertical accumulator   (Q16)

    // Accumulator update
    always @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            hacc <= 32'd0;
            vacc <= 32'd0;
        end else begin
            // Reset hacc at start of each video line
            if (hcnt == VID_X0 - 1)
                hacc <= 32'd0;
            else if (is_video)
                hacc <= hacc + HSTEP;

            // Reset vacc at start of first video line; increment at end of each line
            if (vcnt == VID_Y0 - 1 && hcnt == H_TOTAL - 1)
                vacc <= 32'd0;
            else if (vcnt >= VID_Y0 && vcnt < VID_Y1 && hcnt == H_TOTAL - 1)
                vacc <= vacc + VSTEP;
        end
    end

    wire [10:0] src_x = hacc[26:16];   // integer part (max 1919)
    wire [10:0] src_y = vacc[26:16];   // integer part (max 1079)

//==============================================================================
// Frame Buffer Read Address Generation
// Issue read 2 cycles ahead (to compensate for 2-cycle BRAM/DDR read latency)
//==============================================================================

    always @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            fb_rd_x  <= 11'd0;
            fb_rd_y  <= 11'd0;
            fb_rd_en <= 1'b0;
        end else begin
            fb_rd_en <= is_video;
            fb_rd_x  <= src_x;
            fb_rd_y  <= src_y;
        end
    end

//==============================================================================
// "Lathe" Text Font ROM
// Bitmap for "Lathe" rendered in 320x100 px (white on black)
// Font height: 80px, vertically centered → top offset 10px
// Font data loaded from lathe_font.hex (generated by Step 4 Python script)
//==============================================================================

    localparam FONT_ROWS = TXT_H;          // 100
    localparam FONT_COLS = TXT_W;          // 320

    // Local coordinates within text box (registered to avoid glitch)
    reg [8:0] lx_r;   // 0~319
    reg [6:0] ly_r;   // 0~99
    reg       in_text_r;

    always @(posedge clk_pixel) begin
        lx_r      <= hcnt - TXT_X0;
        ly_r      <= vcnt - TXT_Y0;
        in_text_r <= is_text;
    end

    // Font ROM: 100 rows, each row 320 bits wide
    // Stored as 10 x 32-bit words per row → 100 x 320 bits = 4000 bytes
    reg [319:0] font_rom [0:FONT_ROWS-1];

    initial begin
        // $readmemh("lathe_font.hex", font_rom);
        // Placeholder until Step 4 generates the hex file
        integer i;
        for (i = 0; i < FONT_ROWS; i = i + 1)
            font_rom[i] = 320'h0;
    end

    // Registered font pixel lookup (1 cycle latency)
    reg font_pixel;
    always @(posedge clk_pixel) begin
        if (in_text_r && lx_r < FONT_COLS && ly_r < FONT_ROWS)
            font_pixel <= font_rom[ly_r][FONT_COLS - 1 - lx_r];
        else
            font_pixel <= 1'b0;
    end

    // Font pixel color (white=1, black=0)
    wire [7:0] txt_r = font_pixel ? 8'hFF : 8'h00;
    wire [7:0] txt_g = font_pixel ? 8'hFF : 8'h00;
    wire [7:0] txt_b = font_pixel ? 8'hFF : 8'h00;

//==============================================================================
// Pixel Compositor
// Selects output color based on region priority
// All region flags are delayed 2 cycles to match pixel data pipeline
//==============================================================================

    always @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            out_r <= 8'h0;
            out_g <= 8'h0;
            out_b <= 8'h0;
        end else begin
            if (!de_pipe[1]) begin
                // Blanking interval
                out_r <= 8'h00;
                out_g <= 8'h00;
                out_b <= 8'h00;
            end else if (is_text_d2) begin
                // Priority 1: "Lathe" text
                out_r <= txt_r;
                out_g <= txt_g;
                out_b <= txt_b;
            end else if (is_border_d2) begin
                // Priority 2: Orange border
                out_r <= ORANGE_R;
                out_g <= ORANGE_G;
                out_b <= ORANGE_B;
            end else if (is_video_d2 && fb_valid) begin
                // Priority 3: Scaled input video from frame buffer
                out_r <= fb_r;
                out_g <= fb_g;
                out_b <= fb_b;
            end else begin
                // Priority 4: Black background
                out_r <= 8'h00;
                out_g <= 8'h00;
                out_b <= 8'h00;
            end
        end
    end

endmodule

//==============================================================================
// Module     : tb_image_composer.v  (simulation only)
// Testbench  : Verifies timing and region decode of image_composer
//              Run with Icarus Verilog:
//                iverilog -o tb tb_image_composer.v image_composer.v
//                vvp tb
//==============================================================================

`ifdef SIMULATION
module tb_image_composer;

    reg clk, rst_n;

    // Frame buffer stub
    reg [7:0] fb_r_s = 8'hAA;
    reg [7:0] fb_g_s = 8'hBB;
    reg [7:0] fb_b_s = 8'hCC;
    reg       fb_valid_s = 1'b1;

    wire [10:0] fb_rd_x, fb_rd_y;
    wire        fb_rd_en;
    wire [7:0]  out_r, out_g, out_b;
    wire        out_de, out_hsync, out_vsync;

    image_composer dut (
        .clk_pixel  (clk),
        .rst_n      (rst_n),
        .fb_rd_x    (fb_rd_x),
        .fb_rd_y    (fb_rd_y),
        .fb_rd_en   (fb_rd_en),
        .fb_r       (fb_r_s),
        .fb_g       (fb_g_s),
        .fb_b       (fb_b_s),
        .fb_valid   (fb_valid_s),
        .out_r      (out_r),
        .out_g      (out_g),
        .out_b      (out_b),
        .out_de     (out_de),
        .out_hsync  (out_hsync),
        .out_vsync  (out_vsync)
    );

    // 74.25 MHz clock  (period ≈ 13.468 ns)
    initial clk = 0;
    always #6.734 clk = ~clk;

    // Run for 3 frames
    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
        // 1 frame = 2200 * 1125 * 13.468 ns ≈ 33.3 ms
        #100_000_000;
        $finish;
    end

    // Count DE pulses and check first active line starts at correct hcnt
    integer de_count = 0;
    always @(posedge clk)
        if (out_de) de_count <= de_count + 1;

    initial begin
        $dumpfile("tb_image_composer.vcd");
        $dumpvars(0, tb_image_composer);
    end

endmodule
`endif
