`timescale 1ns/1ps

module leap_year (
    input [15:0] year,
    output wire leap
);

    assign leap = ((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0);

endmodule