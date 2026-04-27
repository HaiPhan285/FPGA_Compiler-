`timescale 1ns/1ps

module year_counter (
    input logic clk,
    input logic rst,
    input logic btn_year_pulse,
    input logic year_enable,
    output logic [15:0] year = 2026
);

always @(posedge clk) begin
    if (rst) year <= 2026;
    else if (year_enable || btn_year_pulse) year <= year + 1;
end

endmodule