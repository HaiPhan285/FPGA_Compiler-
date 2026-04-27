`timescale 1ns/1ps

module day_counter(
    input logic clk,
    input logic rst,
    input logic day_enable,
    input logic day_btn_pulse,
    input logic[5:0] max_day,
    output logic [5:0] day = 24,
    output logic day_rollover
);

always @(posedge clk) begin
    if (rst) begin
        day <= 1;
        day_rollover <= 0;
    end
    else begin
        day_rollover <= 0;
        if (day_enable || day_btn_pulse) begin
            if (day == max_day) begin
                day_rollover <= 1;
                day <= 1;
            end
            else day <= day + 1;
        end
    end
end

endmodule