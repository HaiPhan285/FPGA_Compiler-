`timescale 1ns/1ps

module hour_gen (
    input clk, 
    input rst,
    input hr_pulse,
    input min_rollover,
    output reg [4:0] hours,
    output reg hour_rollover
);

    always@(posedge clk) begin
        if (rst) begin
            hours <= 0;
            hour_rollover <= 0;
        end
        else begin
            hour_rollover <= 0;
            if (min_rollover || hr_pulse) begin
                if (hours == 5'd23) begin
                    hours <= 0;
                    hour_rollover <= 1;
                end
                else begin
                    hours <= hours + 1;
                end
            end
        end
    end
endmodule


