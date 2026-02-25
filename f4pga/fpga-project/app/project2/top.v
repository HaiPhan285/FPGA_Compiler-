`timescale 1ns / 1ps

module top_fpga (
    input  wire [18:0] SW,       // switches
    output wire [3:0]  LED,      // flag LEDs
    output wire [6:0]  HEX0,     // lower hex digit (7-seg)
    output wire [6:0]  HEX1      // upper hex digit (7-seg)
);

    wire [7:0] y;
    wire       z_flag, n_flag, c_flag, v_flag;

    alu #(.w(8)) u_alu (
        .A        (SW[7:0]),
        .B        (SW[15:8]),
        .op       (SW[18:16]),
        .y        (y),
        .zero     (z_flag),
        .negative (n_flag),
        .carry    (c_flag),
        .overflow (v_flag)
    );

    assign LED[3] = z_flag;   // Z
    assign LED[2] = n_flag;   // N
    assign LED[1] = c_flag;   // C
    assign LED[0] = v_flag;   // V

    function [6:0] hex_to_7seg;
        input [3:0] nibble;
        case (nibble)
            4'h0: hex_to_7seg = ~7'b0111111; // 0
            4'h1: hex_to_7seg = ~7'b0000110; // 1
            4'h2: hex_to_7seg = ~7'b1011011; // 2
            4'h3: hex_to_7seg = ~7'b1001111; // 3
            4'h4: hex_to_7seg = ~7'b1100110; // 4
            4'h5: hex_to_7seg = ~7'b1101101; // 5
            4'h6: hex_to_7seg = ~7'b1111101; // 6
            4'h7: hex_to_7seg = ~7'b0000111; // 7
            4'h8: hex_to_7seg = ~7'b1111111; // 8
            4'h9: hex_to_7seg = ~7'b1101111; // 9
            4'hA: hex_to_7seg = ~7'b1110111; // A
            4'hB: hex_to_7seg = ~7'b1111100; // B
            4'hC: hex_to_7seg = ~7'b0111001; // C
            4'hD: hex_to_7seg = ~7'b1011110; // D
            4'hE: hex_to_7seg = ~7'b1111001; // E
            4'hF: hex_to_7seg = ~7'b1110001; // F
            default: hex_to_7seg = ~7'b0000000;
        endcase
    endfunction

    assign HEX0 = hex_to_7seg(y[3:0]);   // lower nibble
    assign HEX1 = hex_to_7seg(y[7:4]);   // upper nibble

endmodule