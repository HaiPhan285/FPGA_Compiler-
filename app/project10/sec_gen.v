`timescale 1ns/1ps

module sec_gen (
    input clk,
    input rst,
    input tick_1hz,
    input sec_pulse,
    output reg sec_rollover,
    output reg [5:0] seconds
);

always @(posedge clk) begin
    if (rst) begin
        sec_rollover <= 0;
        seconds <= 0;
    end
    else begin
        sec_rollover <= 0;
        if (tick_1hz || sec_pulse) begin
            if (seconds == 6'd59) begin
                seconds <= 0;
                sec_rollover <= 1;
            end
            else begin
                seconds <= seconds + 1;
            end
        end
    end
end
endmodule