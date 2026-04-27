`timescale 1ns/1ps

module month_counter (
    input clk, 
    input rst,
    input month_pulse,
    input month_enable,
    output reg [3:0] month = 3,
    output reg month_rollover
);

always @(posedge clk) begin
    if (rst) begin
        month <= 1;
        month_rollover <= 0;
    end
    else begin
        month_rollover <= 0;
        if (month_enable || month_pulse) begin
            if (month == 12) begin
                month_rollover <= 1;
                month <= 1;
            end
            else month <= month + 1;
        end
    end
end
endmodule