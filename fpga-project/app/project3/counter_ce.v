module counter_ce #(
    parameter integer WIDTH = 8
)(
    input  wire clk,
    input  wire rst,     // synchronous reset
    input  wire ce,
    output reg  [WIDTH-1:0] q
);
    always @(posedge clk) begin
        if (rst) begin
            q <= {WIDTH{1'b0}};
        end else if (ce) begin
            q <= q + 1'b1;
        end
    end
endmodule