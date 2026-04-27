`timescale 1ns/1ps

module hour_gen (
    input logic clk, 
    input logic rst,
    input logic min_rollover,
    input logic btn_hr_pulse,
    output logic [4:0] hours,
    output logic hour_rollover
);

    always_ff @(posedge clk) begin
        if (rst) begin
            hours <= 0;
            hour_rollover <= 0;
        end
        else begin
            hour_rollover <= 0;
            if (min_rollover || btn_hr_pulse) begin
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


