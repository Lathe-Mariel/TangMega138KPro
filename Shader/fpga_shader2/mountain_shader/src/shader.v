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
logic[7:0] sphere_value;

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

    if (sphere_length[11:0] <110)begin
        sphere_value <= 8'hff;
    end else begin
        sphere_value <= (8'hff < (sphere_length[11:0]*2-90))?8'b0:(8'hff - (sphere_length[11:0]*2-90));
    end

end

// =====================
// Grid
// =====================
logic[7:0] grid_value;

always_ff @(posedge clk)begin
    grid_value <= 8'h00;
    if(y == 300)begin
        grid_value <= 8'hA0;
    end
    if(y == 420)begin
        grid_value <= 8'hA0;
    end
    if(y == 520)begin
        grid_value <= 8'hA0;
    end
    if(y == 600)begin
        grid_value <= 8'hA0;
    end
    if(y == 675)begin
        grid_value <= 8'hA0;
    end

if(y > 300)begin
    if((-2*(x-530)) >= y && (-2*(x-530)) <= y+2)begin
        grid_value <= 8'hA0;
    end
    if((-4*(x-640)) >= y && (-4*(x-640)) <= y+4)begin
        grid_value <= 8'hA0;
    end
    if((-8*(x-730)) >= y && (-8*(x-730)) <= y+8)begin
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

/*
    if(y>100 && y<200)begin
        grid_value <= 8'h80;
    end else if (y>330 && y<490)begin
        grid_value <= 8'h80;
    end else if (y>650)begin
        grid_value <= 8'h80;
    end else begin
        grid_value <= 8'h00;
    end
*/
/*
    if(x>100 && y<200)begin
        grid_value <= 8'h80;
    end else if (y>330 && y<490)begin
        grid_value <= 8'h80;
    end else if (y>650)begin
        grid_value <= 8'h80;
    end else begin
        grid_value <= 8'h00;
    end*/
end

assign r = sphere_value | grid_value;
assign g = sphere_value | grid_value;
assign b = sphere_value | grid_value;

endmodule