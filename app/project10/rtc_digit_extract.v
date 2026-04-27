`timescale 1ns/1ps

module rtc_digit_extract(
    input [5:0] seconds,
    input [5:0] minutes,
    input [4:0] hours,
    input [5:0] day,
    input [3:0] month,
    input [15:0] year,

    output reg [3:0] sec_tens,
    output reg [3:0] sec_ones,
    output reg [3:0] min_tens,
    output reg [3:0] min_ones,
    output reg [3:0] hour_tens,
    output reg [3:0] hour_ones,
    output reg [3:0] day_tens,
    output reg [3:0] day_ones,
    output reg [3:0] month_tens,
    output reg [3:0] month_ones,
    output reg [3:0] year_thousands,
    output reg [3:0] year_hundreds,
    output reg [3:0] year_tens,
    output reg [3:0] year_ones
);

    always @(*) begin
        year_thousands = year / 1000;
        year_hundreds = (year %1000) / 100;
        year_tens = (year % 100) / 10;
        year_ones = year % 10;
        
        month_tens = month /10;
        month_ones = month % 10;
        day_tens = day /10;
        day_ones = day % 10;

        hour_tens = hours / 10;
        hour_ones = hours % 10;
        min_tens = minutes / 10;
        min_ones = minutes % 10;
        sec_tens = seconds /10;
        sec_ones = seconds % 10;
    end

endmodule