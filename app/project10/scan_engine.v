`timescale 1ns/1ps

module scan_engine(
    input clk,
    input rst,
    output reg [7:0] AN,
    output reg DP,
    output reg blank_digit,
    output wire [2:0] digit_sel
);

    reg [16:0] refresh_counter;
    always @(posedge clk) begin
        if (rst)
            refresh_counter <= 0;
        else
            refresh_counter <= refresh_counter + 1'b1;
    end

    assign digit_sel = refresh_counter[16:14];

    //--------------------------------------------------------------------------
    // Digit select
    // Active-low AN on Nexys A7
    // Rightmost digit is AN[0]
    
    always @(*) begin
        AN          = 8'b1111_1111;
        DP          = 1'b1;       // decimal point off (active-low)
        blank_digit = 1'b0;

        case (digit_sel)
            3'd0: AN = 8'b1111_1110;   // AN[0]
            3'd1: AN = 8'b1111_1101;   // AN[1]
            3'd2: AN = 8'b1111_1011;   // AN[2]
            3'd3: AN = 8'b1111_0111;   // AN[3]
            3'd4: AN = 8'b1110_1111;   // AN[4]
            3'd5: AN = 8'b1101_1111;   // AN[5]
            3'd6: AN = 8'b1011_1111;   // AN[6]
            3'd7: AN = 8'b0111_1111;   // AN[7]
            default: begin
                AN = 8'b1111_1111;
                blank_digit = 1'b1;
            end
        endcase
    end
endmodule