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

localparam ST_LOAD   = 2'd0;
localparam ST_SEARCH = 2'd1;
localparam ST_DONE   = 2'd2;

reg [ 1:0] state;
reg [ 7:0] sel_a;
reg [ 7:0] sel_b;
reg [ 7:0] best_sel_a;
reg [ 7:0] best_sel_b;
reg [ 5:0] best_cover;
reg        search_done;
reg [ 5:0] coord_idx;
reg [39:0] cover_mask [0:255];

wire [39:0] mask_a = cover_mask[sel_a];
wire [39:0] mask_b = cover_mask[sel_b];
wire [39:0] union_mask = mask_a | mask_b;
wire [5:0] union_cover = popcount40(union_mask);
wire [15:0] current_pair = {sel_a, sel_b};
wire [15:0] best_pair = {best_sel_a, best_sel_b};
wire last_pair = (sel_a == 8'd255) && (sel_b == 8'd255);

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        C1X <= 4'd0;
        C1Y <= 4'd0;
        C2X <= 4'd0;
        C2Y <= 4'd0;
        DONE <= 1'b0;
    end
    else begin
        if (state == ST_DONE) begin
            C1X <= best_sel_a[3:0];
            C1Y <= best_sel_a[7:4];
            C2X <= best_sel_b[3:0];
            C2Y <= best_sel_b[7:4];
            DONE <= 1'b1;
        end
        else begin
            C1X <= 4'd0;
            C1Y <= 4'd0;
            C2X <= 4'd0;
            C2Y <= 4'd0;
            DONE <= 1'b0;
        end
    end
end

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        state <= ST_LOAD;
    end
    else begin
        case (state)
            ST_LOAD: begin
                if (coord_idx == 6'd40) begin
                    state <= ST_SEARCH;
                end
            end
            ST_SEARCH: begin
                if (search_done) begin
                    state <= ST_DONE;
                end
            end
            ST_DONE: begin
                state <= ST_DONE;
            end
            default: begin
                state <= ST_LOAD;
            end
        endcase
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

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        sel_a <= 8'd0;
        sel_b <= 8'd0;
    end
    else begin
        if (state == ST_LOAD) begin
            if (coord_idx == 6'd40) begin
                sel_a <= 8'd0;
                sel_b <= 8'd0;
            end
        end
        else if (state == ST_SEARCH) begin
            if (!last_pair) begin
                if (sel_b == 8'd255) begin
                    sel_a <= sel_a + 8'd1;
                    sel_b <= sel_a + 8'd1;
                end
                else begin
                    sel_b <= sel_b + 8'd1;
                end
            end
        end
    end
end

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        best_sel_a <= 8'd0;
        best_sel_b <= 8'd0;
        best_cover <= 6'd0;
    end
    else begin
        if (state == ST_LOAD) begin
            best_sel_a <= 8'd0;
            best_sel_b <= 8'd0;
            best_cover <= 6'd0;
        end
        else if (state == ST_SEARCH) begin
            if ((union_cover > best_cover) ||
                ((union_cover == best_cover) && (current_pair < best_pair))) begin
                best_sel_a <= sel_a;
                best_sel_b <= sel_b;
                best_cover <= union_cover;
            end
        end
    end
end

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        search_done <= 1'b0;
    end
    else begin
        if (state != ST_SEARCH) begin
            search_done <= 1'b0;
        end
        else if (last_pair) begin
            search_done <= 1'b1;
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
