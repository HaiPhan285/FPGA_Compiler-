`timescale 1ns/1ps

module min_gen (
    input clk,
    input rst,
    input min_pulse,
    input sec_rollover,
    output reg [5:0] minutes,
    output reg min_rollover
);

    always @(posedge clk) begin
        if (rst) begin
            minutes <= 0;
            min_rollover <= 0;
        end
        else begin
            min_rollover <= 0;
            if (sec_rollover || min_pulse) begin
                if (minutes == 6'd59) begin
                    min_rollover <= 1;
                    minutes <= 0;
                end
                else begin
                    minutes <= minutes + 1;
                end
            end
        end
    end 
endmodule