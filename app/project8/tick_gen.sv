`timescale 1ns / 1ps

module tick_gen #(parameter int DIVISOR = 100_000_000) (
    input logic clk,
    input logic rst,
    output logic tick
);

    logic [26:0] count;

    always_ff @(posedge clk) begin
        if (rst) begin
            count <= '0;
            tick <= '0;
        end
        else begin
            if (count == (DIVISOR-1)) begin
                count <= '0;
                tick <= '1;
            end
            else begin
                count <= count + 1;
                tick <= '0;
            end
        end
    end
endmodule