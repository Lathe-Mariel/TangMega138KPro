module shader (
    input wire clk,
    input wire [11:0] x,
    input wire [10:0] y,
//    input wire [23:0] time_f,

    output reg [7:0] r,
    output reg [7:0] g,
    output reg [7:0] b
);

localparam [11:0] CAMERA_x = 1650 / 2;
localparam [10:0] CAMERA_y = 720 / 2;
localparam [11:0] CAMERA_z = 0;


// =====================
// Sphire
// =====================
logic[7:0] sphere_value;

function [11:0] length;
    input [13:0] val1;
    input [13:0] val2;

    length = ( (((val1>val2)?val1:val2) << 4) + (((val1<val2)?val1:val2) << 3)) >> 4;
//    length =  (((val1>val2)?val1:val2) *983 + (((val1<val2)?val1:val2) *407)) >> 10;

endfunction

logic[11:0] c_x, c_y; // x/y from center

assign c_x = (x < CAMERA_x)?CAMERA_x - x: x - CAMERA_x;
assign c_y = (y < CAMERA_y)?CAMERA_y - y: y - CAMERA_y;
logic[11:0] sphere_length;
assign sphere_length = length(c_x,c_y);
/*
always_ff@(posedge clk) begin

    if (sphere_length <12'd110)begin
        sphere_value <= 8'hfc;
    end else begin
//        sphere_value <= (8'hff < (sphere_length[11:0]*2-90))?8'b0:(8'hff - (sphere_length[11:0]*2-90));
        sphere_value <= (sphere_length<9'd365)?9'd365-sphere_length[8:0]:8'b0;
    end

end
*/
// =====================
// Grid
// =====================
logic[7:0] grid_value;

always_ff @(posedge clk)begin
    grid_value <= 0;

    if(y == 300)begin
        grid_value <= 8'hA0;
    end
    if(y == 360)begin
        grid_value <= 8'hA0;
    end
    if(y == 440)begin
        grid_value <= 8'hA0;
    end
    if(y == 545)begin
        grid_value <= 8'hA0;
    end
    if(y == 675)begin
        grid_value <= 8'hA0;
    end

  if(y > 300)begin
    if((-2*(x-530)) >= y && (-2*(x-530)) <= y+2)begin
        grid_value <= 8'hA0;
    end
    if((-4*(x-590)) >= y && (-4*(x-590)) <= y+4)begin
        grid_value <= 8'hA0;
    end
    if((-8*(x-685)) >= y && (-8*(x-685)) <= y+8)begin
        grid_value <= 8'hA0;
    end
    if((-16*(x-800)) >= y && (-16*(x-800)) <= y+16)begin
        grid_value <= 8'hA0;
    end

    if((2*(x-1150)) >= y && (2*(x-1150)) <= y+2)begin
        grid_value <= 8'hA0;
    end
    if((4*(x-1050)) >= y && (4*(x-1050)) <= y+4)begin
        grid_value <= 8'hA0;
    end
    if((8*(x-950)) >= y && (8*(x-950)) <= y+8)begin
        grid_value <= 8'hA0;
    end
    if((16*(x-850)) >= y && (16*(x-850)) <= y+16)begin
        grid_value <= 8'hA0;
    end
  end

end

// =====================
// Background
// =====================

logic[7:0] background_value;

always_ff@(posedge clk) begin

    if(y < 11'd256)begin
        background_value <= 8'hff~^y;
    end else begin
        background_value <= 0;
    end
end

// =====================
// Pixel value
// =====================
logic[8:0] red, green, blue;

always_comb begin
  r = (sphere_value > grid_value)?sphere_value:grid_value;
  green = ((sphere_value > grid_value)?sphere_value:grid_value) + background_value;
  blue  = ((sphere_value > grid_value)?sphere_value:grid_value) + background_value;

  g = (green[8] == 1)?255:green[7:0];
  b = (blue[8] == 1)?255:blue[7:0];

end
endmodule