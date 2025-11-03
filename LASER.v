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

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        C1X <= 4'd0;
        C1Y <= 4'd0;
        C2X <= 4'd0;
        C2Y <= 4'd0;
        DONE <= 1'b0;
    end
    else begin
        C1X <= 4'd4;
        C1Y <= 4'd10;
        C2X <= 4'd11;
        C2Y <= 4'd12;
        DONE <= 1'b0;  
    end
end

endmodule

