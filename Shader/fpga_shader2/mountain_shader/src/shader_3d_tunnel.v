// ============================================================
// 3D Space Tunnel Shader
// Effect: Flying through a star-field tunnel with neon rings,
//         laser grid floor, and depth-fogged nebula colours.
//
// Pipeline (3-stage to meet timing):
//   Stage 0: coordinate normalise  (registered)
//   Stage 1: fixed-point math      (registered)
//   Stage 2: colour mix            (combinational → registered out)
//
// All arithmetic is 18-bit fixed-point Q10.8 unless noted.
// "iTime" = frame_cnt (increments at 30 Hz).
// ============================================================
module shader_3d_tunnel (
    input  wire        clk,
    input  wire        rst,
    input  wire [10:0] hcount,
    input  wire [10:0] vcount,
    input  wire        de,
    input  wire [23:0] frame_cnt,
    output reg  [ 7:0] r,
    output reg  [ 7:0] g,
    output reg  [ 7:0] b
);

// ── Fixed-point helpers ────────────────────────────────────
// Q8 = 8 fractional bits  → scale = 256
localparam FP = 8;                 // fractional bits
localparam ONE  = (1 << FP);      // 1.0
localparam HALF = (1 << (FP-1));  // 0.5

// ── Screen centre (fixed) ──────────────────────────────────
localparam [10:0] CX = 960;
localparam [10:0] CY = 540;

// ── Pipeline registers ─────────────────────────────────────

// Stage 0 → 1
reg signed [17:0] s1_nx, s1_ny;   // normalised coords ×256  (-480..+480 range)
reg        [23:0] s1_time;
reg               s1_de;

// Stage 1 → 2
reg signed [17:0] s2_r2;          // nx²+ny²  (Q8, capped)
reg        [17:0] s2_angle_idx;   // pseudo-angle 0..255
reg        [17:0] s2_depth;       // 1/sqrt(r²) approximation Q8
reg        [23:0] s2_time;
reg         [7:0] s2_ring_phase;
reg               s2_de;
reg signed [17:0] s2_nx, s2_ny;

// ── LUT: sin/cos table 256-entry, 8-bit (signed) ──────────
// We store 256 values representing sin(2π·i/256)×127
reg signed [7:0] sin_lut [0:255];
integer i;
initial begin
    for (i = 0; i < 256; i = i + 1)
        sin_lut[i] = $rtoi($sin(2.0 * 3.14159265 * i / 256.0) * 127.0);
end

// ── Stage 0: normalise pixel ───────────────────────────────
// nx = (hcount - CX), ny = (vcount - CY)
// Scale: keep as integer pixels (range ±960 / ±540), will use later
always @(posedge clk or posedge rst) begin
    if (rst) begin
        s1_nx <= 0; s1_ny <= 0; s1_time <= 0; s1_de <= 0;
    end else begin
        s1_nx  <= {{7{1'b0}}, hcount} - CX;   // signed 11→18 bit
        s1_ny  <= {{7{1'b0}}, vcount} - CY;
        s1_time <= frame_cnt;
        s1_de  <= de;
    end
end

// ── Stage 1: compute r², pseudo-angle, depth ──────────────
// r² = nx²+ny²  (raw pixel²)
// pseudo-angle: octant-based approximation, maps to 0-255
// depth = 32768 / (r² + 1) truncated   → represents 1/dist
wire signed [35:0] nx2 = s1_nx * s1_nx;
wire signed [35:0] ny2 = s1_ny * s1_ny;
wire        [35:0] r2_raw = nx2 + ny2;

// Cap r² to 18 bits to avoid overflow (max ~524288 = 720²+540²≈845000 → cap)
wire [17:0] r2_capped = (r2_raw > 18'h3FFFF) ? 18'h3FFFF : r2_raw[17:0];

// Depth: reciprocal approximation via leading-zero shift
// depth ≈ 65535 >> log2(r2+1), packed Q8
wire [17:0] r2p1 = r2_capped + 1;
reg  [ 4:0] lz;   // leading-zero position
always @(*) begin
    casez (r2p1[17:0])
        18'b1?????????????????: lz = 17;
        18'b01????????????????: lz = 16;
        18'b001???????????????: lz = 15;
        18'b0001??????????????: lz = 14;
        18'b00001?????????????: lz = 13;
        18'b000001????????????: lz = 12;
        18'b0000001???????????: lz = 11;
        18'b00000001??????????: lz = 10;
        18'b000000001?????????: lz = 9;
        18'b0000000001????????: lz = 8;
        18'b00000000001???????: lz = 7;
        18'b000000000001??????: lz = 6;
        18'b0000000000001?????: lz = 5;
        18'b00000000000001????: lz = 4;
        18'b000000000000001???: lz = 3;
        18'b0000000000000001??: lz = 2;
        18'b00000000000000001?: lz = 1;
        default:                lz = 0;
    endcase
end

// Depth Q8: 256 >> (lz/2)  (rough sqrt-reciprocal)
wire [17:0] depth_w = (lz > 1) ? (18'd256 >> (lz >> 1)) : 18'd255;

// Pseudo-angle: atan2 approximation → 0..255
// Use sign bits and magnitude ratio for octant
wire sign_x = s1_nx[17];  // negative?
wire sign_y = s1_ny[17];
wire [17:0] abs_nx = sign_x ? (~s1_nx + 1) : s1_nx;
wire [17:0] abs_ny = sign_y ? (~s1_ny + 1) : s1_ny;
// ratio = 128 * min/max  → 0..127 within octant
wire gt = (abs_nx > abs_ny);
wire [17:0] numer = gt ? abs_ny : abs_nx;
wire [17:0] denom = gt ? abs_nx : abs_ny;
wire [17:0] ratio = (denom == 0) ? 0 : ((numer << 7) / denom);  // 0..127
// Map to 0..255 angle
wire [7:0] ang_w;
assign ang_w = gt  ? ( sign_x ? (sign_y ? (8'd192 + ratio[6:0]) : (8'd64  - ratio[6:0]))
                               : (sign_y ? (8'd128 + ratio[6:0]) : (8'd64  + ratio[6:0])) )
                    : ( sign_x ? (sign_y ? (8'd192 - ratio[6:0]) : (8'd128 - ratio[6:0]))  // top/bottom half
                               : (sign_y ? (8'd255 - ratio[6:0]) : ratio[6:0]) );

// Ring phase: depth-based ring pattern
// ring = (depth + time_scroll) mod 32 → maps to 0..31
wire [7:0] scroll   = s1_time[7:0];                  // scrolls at 30Hz
wire [7:0] ring_idx = (depth_w[7:0] + scroll) & 8'hFF;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        s2_r2 <= 0; s2_angle_idx <= 0; s2_depth <= 0;
        s2_time <= 0; s2_ring_phase <= 0; s2_de <= 0;
        s2_nx <= 0; s2_ny <= 0;
    end else begin
        s2_r2        <= r2_capped;
        s2_angle_idx <= {10'b0, ang_w};
        s2_depth     <= depth_w;
        s2_time      <= s1_time;
        s2_ring_phase<= ring_idx;
        s2_de        <= s1_de;
        s2_nx        <= s1_nx;
        s2_ny        <= s1_ny;
    end
end

// ── Stage 2: colour synthesis ─────────────────────────────
// Palette: neon tunnel
//   Base hue rotates with angle
//   Brightness driven by depth (close = bright)
//   Rings flash white
//   Stars near centre (r² small)

wire [7:0] ang8 = s2_angle_idx[7:0];
wire [7:0] dep8 = s2_depth[7:0];       // 0=far, 255=near (capped)

// Hue rotation: ang8 + time/4
wire [7:0] hue_idx  = ang8 + s2_time[9:2];

// Colour channels from sin-LUT (pseudo-hue)
wire signed [7:0] sin_h   = sin_lut[hue_idx];
wire signed [7:0] sin_h90 = sin_lut[hue_idx + 64];   // +90°
wire signed [7:0] sin_h45 = sin_lut[hue_idx + 128];  // +180°

// Neon hue  (convert signed -127..127 → unsigned 0..254)
wire [8:0] hue_r9 = {1'b0, sin_h[7]}   ? 9'd0 : {1'b0, sin_h   + 8'd127};
wire [8:0] hue_g9 = {1'b0, sin_h90[7]} ? 9'd0 : {1'b0, sin_h90 + 8'd127};
wire [8:0] hue_b9 = {1'b0, sin_h45[7]} ? 9'd0 : {1'b0, sin_h45 + 8'd127};

// Depth brightness (closer = brighter, with gamma-ish curve)
// bright = dep8²/255  (Q8 multiply)
wire [15:0] bright16 = dep8 * dep8;           // 0..65025
wire  [7:0] bright   = bright16[15:8];        // 0..254

// Mix hue × brightness
wire [15:0] cr16 = hue_r9[7:0] * bright;
wire [15:0] cg16 = hue_g9[7:0] * bright;
wire [15:0] cb16 = hue_b9[7:0] * bright;
wire  [7:0] cr   = cr16[15:8];
wire  [7:0] cg   = cg16[15:8];
wire  [7:0] cb   = cb16[15:8];

// Ring flash: ring_phase[4:0] < 2 → white flash
wire ring_flash = (s2_ring_phase[4:0] < 5'd3);

// Stars: centre-glow when r² is very small
wire star = (s2_r2 < 18'd64);

// Grid lines: angular grid (16 spokes) + radial rings
wire spoke    = (ang8[3:0] == 4'd0) || (ang8[3:0] == 4'd8);
wire grid_glow = spoke && (dep8 > 8'd10);

// Final colour
wire [8:0] fr = ring_flash ? 9'd255 : (star ? 9'd255 : (grid_glow ? {1'b0,cg}+9'd40 : {1'b0,cr}));
wire [8:0] fg = ring_flash ? 9'd255 : (star ? 9'd255 : (grid_glow ? {1'b0,cr}+9'd80 : {1'b0,cg}));
wire [8:0] fb = ring_flash ? 9'd255 : (star ? 9'd255 : (grid_glow ? 9'd255          : {1'b0,cb}+9'd30));

// Clamp 9→8 bit
wire [7:0] out_r = fr[8] ? 8'hFF : fr[7:0];
wire [7:0] out_g = fg[8] ? 8'hFF : fg[7:0];
wire [7:0] out_b = fb[8] ? 8'hFF : fb[7:0];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r <= 0; g <= 0; b <= 0;
    end else begin
        if (s2_de) begin
            r <= out_r;
            g <= out_g;
            b <= out_b;
        end else begin
            r <= 0; g <= 0; b <= 0;
        end
    end
end

endmodule
