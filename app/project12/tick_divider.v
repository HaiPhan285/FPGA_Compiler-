`timescale 1ns/1ps

module tick_divider #(parameter integer DIVISOR = 100_000_000) 
(
    input clk,
    input rst,
    output reg tick
);

    reg [26:0] count;
    always @(posedge clk) begin
        if (rst) begin
            tick <= 1'b0;
            count <= 26'd0;
        end
        else begin
            tick <= 1'b0;
            if (count == DIVISOR-1) begin
                tick <= 1'b1;
                count <= 26'd0;
            end
            else begin
                count <= count + 26'd1;
            end
        end
    end
endmodule