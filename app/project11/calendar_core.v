`timescale 1ns/1ps

module calendar_core(
    input             clk,
    input             rst,
    input             day_tick,
    input             day_pulse,
    input             month_pulse,
    input             year_pulse,
    output reg [4:0]  day,
    output reg [3:0]  month,
    output reg [15:0] year
);

function [5:0] max_day;
    input [3:0]  month_in;
    input [15:0] year_in;
    begin
        case (month_in)
            4'd1, 4'd3, 4'd5, 4'd7, 4'd8, 4'd10, 4'd12: max_day = 6'd31;
            4'd4, 4'd6, 4'd9, 4'd11:                   max_day = 6'd30;
            4'd2: begin
                if (((year_in % 4) == 0 && (year_in % 100) != 0) ||
                    ((year_in % 400) == 0))
                    max_day = 6'd29;
                else
                    max_day = 6'd28;
            end
            default: max_day = 6'd31;
        endcase
    end
endfunction

reg [5:0]  next_day;
reg [3:0]  next_month;
reg [15:0] next_year;

always @(*) begin
    next_day   = day;
    next_month = month;
    next_year  = year;

    // live calendar update
    if (day_tick) begin
        if (day == max_day(month, year)) begin
            next_day = 6'd1;
            if (month == 4'd12) begin
                next_month = 4'd1;
                next_year  = year + 16'd1;
            end
            else begin
                next_month = month + 4'd1;
            end
        end
        else begin
            next_day = day + 6'd1;
        end
    end
    else begin
        // manual editing
        if (year_pulse) begin
            next_year = year + 16'd1;

            if (next_day > max_day(next_month, next_year))
                next_day = max_day(next_month, next_year);
        end
        else if (month_pulse) begin
            if (month == 4'd12)
                next_month = 4'd1;
            else
                next_month = month + 4'd1;

            if (next_day > max_day(next_month, next_year))
                next_day = max_day(next_month, next_year);
        end
        else if (day_pulse) begin
            if (day == max_day(month, year))
                next_day = 6'd1;
            else
                next_day = day + 6'd1;
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        day   <= 6'd1;
        month <= 4'd1;
        year  <= 16'd2025;
    end
    else begin
        day   <= next_day;
        month <= next_month;
        year  <= next_year;
    end
end

endmodule