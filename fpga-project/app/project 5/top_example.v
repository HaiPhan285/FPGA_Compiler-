// Example: 8-bit DFF instantiation
module top_example (
    input  wire       clk,
    input  wire       arst,
    input  wire       apreset,
    input  wire       en,
    input  wire [7:0] din,
    output wire [7:0] q_out,
    output wire [7:0] qn_out
);

    dff_allpins #(.WIDTH(8)) my_dff (
        .clk(clk),
        .arst(arst),
        .apreset(apreset),
        .en(en),
        .d(din),
        .q(q_out),
        .qn(qn_out)
    );

endmodule