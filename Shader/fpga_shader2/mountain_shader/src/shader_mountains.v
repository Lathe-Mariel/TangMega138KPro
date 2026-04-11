module pixel_core_sky (
    input wire clk,
    input wire [11:0] x,
    input wire [11:0] y,
    input wire [23:0] time_f,

    output reg [7:0] r,
    output reg [7:0] g,
    output reg [7:0] b
);

// =====================
// カメラ＆レイ
// =====================
reg signed [15:0] ro_x, ro_y, ro_z;
reg signed [15:0] rd_x, rd_y, rd_z;

always @(posedge clk) begin
    ro_x <= 0;
    ro_y <= 16'h0200;
    ro_z <= time_f[23:8]; // 前進

    rd_x <= (x - 825) <<< 3;
    rd_y <= (y - 375) <<< 3;
    rd_z <= 16'h0100;
end

// =====================
// 太陽（時間で回転）
// =====================
reg signed [15:0] sun_x, sun_y, sun_z;

always @(posedge clk) begin
    sun_x <= (time_f[23:16] <<< 1);
    sun_y <= 16'h0080;
    sun_z <= 16'h0040;
end

// =====================
// terrain
// =====================
function signed [15:0] terrain;
    input signed [15:0] x,z;
    begin
        terrain = (x ^ z) + ((x>>>2) ^ (z>>>3));
    end
endfunction

// =====================
// raymarch
// =====================
reg [5:0] step;
reg signed [15:0] t;
reg hit;

reg signed [15:0] px,py,pz;
reg signed [15:0] h;

always @(posedge clk) begin

    if (step == 0) begin
        t <= 16'h0200;
        hit <= 0;
        step <= 1;
    end else if (step < 16) begin

        px <= ro_x + ((rd_x * t) >>> 8);
        py <= ro_y + ((rd_y * t) >>> 8);
        pz <= ro_z + ((rd_z * t) >>> 8);

        h <= terrain(px, pz);

        if (py < h) begin
            hit <= 1;
            step <= 16;
        end else begin
            t <= t + 16'h0100;
            step <= step + 1;
        end

    end else begin
        step <= 0;
    end
end

// =====================
// 法線
// =====================
reg signed [15:0] nx,ny,nz;

always @(posedge clk) begin
    nx <= terrain(px+8,pz) - terrain(px-8,pz);
    nz <= terrain(px,pz+8) - terrain(px,pz-8);
    ny <= 16'h0100;
end

// =====================
// シャドウ（4step）
// =====================
reg [2:0] sstep;
reg signed [15:0] st;
reg [7:0] shadow;

always @(posedge clk) begin
    if (hit) begin
        if (sstep == 0) begin
            st <= 16'h0080;
            shadow <= 8'd255;
            sstep <= 1;
        end else if (sstep < 4) begin
            if ((py + ((sun_y*st)>>8)) < terrain(px + ((sun_x*st)>>8), pz + ((sun_z*st)>>8))) begin
                shadow <= 8'd60;
                sstep <= 4;
            end else begin
                st <= st + 16'h0100;
                sstep <= sstep + 1;
            end
        end
    end else begin
        sstep <= 0;
    end
end

// =====================
// 空（skyモデル）
// =====================
function [7:0] sky_r;
    input signed [15:0] dy;
    begin
        sky_r = 8'd30 + (dy[15:8] >> 2);
    end
endfunction

function [7:0] sky_g;
    input signed [15:0] dy;
    begin
        sky_g = 8'd60 + (dy[15:8] >> 1);
    end
endfunction

function [7:0] sky_b;
    input signed [15:0] dy;
    begin
        sky_b = 8'd140 + (dy[15:8]);
    end
endfunction

// 太陽ディスク（簡易）
function [7:0] sun_glow;
    input signed [15:0] dx,dy,dz;
    begin
        sun_glow = ((dx*sun_x + dy*sun_y + dz*sun_z) >>> 8);
    end
endfunction

// =====================
// 最終カラー
// =====================
always @(posedge clk) begin

    if (hit) begin
        // diffuse
        reg signed [15:0] diff;
        diff = ((nx*sun_x + ny*sun_y + nz*sun_z) >>> 8);

        // shadow適用
        diff = (diff * shadow) >>> 8;

        r <= 8'd80 + diff[7:0];
        g <= 8'd120 + diff[7:0];
        b <= 8'd70;

    end else begin
        // 空
        r <= sky_r(rd_y) + sun_glow(rd_x,rd_y,rd_z);
        g <= sky_g(rd_y) + sun_glow(rd_x,rd_y,rd_z);
        b <= sky_b(rd_y);
    end
end

endmodule