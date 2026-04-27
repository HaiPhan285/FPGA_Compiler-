`timescale 1ns/1ps

module minute_counter (
    input logic clk,
    input logic rst,
    input logic sec_rollover,
    input logic btn_min_pulse,
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
            if (sec_rollover || btn_min_pulse) begin
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