module half_adder#(parameter w = 8)
(
    input a, 
    input b,
    output sum,
    output cout
);

    assign sum = a ^ b;
    assign cout = a & b;

endmodule