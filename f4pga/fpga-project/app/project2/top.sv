`timescale 1ns / 1ps

module top (
    input  wire a,
    input  wire b,
    output wire y
);

    assign y = a & b;

endmodule
