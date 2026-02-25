

// DFF_allpins.v
`timescale 1ns / 1ps

module dff_allpins #(
    parameter WIDTH = 1
) (
    input  wire                 clk,      // clock (rising edge)
    input  wire                 arst,     // asynchronous reset (active-high) -> clears Q to 0
    input  wire                 apreset,  // asynchronous preset (active-high) -> sets Q to 1
    input  wire                 en,       // synchronous enable (when 0, hold; when 1, sample D on posedge)
    input  wire [WIDTH-1:0]     d,        // data input
    output reg  [WIDTH-1:0]     q,        // output
    output wire [WIDTH-1:0]     qn        // inverted output (bitwise)
);

    // qn is simply bitwise complement of q
    assign qn = ~q;

    always @(posedge clk or posedge arst or posedge apreset) begin
        // Asynchronous preset / reset have priority here.
        if (arst) begin
            q <= {WIDTH{1'b0}};         // async clear
        end else if (apreset) begin
            q <= {WIDTH{1'b1}};         // async set
        end else begin
            // synchronous behavior on clock edge
            if (en) begin
                q <= d;
            end else begin
                q <= q;                // hold (explicit for clarity)
            end
        end
    end

endmodule