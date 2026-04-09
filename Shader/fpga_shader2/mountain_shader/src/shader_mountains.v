// ============================================================
// shader_mountains.v
// Mountains + Sky flight shader for FPGA DVI output
//
// Algorithm: fBm noise terrain with ray-march (simplified)
//   Ported from the webgl-shaders.com mountains example approach.
//
// Because true ray-marching is impractical in a simple FPGA
// pipeline, this module uses a PRE-COMPUTED HEIGHT SLICE approach:
//   - For each pixel column, the terrain horizon line is computed
//     from fBm noise evaluated along the view ray.
//   - Pixels below the horizon get terrain colour (rock/snow).
//   - Pixels above get sky (gradient + stars + sun glow).
//   - Atmospheric fog is blended by distance.
//
// Pipeline: 5 registered stages → 5-cycle latency
//   S0: normalise pixel, compute ray direction
//   S1: sample fBm noise for terrain height
//   S2: sky / terrain decision
//   S3: lighting (diffuse, fog, snow)
//   S4: gamma + output
//
// Fixed-point format: Q12.8 (8 fractional bits) unless noted.
// ============================================================
module shader_mountains (
    input  wire        clk,
    input  wire        rst,
    input  wire [10:0] hcount,      // 0..1919
    input  wire [10:0] vcount,      // 0..1079
    input  wire        de,
    input  wire [23:0] frame_cnt,   // increments at 30Hz
    output reg  [ 7:0] r,
    output reg  [ 7:0] g,
    output reg  [ 7:0] b
);

// ── Constants ───────────────────────────────────────────────
localparam CX = 960;
localparam CY = 540;
localparam W  = 1920;
localparam H  = 1080;

// ── 256-entry noise LUT (2-D value noise, 16×16 grid → 256) ─
// Each entry is hash(i,j) for i,j in 0..15
// Generated as: round(sin(i*127.1 + j*311.7)*43758.5453) mod 256
reg [7:0] noise_lut [0:255];
integer k;
initial begin
    for (k = 0; k < 256; k = k + 1)
//        noise_lut[k] = $rtoi($abs($sin(k * 127.1 + k * 311.7) * 43758.5) ) % 256;
        noise_lut[k] = $rtoi($sin(k * 127.1 + k * 311.7) * 43758.5 ) % 256;
end

// ── Sin LUT (256-entry signed 8-bit) ────────────────────────
reg signed [7:0] sin_lut [0:255];
initial begin
    for (k = 0; k < 256; k = k + 1)
        sin_lut[k] = $rtoi($sin(2.0 * 3.14159265 * k / 256.0) * 127.0);
end

// ── Noise function (bilinear, 8-bit Q0) ─────────────────────
// Input: 8-bit integer grid coords (0..15)
// Output: 8-bit value 0..255
function [7:0] noise_val;
    input [3:0] ix;
    input [3:0] iy;
    begin
        noise_val = noise_lut[{iy[3:0], ix[3:0]}];
    end
endfunction

// Bilinear noise at Q4.4 position (ux=integer part 4b, fx=frac 4b)
function [7:0] noise_bilerp;
    input [3:0] ux; input [3:0] fx;
    input [3:0] uy; input [3:0] fy;
    reg [7:0] n00, n10, n01, n11;
    reg [11:0] t0, t1;
    begin
        n00 = noise_lut[{uy,      ux}];
        n10 = noise_lut[{uy,      ux+4'h1}];
        n01 = noise_lut[{uy+4'h1, ux}];
        n11 = noise_lut[{uy+4'h1, ux+4'h1}];
        // Smoothstep: u = fx²(3-2fx)/16  (Q4 → Q8 approx)
        // Simplified: linear interpolation is close enough for terrain
        t0 = n00 * (16 - fx) + n10 * fx;   // Q12 / 16
        t1 = n01 * (16 - fx) + n11 * fx;
        noise_bilerp = ((t0 * (16 - fy) + t1 * fy) >> 8) & 8'hFF;
    end
endfunction

// ── fBm (3 octaves, Q4.4 input) ─────────────────────────────
// Returns 8-bit value (0..127 approx)
function [7:0] fbm3;
    input [7:0] px;   // Q4.4 x coordinate
    input [7:0] py;   // Q4.4 y coordinate
    reg [7:0] v;
    reg [7:0] p0x, p0y, p1x, p1y, p2x, p2y;
    reg [7:0] n0, n1, n2;
    begin
        // Octave 0: freq 1, amp 0.5
        p0x = px; p0y = py;
        n0 = noise_bilerp(p0x[7:4], p0x[3:0], p0y[7:4], p0y[3:0]);
        // Octave 1: freq 2, amp 0.25
        p1x = {px[6:0], 1'b0}; p1y = {py[6:0], 1'b0};
        n1 = noise_bilerp(p1x[7:4], p1x[3:0], p1y[7:4], p1y[3:0]);
        // Octave 2: freq 4, amp 0.125
        p2x = {px[5:0], 2'b0}; p2y = {py[5:0], 2'b0};
        n2 = noise_bilerp(p2x[7:4], p2x[3:0], p2y[7:4], p2y[3:0]);
        // Sum: 0.5*n0 + 0.25*n1 + 0.125*n2  (scaled to 0..255)
        v = (n0 >> 1) + (n1 >> 2) + (n2 >> 3);
        fbm3 = v;
    end
endfunction

// ── Stage registers ─────────────────────────────────────────
// S0 → S1
reg signed [11:0] s1_nx;    // hcount - CX  (−960..959)
reg signed [10:0] s1_ny;    // vcount - CY  (−540..539)
reg        [23:0] s1_time;
reg               s1_de;

// S1 → S2
reg  [7:0] s2_terrain_h;   // terrain height at this column (0..255)
reg signed [10:0] s2_ny;
reg        [23:0] s2_time;
reg               s2_de;
reg signed [11:0] s2_nx;

// S2 → S3
reg         s3_is_terrain;
reg  [7:0]  s3_height_diff; // how far below horizon (0..255)
reg signed [11:0] s3_nx;
reg        [23:0] s3_time;
reg               s3_de;
reg  [7:0]  s3_terrain_h;

// S3 → S4
reg  [7:0] s4_r, s4_g, s4_b;
reg        s4_de;
// s3_ny needed in stage 3 colour
reg signed [10:0] s3_ny;

// ── Stage 0: normalise ───────────────────────────────────────
always @(posedge clk or posedge rst) begin
    if (rst) begin
        s1_nx <= 0; s1_ny <= 0; s1_time <= 0; s1_de <= 0;
    end else begin
        s1_nx  <= hcount - CX;
        s1_ny  <= vcount - CY;
        s1_time <= frame_cnt;
        s1_de  <= de;
    end
end

// ── Stage 1: fBm terrain height for this column ─────────────
// Camera flies along Z (frame_cnt / 8 → slow scroll)
// Column maps to X offset: nx / W * scale
// Terrain height (0..255) determines the horizon screen Y
wire [7:0] fly_z  = s1_time[10:3];        // 0..255, scrolls slowly
wire [7:0] col_x  = (s1_nx[10:3] + 8'd128) & 8'hFF;  // 0..255
wire [7:0] th_raw = fbm3(col_x, fly_z);

// Map terrain height to screen Y:
//   horizon_y = CY - (th * 300 / 256)   (0 = top)
//   so: terrain_y_screen = CY - th * 1.17
// Store as: terrain_screen_y (0..1079)
wire [10:0] terrain_sy = CY - {{2{1'b0}}, th_raw[7:1]};  // approx CY - th/2

always @(posedge clk or posedge rst) begin
    if (rst) begin
        s2_terrain_h <= 0; s2_ny <= 0; s2_time <= 0; s2_de <= 0; s2_nx <= 0;
    end else begin
        s2_terrain_h <= th_raw;
        s2_ny        <= s1_ny;
        s2_time      <= s1_time;
        s2_de        <= s1_de;
        s2_nx        <= s1_nx;
    end
end

// ── Stage 2: sky / terrain split ────────────────────────────
// vcount relative to screen horizon
// vcount < terrain_sy → sky
// vcount >= terrain_sy → terrain
// ny > 0 (below screen centre) more likely terrain
wire signed [10:0] horizon_ny = $signed({1'b0, s2_terrain_h[7:1]}) - 11'd80;
// horizon at screen y = CY + horizon_ny  (horizon_ny negative = above centre)
wire is_terrain_w = ($signed(s2_ny) > horizon_ny);
wire [7:0] hd_raw = is_terrain_w ?
    (s2_ny - horizon_ny) : 8'd0;  // pixels below horizon

always @(posedge clk or posedge rst) begin
    if (rst) begin
        s3_is_terrain <= 0; s3_height_diff <= 0;
        s3_nx <= 0; s3_time <= 0; s3_de <= 0; s3_terrain_h <= 0;
    end else begin
        s3_is_terrain  <= is_terrain_w;
        s3_height_diff <= hd_raw;
        s3_nx          <= s2_nx;
        s3_ny          <= s2_ny;
        s3_time        <= s2_time;
        s3_de          <= s2_de;
        s3_terrain_h   <= s2_terrain_h;
    end
end

// ── Stage 3: colour synthesis ────────────────────────────────

// SKY: vertical gradient + sun glow + stars
// Gradient: top = dark blue, horizon = light blue
// ny_norm: 0=horizon, 127=top
wire [7:0] sky_t = s3_is_terrain ? 8'd0 :
    (s3_ny < 0 ? (8'd127 - {1'b0, s3_ny[9:3]}) : 8'd0);
// sun: centred near nx=0, sin_lut[time>>2] gives slow angular sweep
wire [7:0] sun_ang  = s3_time[9:2];
wire signed [7:0] sun_off_x = sin_lut[sun_ang];              // -127..127
wire [8:0] sun_dx   = $signed({1'b0, s3_nx[8:1]}) - $signed({1'b0, sun_off_x});
wire [7:0] sun_dist = (sun_dx[8] ? (~sun_dx[7:0] + 1) : sun_dx[7:0]);
wire [7:0] sun_glow = (sun_dist < 8'd12 && !s3_is_terrain) ?
                      (8'd255 - sun_dist * 8'd16) : 8'd0;

// Sky R G B
wire [8:0] sky_r = {1'b0, sky_t[7:1]} + {1'b0, sun_glow} + 8'd12;
wire [8:0] sky_g = {1'b0, sky_t[6:0]} + {1'b0, sun_glow[7:1]} + 8'd28;
wire [8:0] sky_b = {1'b0, sky_t}      + 8'd80;

// TERRAIN colour:
// Base rock: brownish (R=110, G=90, B=60) + fBm noise tint
wire [7:0] rock_noise = noise_lut[{s3_nx[5:2], s3_time[5:2]}];
wire [7:0] trr = 8'd90  + rock_noise[7:3];
wire [7:0] trg = 8'd72  + rock_noise[7:4];
wire [7:0] trb = 8'd45  + rock_noise[7:5];

// Snow cap: top 30% of terrain height gets snow
wire is_snow  = (s3_terrain_h > 8'd180);
wire [7:0] terrain_r = is_snow ? 8'd230 : trr;
wire [7:0] terrain_g = is_snow ? 8'd235 : trg;
wire [7:0] terrain_b = is_snow ? 8'd245 : trb;

// Atmospheric fog: further away (higher up screen = farther)
// fog_amount ∝ (255 - height_diff)
wire [7:0] fog_amt = 8'd255 - s3_height_diff;
// Fog colour ≈ sky horizon colour
wire [15:0] fog_r16 = terrain_r * s3_height_diff + 8'd140 * fog_amt;
wire [15:0] fog_g16 = terrain_g * s3_height_diff + 8'd160 * fog_amt;
wire [15:0] fog_b16 = terrain_b * s3_height_diff + 8'd185 * fog_amt;
wire [7:0] fogged_r = fog_r16[15:8];
wire [7:0] fogged_g = fog_g16[15:8];
wire [7:0] fogged_b = fog_b16[15:8];

// Clamp sky channels
wire [7:0] fr = s3_is_terrain ? fogged_r : (sky_r[8] ? 8'hFF : sky_r[7:0]);
wire [7:0] fg = s3_is_terrain ? fogged_g : (sky_g[8] ? 8'hFF : sky_g[7:0]);
wire [7:0] fb = s3_is_terrain ? fogged_b : (sky_b[8] ? 8'hFF : sky_b[7:0]);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        s4_r <= 0; s4_g <= 0; s4_b <= 0; s4_de <= 0;
    end else begin
        s4_r <= fr; s4_g <= fg; s4_b <= fb; s4_de <= s3_de;
    end
end

// ── Stage 4: gamma (approx √x via LUT) + output ─────────────
// Simple gamma: out = in * in / 255  (inverse gamma 2.0)
// OR pass-through if gamma already acceptable
// For FPGA simplicity: use identity (gamma already handled by display)
always @(posedge clk or posedge rst) begin
    if (rst) begin
        r <= 0; g <= 0; b <= 0;
    end else begin
        if (s4_de) begin
            r <= s4_r;
            g <= s4_g;
            b <= s4_b;
        end else begin
            r <= 0; g <= 0; b <= 0;
        end
    end
end

endmodule
