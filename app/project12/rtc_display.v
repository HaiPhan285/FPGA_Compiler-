`timescale 1ns/1ps

module rtc_display (
    input clk, 
    input rst,
    input [5:0] second,
    input [5:0] minute,
    input [4:0] hour,
    input [4:0] day,
    input [3:0] month,
    input [15:0] year,
    input [2:0] state,
    input [1:0] display_mode,
    
    output reg [6:0] seg_n,
    output reg [7:0] AN,
    output reg DP
);

localparam RUN = 3'd0,
           SET_MIN = 3'd1,
           SET_HOUR = 3'd2,
           SET_DAY = 3'd3,
           SET_MONTH = 3'd4,
           SET_YEAR = 3'd5;

//Digit extraction
reg [3:0] year_thousands, year_hundreds, year_tens, year_ones;
reg [3:0] month_tens, month_ones;
reg [3:0] day_tens, day_ones;
reg [3:0] hour_tens, hour_ones;
reg [3:0] min_tens, min_ones;
reg [3:0] sec_tens, sec_ones;

always @(*) begin
    year_thousands = year / 1000;
    year_hundreds = (year / 100) % 10;
    year_tens = (year / 10) % 10; 
    year_ones = year % 10;

    month_tens = month /10;
    month_ones = month % 10;
    day_tens = day /10;
    day_ones = day % 10;

    hour_tens = hour / 10;
    hour_ones = hour % 10;
    min_tens = minute / 10;
    min_ones = minute % 10;
    sec_tens = second /10;
    sec_ones = second % 10;
end

//Digit control based on display_mode
reg [3:0] d7, d6, d5, d4, d3, d2, d1, d0;
always @(*) begin
    d7 = 4'hF; d6 = 4'hF; d5 = 4'hF; d4 = 4'hF; 
    d3 = 4'hF; d2 = 4'hF; d1 = 4'hF; d0 = 4'hF;

    case (display_mode)
        2'b00: begin
            d5 = hour_tens; d4 = hour_ones;
            d3 = min_tens; d2 = min_ones;
            d1 = sec_tens; d0 = sec_ones;
        end
        2'b01: begin
            d7 = year_thousands; d6 = year_hundreds;
            d5 = year_tens; d4 = year_ones;
            d3 = month_tens; d2 = month_ones;
            d1 = day_tens; d0 = day_ones;
        end
        default: begin 
        end
    endcase
end

reg [7:0] blink_mask;

always @(*) begin
    blink_mask = 8'b0000_0000;

    //Control d0 - d7 depend on the mode and only during SET mode
    case (display_mode)
        2'b00: begin //Time mode
            case (state)
                SET_MIN: blink_mask = 8'b1100_1100;
                SET_HOUR: blink_mask = 8'b1111_0000;
                default: blink_mask = 8'b0000_0000;
            endcase
        end
        2'b01: begin //Calendar mode
            case (state)
                SET_DAY: blink_mask = 8'b0000_0011;
                SET_MONTH: blink_mask = 8'b0000_1100;
                SET_YEAR: blink_mask = 8'b1111_0000;
                default: blink_mask = 8'b0000_0000;
            endcase
        end
    default: blink_mask = 8'b0000_0000;
    endcase
end     

//Blinking handling while manual editing with blinking control
//and logic to output the blinking of value 
reg [25:0] blink_ctr;
always @(posedge clk) begin
    if (rst) 
        blink_ctr <= 26'd0;
    else
        blink_ctr <= blink_ctr + 26'd1; 
end

wire blink_phase = blink_ctr[25];
wire show_selected = (state == RUN) || ~blink_phase;

wire [3:0] bd7, bd6, bd5, bd4, bd3, bd2, bd1, bd0;
assign bd7 = (blink_mask[7] && !show_selected) ? 4'hF : d7;
assign bd6 = (blink_mask[6] && !show_selected) ? 4'hF : d6;
assign bd5 = (blink_mask[5] && !show_selected) ? 4'hF : d5;
assign bd4 = (blink_mask[4] && !show_selected) ? 4'hF : d4;
assign bd3 = (blink_mask[3] && !show_selected) ? 4'hF : d3;
assign bd2 = (blink_mask[2] && !show_selected) ? 4'hF : d2;
assign bd1 = (blink_mask[1] && !show_selected) ? 4'hF : d1;
assign bd0 = (blink_mask[0] && !show_selected) ? 4'hF : d0;


reg [16:0] refresh_counter;
always @(posedge clk) begin
    if (rst) refresh_counter <= 17'd0;
    else refresh_counter <= refresh_counter + 17'd1;
end

wire [2:0] digit_sel = refresh_counter[16:14];
reg blank_digit;
always @(*) begin
    AN = 8'b1111_1111;
    DP = 1'b1;
    blank_digit = 1'b1;
    case(digit_sel) 
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

reg [3:0] current_digit;
//Assign the current digit based on display_mode
always @(*) begin
    current_digit = 4'hF;
    case(digit_sel) 
        3'd0: current_digit = bd0;
        3'd1: current_digit = bd1;
        3'd2: current_digit = bd2;
        3'd3: current_digit = bd3;
        3'd4: current_digit = bd4;
        3'd5: current_digit = bd5;
        3'd6: current_digit = bd6;
        3'd7: current_digit = bd7;
    endcase
end

//Set the anode based on the digit value;
always @(*) begin
    case (current_digit)
        4'd0: seg_n = 7'b1000000;
        4'd1: seg_n = 7'b1111001;
        4'd2: seg_n = 7'b0100100;
        4'd3: seg_n = 7'b0110000;
        4'd4: seg_n = 7'b0011001;
        4'd5: seg_n = 7'b0010010;
        4'd6: seg_n = 7'b0000010;
        4'd7: seg_n = 7'b1111000;
        4'd8: seg_n = 7'b0000000;
        4'd9: seg_n = 7'b0010000;
        default: seg_n = 7'b1111111;
    endcase
end

endmodule