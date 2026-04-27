`timescale 1ns/1ps

module year_counter (
    input clk,
    input rst,
    input year_pulse,
    input year_enable,
    output reg [15:0] year = 2026
);

always @(posedge clk) begin
    if (rst) year <= 2026;
    else if (year_enable || year_pulse) year <= year + 1;
end

endmodule