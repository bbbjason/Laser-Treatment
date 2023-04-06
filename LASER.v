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

//Input DFF
reg [3:0] X_d [0:39];
reg [3:0] Y_d [0:39];
reg [40-1:0] active_current, active_max_tmp, active_max;
reg [2:0] data_idx;

// FSM state
localparam IDLE = 2'd0;
localparam REC = 2'd1;
localparam COMP = 2'd2;
localparam OUT = 2'd3;
reg [2-1:0] state, state_next;

// control signal
wire finish;

// count receive data
reg [6-1:0] cnt_data;

reg [5:0] iteration;
reg [3:0] circle1_X, max_X1_value;
reg [3:0] circle1_Y, max_Y1_value;
reg [7:0] max1_value;
reg [3:0] circle2_X, max_X2_value;
reg [3:0] circle2_Y, max_Y2_value;
reg [7:0] max2_value;
reg [7:0] current_value;
wire [3:0] circle_X, circle_Y;

wire [7:0] inside_flag;
wire [3:0] dx[0:7];
wire [3:0] dy[0:7];
wire [7:0] dist_sq[0:7];


genvar j;
generate
    for (j=0; j<8; j=j+1) begin: gen
        // calculate the squared distance from (x,y) to (cx,cy)
        assign dx[j] = (circle_X > X_d[data_idx*8 + j]) ? circle_X - X_d[data_idx*8 + j] : X_d[data_idx*8 + j] - circle_X;
        assign dy[j] = (circle_Y > Y_d[data_idx*8 + j]) ? circle_Y - Y_d[data_idx*8 + j] : Y_d[data_idx*8 + j] - circle_Y;
        assign dist_sq[j] = dx[j]*dx[j] + dy[j]*dy[j];
        // check if the point is inside the circle
        assign inside_flag[j] = (dist_sq[j] <= 16);
    end
endgenerate



assign circle_X = (iteration[0] == 0) ? circle1_X : circle2_X;
assign circle_Y = (iteration[0] == 0 ) ? circle1_Y : circle2_Y;

// FSM
always@* begin
    state_next = IDLE;
    case(state) 
        IDLE: begin
            state_next = REC;
        end

        REC: begin
            if (cnt_data == 39) state_next = COMP;
            else state_next = REC;
        end

        COMP: begin
            if (finish == 1) state_next = OUT;
            else  state_next = COMP;
        end

        OUT: begin
            state_next = REC;
        end
    endcase
end

assign finish = (iteration==5);

//////////////////////////////////////////////////////////////////////////////

always@(posedge CLK) begin
    if(RST) state <= IDLE;
    else state <= state_next;
end

always@(posedge CLK) begin
    if(RST) cnt_data <= 0;
    else if(state == OUT) cnt_data <= 0;
    else if(state == REC) cnt_data <= cnt_data + 1;
end

always@(posedge CLK) begin
    if(RST) begin
        for (i=0; i<40 ; i=i+1) begin
            X_d[i] <= 0;
            Y_d[i] <= 0;
        end
    end
    else if(state == REC) begin
        X_d[cnt_data] <= X;
        Y_d[cnt_data] <= Y;
    end
end

always@(posedge CLK) begin
    if(RST) begin
        iteration <= 0;
    end
    else begin
        if(state == COMP) begin
            if((data_idx == 5) && ((circle1_X == 13 && circle1_Y == 13) || (circle2_X == 13 && circle2_Y == 13))) begin
                iteration <= iteration + 1;
                // $display("(%d,%d), (%d,%d), : %d", max_X1_value, max_Y1_value, max_X2_value, max_Y2_value, max1_value + max2_value);
            end
            else begin
                iteration <= iteration;
            end
        end
        else if(state == OUT) 
            begin
                iteration <= 0;
            end
    end
end

always@(posedge CLK) begin
    if(RST) begin
        circle1_X <= 0;
        circle1_Y <= 0;
        circle2_X <= 0;
        circle2_Y <= 0;
        active_max <= 0;
    end
    else begin
        if(data_idx == 5) begin
            if (iteration[0] == 0) begin
                if(iteration == 0 && circle1_X == 0 && circle1_Y == 0) begin
                    circle1_X <= 2;
                    circle1_Y <= 2;
                end
                else begin
                    if(circle1_X == 13 && circle1_Y == 13) begin
                        circle1_X <= 2;
                        circle1_Y <= 2;
                        active_max <= active_max_tmp;

                    end
                    else if(circle1_X == 13) begin
                        circle1_X <= 2;
                        circle1_Y <= circle1_Y + 1;
                    end
                    else begin
                        circle1_X <= circle1_X + 1;
                        circle1_Y <= circle1_Y;
                    end
                end            
            end
            else begin
                if(iteration == 1 && circle2_X == 0 && circle2_Y == 0) begin
                    circle2_X <= 2;
                    circle2_Y <= 2;
                end
                else begin
                    if(circle2_X == 13 && circle2_Y == 13) begin
                        circle2_X <= 2;
                        circle2_Y <= 2;
                        active_max <= active_max_tmp;
                    end
                    else if(circle2_X == 13) begin
                        circle2_X <= 2;
                        circle2_Y <= circle2_Y + 1;
                    end
                    else begin
                        circle2_X <= circle2_X + 1;
                        circle2_Y <= circle2_Y;
                    end
                end            
            end

        end
        else if(state == REC) begin
            circle1_X <= 0;
            circle1_Y <= 0;
            circle2_X <= 0;
            circle2_Y <= 0;
            active_max <= 0;
        end
        else begin
            circle1_X <= circle1_X;
            circle1_Y <= circle1_Y;
            circle2_X <= circle2_X;
            circle2_Y <= circle2_Y;
            active_max <= active_max;
        end
    end
end

always@(posedge CLK) begin
    if(RST) begin
        data_idx <= 0;
    end
    else begin
        if(state == COMP) begin
            if(data_idx == 5) begin
                data_idx <= 0;
            end
            else begin
                data_idx <= data_idx + 1;
            end
        end
        else data_idx <= 0;
        
    end
end

always@(posedge CLK) begin
    if(RST) begin
        current_value <= 0;
        max1_value <= 0;
        max2_value <= 0;
        max_X1_value <= 0;
        max_Y1_value <= 0;
        max_X2_value <= 0;
        max_Y2_value <= 0;
        active_current <= 0;
        active_max_tmp <= 0;
    end
    else begin
        if(state == COMP) begin
            if(iteration[0] == 0) begin
                max2_value <= 0;
                if(data_idx == 5) begin
                    current_value <= 0;
                    active_current <= 0;
                    if(current_value >= max1_value) begin
                        max1_value <= current_value;
                        max_X1_value <= circle1_X;
                        max_Y1_value <= circle1_Y;
                        active_max_tmp <= active_current;
                    end
                    // else begin
                    //     max1_value <= max1_value;
                    //     max_X1_value <= max_X1_value;
                    //     max_Y1_value <= max_Y1_value;
                    // end
                end
                else if(|inside_flag) begin
                    current_value <= current_value + (!active_max[data_idx*8 + 0] && inside_flag[0]) + (!active_max[data_idx*8 + 1] && inside_flag[1]) + (!active_max[data_idx*8 + 2] && inside_flag[2]) + (!active_max[data_idx*8 + 3] && inside_flag[3]) + (!active_max[data_idx*8 + 4] && inside_flag[4]) + (!active_max[data_idx*8 + 5] && inside_flag[5]) + (!active_max[data_idx*8 + 6] && inside_flag[6]) + (!active_max[data_idx*8 + 7] && inside_flag[7]);
                    // max1_value <= max1_value;
                    active_current[data_idx*8+:8] <= inside_flag;

                end
                // else begin
                //     current_value <= current_value;
                //     max1_value <= max1_value;
                // end
            end
            else begin
                max1_value <= 0;
                if(data_idx == 5) begin
                    current_value <= 0;
                    active_current <= 0;
                    if(current_value >= max2_value) begin
                        max2_value <= current_value;
                        max_X2_value <= circle2_X;
                        max_Y2_value <= circle2_Y;
                        active_max_tmp <= active_current;
                    end
                    // else begin
                    //     max2_value <= max2_value;
                    //     max_X2_value <= max_X2_value;
                    //     max_Y2_value <= max_Y2_value;
                    // end
                end
                else if(|inside_flag) begin
                    current_value <= current_value + (!active_max[data_idx*8 + 0] && inside_flag[0]) + (!active_max[data_idx*8 + 1] && inside_flag[1]) + (!active_max[data_idx*8 + 2] && inside_flag[2]) + (!active_max[data_idx*8 + 3] && inside_flag[3]) + (!active_max[data_idx*8 + 4] && inside_flag[4]) + (!active_max[data_idx*8 + 5] && inside_flag[5]) + (!active_max[data_idx*8 + 6] && inside_flag[6]) + (!active_max[data_idx*8 + 7] && inside_flag[7]);
                    // max2_value <= max2_value;
                    active_current[data_idx*8+:8] <= inside_flag;
                end
                // else begin
                //     current_value <= current_value;
                //     max2_value <= max2_value;
                // end
            end

        end
        else begin
            current_value <= 0;
            max1_value <= 0;
            max2_value <= 0;
            max_X1_value <= 0;
            max_Y1_value <= 0;
            max_X2_value <= 0;
            max_Y2_value <= 0;
            active_current <= 0;
            active_max_tmp <= 0;
        end
    end
end

// Output data
always@(posedge CLK) begin
    if(RST) DONE <= 1;
    else if(finish == 1 && state == COMP) DONE <= 1;
    else DONE <= 0;
end

always@(posedge CLK) begin
    if(RST) begin
        C1X <= 0;
        C1Y <= 0;
        C2X <= 0;
        C2Y <= 0;
    end
    else if (finish == 1) begin
        C1X <= max_X1_value;
        C1Y <= max_Y1_value;
        C2X <= max_X2_value;
        C2Y <= max_Y2_value;
    end
end


endmodule