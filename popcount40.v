`timescale 1ns/10ps

module popcount40 (
    input  wire        clk,
    input  wire        RST,
    input  wire        in_valid,
    input  wire [39:0] union_mask,
    output reg         out_valid,
    output reg  [5:0]  out_count   // 0..40
);

// Stage 1 registers: local sums of 10 nibbles (0..8)
reg        vld_s1;
reg [3:0]  s1_s0, s1_s1, s1_s2, s1_s3, s1_s4; // five partial sums (each 0..8)

// Stage 2: directly produce out_count
wire [4:0] t0, t1; // 0..16
wire [5:0] u0;     // 0..32
wire [5:0] res;    // 0..40

// -----------------------
// Stage 1: OR + 10×pc4 + five pairwise adds, then register
// -----------------------
wire [2:0] c0 = pc4(union_mask[ 3: 0]);
wire [2:0] c1 = pc4(union_mask[ 7: 4]);
wire [2:0] c2 = pc4(union_mask[11: 8]);
wire [2:0] c3 = pc4(union_mask[15:12]);
wire [2:0] c4 = pc4(union_mask[19:16]);
wire [2:0] c5 = pc4(union_mask[23:20]);
wire [2:0] c6 = pc4(union_mask[27:24]);
wire [2:0] c7 = pc4(union_mask[31:28]);
wire [2:0] c8 = pc4(union_mask[35:32]);
wire [2:0] c9 = pc4(union_mask[39:36]);

wire [3:0] s0 = c0 + c1; // 0..8
wire [3:0] s1 = c2 + c3; // 0..8
wire [3:0] s2 = c4 + c5; // 0..8
wire [3:0] s3 = c6 + c7; // 0..8
wire [3:0] s4 = c8 + c9; // 0..8

always @(posedge clk or posedge RST) begin
    if (!RST) begin
        vld_s1  <= 1'b0;
        s1_s0   <= 4'd0;
        s1_s1   <= 4'd0;
        s1_s2   <= 4'd0;
        s1_s3   <= 4'd0;
        s1_s4   <= 4'd0;
    end else begin
        vld_s1  <= in_valid;
        s1_s0   <= s0;
        s1_s1   <= s1;
        s1_s2   <= s2;
        s1_s3   <= s3;
        s1_s4   <= s4;
    end
end

// -----------------------
// Stage 2: adder-tree reduction and register output
// -----------------------
assign t0  = s1_s0 + s1_s1;              // 0..16
assign t1  = s1_s2 + s1_s3;              // 0..16
assign u0  = t0 + t1;                    // 0..32
assign res = u0 + {1'b0, s1_s4};         // 0..40

always @(posedge clk or posedge RST) begin
    if (!RST) begin
        out_valid <= 1'b0;
        out_count <= 6'd0;
    end else begin
    out_valid <= vld_s1;             // one-cycle delay to align with Stage 2
        out_count <= res;
    end
end

// -----------------------
// 4-bit popcount (16-entry LUT)
// -----------------------
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
