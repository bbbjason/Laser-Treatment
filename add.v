// Example of a simple parameterized adder following project coding guidelines.
module add #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0] in_a,
    input  wire [WIDTH-1:0] in_b,
    output reg  [WIDTH-1:0] sum,
    output reg              carry_out
);

    always @* begin
        {carry_out, sum} = in_a + in_b;
    end

endmodule
