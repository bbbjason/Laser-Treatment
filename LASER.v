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

reg [3:0] X_d [0:39];
reg [3:0] Y_d [0:39];
reg [5:0] coord_idx;

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

endmodule
