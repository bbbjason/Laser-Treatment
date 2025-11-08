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

reg [ 5:0] coord_idx;
reg [39:0] cover_mask [0:255];

wire [255:0] show_covers_point;
genvar j;
generate
    for (j = 0; j < 256; j = j + 1) begin : SHOW_COVERS_POINT_GEN
        assign show_covers_point[j] = cover_mask[j][39];
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
    end
    else begin 
        if (coord_idx < 6'd40) begin
            coord_idx <= coord_idx + 1;
        end
        else begin
            coord_idx <= coord_idx;
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
            for (row = 0; row < 256; row = row + 1) begin
                cover_mask[row][coord_idx] <= (circle_covers_point(row[7:0], X, Y));
            end
        end
        else begin
            for (row = 0; row < 256; row = row + 1) begin
                cover_mask[row] <= cover_mask[row];
            end
        end
    end
end

function lut_in_circle;
    input [2:0] abs_dx;
    input [2:0] abs_dy;
    reg [4:0] lut_row;
begin
    case (abs_dx)
        3'd0: lut_row = 5'b11111;
        3'd1: lut_row = 5'b01111;
        3'd2: lut_row = 5'b01111;
        3'd3: lut_row = 5'b00111;
        3'd4: lut_row = 5'b00001;
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

function [5:0] popcount40;
    input [39:0] bits;
    integer k;
    begin
        popcount40 = 6'd0;
        for (k = 0; k < 40; k = k + 1) begin
            popcount40 = popcount40 + bits[k];
        end
    end
endfunction

endmodule
