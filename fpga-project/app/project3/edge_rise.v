module edge_rise (
    input  wire clk,
    input  wire rst,        // synchronous reset
    input  wire level_in,
    output reg  pulse_out
);
    reg prev;

    always @(posedge clk) begin
        if (rst) begin
            prev      <= 1'b0;
            pulse_out <= 1'b0;
        end else begin
            pulse_out <= (level_in & ~prev);
            prev      <= level_in;
        end
    end
endmodule