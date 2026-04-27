module main (
    input  [3:0] switch,
    output [6:0] segment,
    output [7:0] enable,
    output       dp
);

    assign dp     = 1'b1;
    assign enable = 8'b11111110;

    segment u_decoder (
        .x(switch),
        .segments(segment)
    );

endmodule