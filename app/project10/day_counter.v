`timescale 1ns/1ps

module day_counter(
    input clk,
    input rst,
    input day_enable,
    input day_pulse,
    input[5:0] max_day,
    output reg [5:0] day = 24,
    output reg day_rollover
);

always @(posedge clk) begin
    if (rst) begin
        day <= 1;
        day_rollover <= 0;
    end
    else begin
        day_rollover <= 0;
        if (day_enable || day_pulse) begin
            if (day == max_day) begin
                day_rollover <= 1;
                day <= 1;
            end
            else day <= day + 1;
        end
    end
end

endmodule