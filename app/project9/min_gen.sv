`timescale 1ns/1ps

module min_gen (
    input logic clk,
    input logic rst,
    input logic sec_rollover,
    output logic [5:0] minutes,
    output logic min_rollover
);

    always_ff @(posedge clk) begin
        if (rst) begin
            minutes <= '0;
            min_rollover <= '0;
        end
        else begin
            min_rollover <= '0;
            if (sec_rollover) begin
                if (minutes == 6'd59) begin
                    min_rollover <= '1;
                    minutes <= '0;
                end
                else begin
                    minutes <= minutes + 1;
                end
            end
        end
    end 
endmodule