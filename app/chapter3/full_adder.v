module full_adder(
    input a,
    input b,
    input cin,
    output cout,
    output sum
);

    assign = a ^ b ^ cin;
    assign = (a & b) | (a & cin) | (b & cin);

endmodule