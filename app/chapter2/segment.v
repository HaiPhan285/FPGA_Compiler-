module segment (
    input  [3:0] x,
    output [6:0] segments
);

    // Segment a
    assign segments[6] = ~(
        (x[1] & x[2]) |
        (x[1] & ~x[3]) |
        (x[3] & ~x[0]) |
        (~x[0] & ~x[2]) |
        (x[0] & x[2] & ~x[3]) |
        (x[3] & ~x[1] & ~x[2])
    );

    // Segment b
    assign segments[5] = ~(
        (~x[2] & ~x[3]) |
        (~x[0] & ~x[2]) |
        (~x[0] & ~x[1] & ~x[3]) |
        (x[0] & x[1] & ~x[3]) |
        (x[0] & x[3] & ~x[1])
    );

    // Segment c
    assign segments[4] = ~(
        (~x[1] & ~x[3]) |
        (x[0] & ~x[1]) |
        (x[0] & ~x[3]) |
        (x[2] & ~x[3]) |
        (x[3] & ~x[2])
    );

    // Segment d
    assign segments[3] = ~(
        (~x[0] & ~x[2] & ~x[3]) |
        (x[0] & x[1] & ~x[2]) |
        (x[0] & x[2] & ~x[1]) |
        (x[1] & x[2] & ~x[0]) |
        (x[3] & ~x[1])
    );

    // Segment e
    assign segments[2] = ~(
        (~x[0] & ~x[2]) |
        (x[1] & ~x[0]) |
        (x[1] & x[3]) |
        (x[2] & x[3])
    );

    // Segment f
    assign segments[1] = ~(
        (~x[0] & ~x[1]) |
        (x[2] & ~x[0]) |
        (x[3] & ~x[2]) |
        (x[1] & x[3]) |
        (x[2] & ~x[1] & ~x[3])
    );

    // Segment g
    assign segments[0] = ~(
        (x[1] & ~x[0]) |
        (x[1] & ~x[2]) |
        (x[3] & ~x[2]) |
        (x[0] & x[3]) |
        (x[2] & ~x[1] & ~x[3])
    );

endmodule