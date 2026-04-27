`timescale 1ns/1ps

module bcd7seg(
    input [3:0] digit,
    output reg [6:0] seg_n
);

always @(*) begin
    case (digit)
        4'd0: seg_n = 7'b000_0001;
        4'd1: seg_n = 7'b100_1111;
        4'd2: seg_n = 7'b001_0010;
        4'd3: seg_n = 7'b000_0110;
        4'd4: seg_n = 7'b100_1100;
        4'd5: seg_n = 7'b010_0100;
        4'd6: seg_n = 7'b010_0000;
        4'd7: seg_n = 7'b000_1111;
        4'd8: seg_n = 7'b000_0000;
        4'd9: seg_n = 7'b000_0100;
        default:
                seg_n = 7'b111_1111;
    endcase
end

endmodule