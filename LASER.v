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

localparam ST_CAPTURE = 2'd0;
localparam ST_SINGLE  = 2'd1;
localparam ST_PAIR    = 2'd2;
localparam ST_DONE    = 2'd3;

localparam [3:0] WINDOW_RANGE = 4'd8;

integer i;
integer row;

reg [5:0] coord_idx;
reg [39:0] cover_mask [0:255];
reg [1:0] state;
reg [1:0] state_next;
reg [1:0] state_prev;

reg [7:0] single_scan_idx;
wire [7:0] single_scan_idx_next;
reg       single_scan_done;
wire      single_scan_done_next;
reg [5:0] single_best_cover;
wire [5:0] single_best_cover_next;
reg [7:0] single_best_idx;
wire [7:0] single_best_idx_next;
wire       single_best_update_en;

reg [7:0] pair_anchor_idx;
reg [7:0] pair_anchor_idx_next;
reg [5:0] current_pair_cover;
reg [5:0] current_pair_cover_next;
reg [7:0] final_pair_a;
reg [7:0] final_pair_a_next;
reg [7:0] final_pair_b;
reg [7:0] final_pair_b_next;
reg [5:0] pair_iter_best_cover;
reg [5:0] pair_iter_best_cover_next;
reg [7:0] pair_iter_best_idx;
reg [7:0] pair_iter_best_idx_next;
reg       pair_phase;
reg       pair_phase_next;
reg       pair_search_complete;
reg       pair_search_complete_next;
reg       pair_scan_setup;
reg       pair_scan_setup_next;
reg [7:0] pair_setup_anchor;
reg [7:0] pair_setup_anchor_next;
reg [5:0] pair_setup_cover;
reg [5:0] pair_setup_cover_next;
reg [3:0] win_x_min, win_x_max;
reg [3:0] win_x_min_next, win_x_max_next;
reg [3:0] win_y_min, win_y_max;
reg [3:0] win_y_min_next, win_y_max_next;
reg [3:0] win_x_cur, win_y_cur;
reg [3:0] win_x_cur_next, win_y_cur_next;

wire enter_single = (state == ST_SINGLE) && (state_prev != ST_SINGLE);
wire enter_pair   = (state == ST_PAIR) && (state_prev != ST_PAIR);

wire [39:0] single_scan_mask = cover_mask[single_scan_idx];
wire [5:0]  single_scan_cover = popcount40(single_scan_mask);
wire        single_scan_last = (single_scan_idx == 8'd255);
wire        better_cover = (single_scan_cover > single_best_cover);
wire        equal_cover  = (single_scan_cover == single_best_cover);
wire        better_index = (single_scan_idx < single_best_idx);


wire [7:0]  pair_candidate_idx = {win_y_cur, win_x_cur};
wire [39:0] anchor_mask = cover_mask[pair_anchor_idx];
wire [39:0] candidate_mask = cover_mask[pair_candidate_idx];
wire [39:0] pair_union_mask = anchor_mask | candidate_mask;
wire [5:0]  pair_union_cover = popcount40(pair_union_mask);

wire [3:0] setup_x_min = clamp_minus(pair_setup_anchor[3:0]);
wire [3:0] setup_x_max = clamp_plus (pair_setup_anchor[3:0]);
wire [3:0] setup_y_min = clamp_minus(pair_setup_anchor[7:4]);
wire [3:0] setup_y_max = clamp_plus (pair_setup_anchor[7:4]);

wire        pair_scan_is_last = (win_x_cur == win_x_max) && (win_y_cur == win_y_max);
wire 	    in_pair             = (state == ST_PAIR);
wire 	    scan_setup_phase    = in_pair && pair_scan_setup;
wire 	    search_phase        = in_pair && !pair_phase && !pair_search_complete && !pair_scan_setup;
wire 	    eval_phase          = in_pair && pair_phase && !pair_search_complete;
wire 	    outside_pair        = !in_pair;
wire        candidate_is_anchor = (pair_candidate_idx == pair_anchor_idx);
wire 	    candidate_improves  = (!candidate_is_anchor) && (pair_union_cover > pair_iter_best_cover);
wire 	    best_pair_improves  = (pair_iter_best_cover > current_pair_cover);
wire 	    advance_window      = search_phase && !pair_scan_is_last;
wire 	    wrap_window         = advance_window && (win_x_cur == win_x_max);

wire [39:0] show_cover_mask = cover_mask[8'ha7];

assign single_scan_idx_next =
    enter_single                               ? 8'd0 :
    ((state == ST_SINGLE) && !single_scan_done && !single_scan_last)
                                                ? (single_scan_idx + 8'd1) :
                                                  single_scan_idx;
                                                  
assign single_scan_done_next =
    enter_single                             ? 1'b0 :
    ((state == ST_SINGLE) && !single_scan_done && single_scan_last)
                                             ? 1'b1 :
                                               single_scan_done;
                                               
assign single_best_update_en = (state == ST_SINGLE) && !single_scan_done &&
                               (better_cover || (equal_cover && better_index));
                                    
assign single_best_cover_next =
    enter_single            ? 6'd0 :
    single_best_update_en   ? single_scan_cover :
                              single_best_cover;

assign single_best_idx_next =
    enter_single            ? 8'd0 :
    single_best_update_en   ? single_scan_idx :
                              single_best_idx;

always @(*) begin
    state_next = state;
    case (state)
        ST_CAPTURE: begin
            if (coord_idx == 6'd40) begin
                state_next = ST_SINGLE;
            end
        end
        ST_SINGLE: begin
            if (single_scan_done) begin
                state_next = ST_PAIR;
            end
        end
        ST_PAIR: begin
            if (pair_search_complete) begin
                state_next = ST_DONE;
            end
        end
        ST_DONE: begin
            state_next = ST_DONE;
        end
        default: begin
            state_next = ST_CAPTURE;
        end
    endcase
end

always @(*) begin
    pair_anchor_idx_next    = pair_anchor_idx;
    current_pair_cover_next = current_pair_cover;
    if (enter_pair) begin
        pair_anchor_idx_next    = single_best_idx;
        current_pair_cover_next = single_best_cover;
    end
    else if (eval_phase && best_pair_improves) begin
        pair_anchor_idx_next    = pair_iter_best_idx;
        current_pair_cover_next = pair_iter_best_cover;
    end
end

always @(*) begin
    final_pair_a_next = final_pair_a;
    final_pair_b_next = final_pair_b;
    if (enter_pair) begin
        final_pair_a_next = single_best_idx;
        final_pair_b_next = single_best_idx;
    end
    else if (eval_phase && best_pair_improves) begin
        final_pair_a_next = pair_anchor_idx;
        final_pair_b_next = pair_iter_best_idx;
    end
end

always @(*) begin
    pair_iter_best_cover_next = pair_iter_best_cover;
    pair_iter_best_idx_next   = pair_iter_best_idx;
    if (scan_setup_phase) begin
        pair_iter_best_cover_next = pair_setup_cover;
        pair_iter_best_idx_next   = pair_setup_anchor;
    end
    else if (search_phase && candidate_improves) begin
        pair_iter_best_cover_next = pair_union_cover;
        pair_iter_best_idx_next   = pair_candidate_idx;
    end
end

always @(*) begin
    pair_phase_next = pair_phase;
    if (outside_pair || enter_pair || scan_setup_phase)
        pair_phase_next = 1'b0;
    else if (search_phase && pair_scan_is_last)
        pair_phase_next = 1'b1;
    else if (eval_phase && best_pair_improves)
        pair_phase_next = 1'b0;
end

always @(*) begin
    pair_search_complete_next = pair_search_complete;
    if (enter_pair)
        pair_search_complete_next = 1'b0;
    else if (eval_phase && !best_pair_improves)
        pair_search_complete_next = 1'b1;
end

always @(*) begin
    pair_scan_setup_next = pair_scan_setup;
    if (outside_pair)
        pair_scan_setup_next = 1'b0;
    else if (enter_pair)
        pair_scan_setup_next = 1'b1;
    else if (scan_setup_phase)
        pair_scan_setup_next = 1'b0;
    else if (eval_phase && best_pair_improves)
        pair_scan_setup_next = 1'b1;
end

always @(*) begin
    pair_setup_anchor_next = pair_setup_anchor;
    pair_setup_cover_next  = pair_setup_cover;
    if (enter_pair) begin
        pair_setup_anchor_next = single_best_idx;
        pair_setup_cover_next  = single_best_cover;
    end
    else if (eval_phase && best_pair_improves) begin
        pair_setup_anchor_next = pair_iter_best_idx;
        pair_setup_cover_next  = pair_iter_best_cover;
    end
end

always @(*) begin
    win_x_min_next = win_x_min;
    win_x_max_next = win_x_max;
    win_y_min_next = win_y_min;
    win_y_max_next = win_y_max;
    win_x_cur_next = win_x_cur;
    win_y_cur_next = win_y_cur;
    if (scan_setup_phase) begin
        win_x_min_next = setup_x_min;
        win_x_max_next = setup_x_max;
        win_y_min_next = setup_y_min;
        win_y_max_next = setup_y_max;
        win_x_cur_next = setup_x_min;
        win_y_cur_next = setup_y_min;
    end
    else if (advance_window) begin
        if (wrap_window) begin
            win_x_cur_next = win_x_min;
            win_y_cur_next = win_y_cur + 4'd1;
        end
        else begin
            win_x_cur_next = win_x_cur + 4'd1;
        end
    end
end

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        state <= ST_CAPTURE;
        state_prev <= ST_CAPTURE;
    end
    else begin
        state_prev <= state;
        state <= state_next;
    end
end

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        C1X <= 4'd0;
        C1Y <= 4'd0;
        C2X <= 4'd0;
        C2Y <= 4'd0;
        DONE <= 1'b0;
    end
    else begin
        C1X <= (state == ST_DONE) ? final_pair_a[3:0] : 4'd0;
        C1Y <= (state == ST_DONE) ? final_pair_a[7:4] : 4'd0;
        C2X <= (state == ST_DONE) ? final_pair_b[3:0] : 4'd0;
        C2Y <= (state == ST_DONE) ? final_pair_b[7:4] : 4'd0;
        DONE <= (state == ST_DONE);
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
        single_scan_idx   <= 8'd0;
        single_scan_done  <= 1'b0;
        single_best_cover <= 6'd0;
        single_best_idx   <= 8'd0;
    end
    else begin
        single_scan_idx   <= single_scan_idx_next;
        single_scan_done  <= single_scan_done_next;
        single_best_cover <= single_best_cover_next;
        single_best_idx   <= single_best_idx_next;
    end
end

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        pair_anchor_idx      <= 8'd0;
        current_pair_cover   <= 6'd0;
        final_pair_a         <= 8'd0;
        final_pair_b         <= 8'd0;
        pair_iter_best_cover <= 6'd0;
        pair_iter_best_idx   <= 8'd0;
        pair_phase           <= 1'b0;
        pair_search_complete <= 1'b0;
        pair_scan_setup      <= 1'b0;
        pair_setup_anchor    <= 8'd0;
        pair_setup_cover     <= 6'd0;
        win_x_min            <= 4'd0;
        win_x_max            <= 4'd0;
        win_y_min            <= 4'd0;
        win_y_max            <= 4'd0;
        win_x_cur            <= 4'd0;
        win_y_cur            <= 4'd0;
    end
    else begin
        pair_anchor_idx      <= pair_anchor_idx_next;
        current_pair_cover   <= current_pair_cover_next;
        final_pair_a         <= final_pair_a_next;
        final_pair_b         <= final_pair_b_next;
        pair_iter_best_cover <= pair_iter_best_cover_next;
        pair_iter_best_idx   <= pair_iter_best_idx_next;
        pair_phase           <= pair_phase_next;
        pair_search_complete <= pair_search_complete_next;
        pair_scan_setup      <= pair_scan_setup_next;
        pair_setup_anchor    <= pair_setup_anchor_next;
        pair_setup_cover     <= pair_setup_cover_next;
        win_x_min            <= win_x_min_next;
        win_x_max            <= win_x_max_next;
        win_y_min            <= win_y_min_next;
        win_y_max            <= win_y_max_next;
        win_x_cur            <= win_x_cur_next;
        win_y_cur            <= win_y_cur_next;
    end
end

function [3:0] clamp_minus;
    input [3:0] coord;
begin
    if (coord <= WINDOW_RANGE)
        clamp_minus = 4'd0;
    else
        clamp_minus = coord - WINDOW_RANGE;
end
endfunction

function [3:0] clamp_plus;
    input [3:0] coord;
begin
    if (coord >= (4'd15 - WINDOW_RANGE))
        clamp_plus = 4'd15;
    else
        clamp_plus = coord + WINDOW_RANGE;
end
endfunction

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
    reg [2:0] n0, n1, n2, n3, n4, n5, n6, n7, n8, n9;
    reg [4:0] s0, s1, s2, s3, s4;
    reg [5:0] t0, t1, t2;
    begin
        n0 = pc4(bits[ 3: 0]);
        n1 = pc4(bits[ 7: 4]);
        n2 = pc4(bits[11: 8]);
        n3 = pc4(bits[15:12]);
        n4 = pc4(bits[19:16]);
        n5 = pc4(bits[23:20]);
        n6 = pc4(bits[27:24]);
        n7 = pc4(bits[31:28]);
        n8 = pc4(bits[35:32]);
        n9 = pc4(bits[39:36]);

        s0 = n0 + n1;
        s1 = n2 + n3;
        s2 = n4 + n5;
        s3 = n6 + n7;
        s4 = n8 + n9;

        t0 = s0 + s1;
        t1 = s2 + s3;
        t2 = t0 + t1;

        popcount40 = t2 + {1'b0, s4};
end
endfunction

function [2:0] pc4;
    input [3:0] x;
    begin
        case (x)
            4'b0000: pc4 = 3'd0; 4'b0001: pc4 = 3'd1; 4'b0010: pc4 = 3'd1; 4'b0011: pc4 = 3'd2;
            4'b0100: pc4 = 3'd1; 4'b0101: pc4 = 3'd2; 4'b0110: pc4 = 3'd2; 4'b0111: pc4 = 3'd3;
            4'b1000: pc4 = 3'd1; 4'b1001: pc4 = 3'd2; 4'b1010: pc4 = 3'd2; 4'b1011: pc4 = 3'd3;
            4'b1100: pc4 = 3'd2; 4'b1101: pc4 = 3'd3; 4'b1110: pc4 = 3'd3; 4'b1111: pc4 = 3'd4;
            default: pc4 = 3'd0;
        endcase
    end
endfunction

endmodule