`timescale 1ns/1ps

module month_counter (
    input logic clk, 
    input logic rst,
    input logic month_enable,
    input logic month_btn_pulse,
    output logic [3:0] month = 3,
    output logic month_rollover
);

always @(posedge clk) begin
    if (rst) begin
        month <= 1;
        month_rollover <= 0;
    end
    else begin
        month_rollover <= 0;
        if (month_enable || month_btn_pulse) begin
            if (month == 12) begin
                month_rollover <= 1;
                month <= 1;
            end
            else month <= month + 1;
        end
    end
end
endmodule