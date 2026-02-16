`timescale 1ns / 1ps

module main #(parameter int W = 8)
(
    input  logic [W-1:0] A,
    input  logic [W-1:0] B,
    input  logic         sub,           // 0: add, 1: subtract (A - B)
    input  logic         signed_mode,    // 0: unsigned (overflow=0), 1: signed overflow enabled

    output logic [W-1:0] Y,
    output logic         carry_no_borrow, // add: carry-out, sub: 1 = no borrow
    output logic         overflow,
    output logic         zero,
    output logic         negative
);

    logic [W-1:0] B_eff;
    logic [W:0]   ext;
   
    // Two's-complement add/sub:
    // sub=0 -> A + B
    // sub=1 -> A + (~B) + 1 = A - B
    assign B_eff = B ^ {W{sub}};
    assign ext   = {1'b0, A} + {1'b0, B_eff} + sub;

    assign Y               = ext[W-1:0];
    assign carry_no_borrow = ext[W];

    // Flags
    assign zero     = (Y == '0);
    assign negative = Y[W-1];

    // Signed overflow flag (only meaningful when signed_mode=1)
    always_comb begin
        overflow = 1'b0;

        if (signed_mode) begin
            if (!sub) begin
                // ADD overflow: A and B same sign, result different sign
                overflow = (~(A[W-1] ^ B[W-1])) & (Y[W-1] ^ A[W-1]);
            end else begin
                // SUB overflow: A and B different sign, result sign differs from A
                overflow = (A[W-1] ^ B[W-1]) & (Y[W-1] ^ A[W-1]);
            end
        end
    end

endmodule

