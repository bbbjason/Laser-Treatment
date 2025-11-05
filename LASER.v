`timescale 1ns/10ps

module LASER (
input CLK,
input RST,
input [3:0] X,
input [3:0] Y,
output reg [3:0] C1X,
output reg [3:0] C1Y,
output reg [3:0] C2X,
output reg [3:0] C2Y,
output reg DONE);

integer i;
integer row;

reg [ 3:0] X_d [0:39];
reg [ 3:0] Y_d [0:39];
reg [ 5:0] coord_idx;
reg [39:0] cover_mask [0:255];

wire [255:0] show_covers_point;
genvar g;
generate
    for (g = 0; g < 256; g = g + 1) begin: show
        assign show_covers_point[g] = cover_mask[g][0];
    end
endgenerate

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        C1X <= 4'd0;
        C1Y <= 4'd0;
        C2X <= 4'd0;
        C2Y <= 4'd0;
        DONE <= 1'b0;
    end
    else begin
        C1X <= 4'd0;
        C1Y <= 4'd0;
        C2X <= 4'd0;
        C2Y <= 4'd0;
        DONE <= 1'b0;  
    end
end

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        coord_idx <= 6'd0;
        for (i = 0; i < 40; i = i + 1) begin
            X_d[i] <= 4'd0;
            Y_d[i] <= 4'd0;
        end
    end
    else begin 
        if (coord_idx < 6'd40) begin
            X_d[coord_idx] <= X;
            Y_d[coord_idx] <= Y;
            coord_idx <= coord_idx + 1;
        end
        else begin
            coord_idx <= coord_idx;
            for (i = 0; i < 40; i = i + 1) begin
                X_d[i] <= X_d[i];
                Y_d[i] <= Y_d[i];
            end
        end
    end
end

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        for (row = 0; row < 256; row = row + 1) begin
            cover_mask[row] <= 40'd0;
        end
    end
    else begin
        if (coord_idx < 6'd40) begin
            if (coord_idx == 6'd0) begin
                for (row = 0; row < 256; row = row + 1) begin
                    if (circle_covers_point(row[7:0], X, Y)) begin
                        cover_mask[row][0] <= 1'b1;
                    end
                end
            end
        end
        else begin
            for (row = 0; row < 256; row = row + 1) begin
                cover_mask[row] <= cover_mask[row];
            end
        end
    end
end


// 5x5 LUT indicating whether (dx^2 + dy^2) <= 16 for |dx|, |dy| in [0,4]
localparam [4:0] DIST_LUT_ROW0 = 5'b11111; // |dx| = 0, |dy| = 0..4
localparam [4:0] DIST_LUT_ROW1 = 5'b11110; // |dx| = 1
localparam [4:0] DIST_LUT_ROW2 = 5'b11110; // |dx| = 2
localparam [4:0] DIST_LUT_ROW3 = 5'b11100; // |dx| = 3
localparam [4:0] DIST_LUT_ROW4 = 5'b10000; // |dx| = 4

function lut_in_circle;
    input [2:0] abs_dx;
    input [2:0] abs_dy;
    reg [4:0] lut_row;
begin
    case (abs_dx)
        3'd0: lut_row = DIST_LUT_ROW0;
        3'd1: lut_row = DIST_LUT_ROW1;
        3'd2: lut_row = DIST_LUT_ROW2;
        3'd3: lut_row = DIST_LUT_ROW3;
        3'd4: lut_row = DIST_LUT_ROW4;
        default: lut_row = 5'b00000;
    endcase
    if (abs_dy < 3'd5)
        lut_in_circle = lut_row[abs_dy];
    else
        lut_in_circle = 1'b0;
end
endfunction

function circle_covers_point;
    input [7:0] circle_idx;
    input [3:0] point_x;
    input [3:0] point_y;
    reg [3:0] circle_x;
    reg [3:0] circle_y;
    reg [3:0] abs_dx;
    reg [3:0] abs_dy;
begin
    circle_x = circle_idx[3:0];
    circle_y = circle_idx[7:4];
    abs_dx = (circle_x >= point_x) ? (circle_x - point_x) : (point_x - circle_x);
    abs_dy = (circle_y >= point_y) ? (circle_y - point_y) : (point_y - circle_y);
    if ((abs_dx <= 4'd4) && (abs_dy <= 4'd4) && lut_in_circle(abs_dx[2:0], abs_dy[2:0]))
        circle_covers_point = 1'b1;
    else
        circle_covers_point = 1'b0;
end
endfunction

endmodule
