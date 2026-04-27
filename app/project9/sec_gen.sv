`timescale 1ns/1ps

module sec_gen (
    input logic clk,
    input logic rst,
    input logic tick_1hz,
    output logic sec_rollover,
    output logic [5:0] seconds
);

always_ff @(posedge clk) begin
    if (rst) begin
        sec_rollover <= '0;
        seconds <= '0;
    end
    else begin
        sec_rollover <= '0;
        if (tick_1hz) begin
            if (seconds == 6'd59) begin
                seconds <= '0;
                sec_rollover <= '1;
            end
            else begin
                seconds <= seconds + 1;
            end
        end
    end
end
endmodule