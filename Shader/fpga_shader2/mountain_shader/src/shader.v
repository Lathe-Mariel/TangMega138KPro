module shader (
    input wire clk,
    input wire [11:0] x,
    input wire [11:0] y,
    input wire [23:0] time_f,

    output reg [7:0] r,
    output reg [7:0] g,
    output reg [7:0] b
);

localparam [11:0] CAMERA_x = 1650 / 2;
localparam [11:0] CAMERA_y = 720 / 2;
localparam [11:0] CAMERA_z = 0;


// =====================
// Sphire
// =====================
logic[7:0] pixel_value;


function [11:0] length;
    input [15:0] val1;
    input [15:0] val2;

    length = ( (((val1>val2)?val1:val2) << 16'd4) + (((val1<val2)?val1:val2) << 16'd3)) >> 16'd4;
/*
  int x0, y0, x2, y2, x3, y3, x4, y4, x5, y5, x6, y6;
  x0 = val1;
  y0 = val2;
  x3 = 4149 * x0;
  y3 = 1112 * y0;
  x4 = 1112 * x0;
  y4 = 4149 * y0;
  x5 = 3720 * x0;
  y5 = 2148 * y0;
  x6 = 2148 * x0;
  y6 = 3720 * y0;
  length =  ((x0 + y0) * 18461 + 
            ((x0>y0)?(x0-y0):(y0-x0)) * 3037 +
            ((x3>y3)?(x3-y3):(y3-x3)) +
            ((x4>y4)?(x4-y4):(y4-x4)) +
            ((x5>y5)?(x5-y5):(y5-x5)) +
            ((x6>y6)?(x6-y6):(y6-x6)))   >> 15;
*/
endfunction

logic[11:0] c_x, c_y; // x/y from center

assign c_x = (x < CAMERA_x)?CAMERA_x - x: x - CAMERA_x;
assign c_y = (y < CAMERA_y)?CAMERA_y - y: y - CAMERA_y;
logic[11:0] sphere_length;
assign sphere_length = length(c_x,c_y);

always_ff @(posedge clk)begin

    if (sphere_length[11:0] <64)begin
        pixel_value <= 8'hff;
    end else begin
        pixel_value <= (8'hff < (sphere_length[11:0]*2))?8'b0:(8'hff - (sphere_length[7:0]*2));
    end
    r <= pixel_value;
    g <= pixel_value;
    b <= pixel_value;
end

endmodule