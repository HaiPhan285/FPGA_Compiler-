`timescale 1ns/1ps

module month_length(
    input[3:0] month,
    input leap,
    output reg [5:0] max_day
);

always @(*) begin
    case (month) 
        4'd1, 4'd3, 4'd5, 4'd7, 4'd8,
        4'd10, 4'd12: max_day = 6'd31;
        4'd4, 4'd6, 4'd9, 4'd11: max_day = 6'd30;
        4'd2: max_day = (leap) ? 6'd29 : 6'd28;
        default: max_day = 6'd31;
    endcase
end

endmodule