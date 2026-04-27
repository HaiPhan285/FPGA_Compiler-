`timescale 1ns/1ps

module rtc_datapath(
    input clk,
    input rst,
    input tick_enable,
    input [2:0] state,
    input inc_pulse,

    output reg [5:0] second,
    output reg [5:0] minute,
    output reg [4:0] hour,
    output reg [4:0] day,
    output reg [3:0] month,
    output reg [15:0] year
);

localparam RUN = 3'd0,
           SET_MIN = 3'd1,
           SET_HOUR = 3'd2,
           SET_DAY = 3'd3,
           SET_MONTH = 3'd4,
           SET_YEAR = 3'd5;

reg day_rollover;
//Time HHMMSS handling
always @(posedge clk) begin
    if (rst) begin
        second <= 6'd0;
        minute <= 6'd0;
        hour <= 6'd0;
        day_rollover <= 1'b0;
    end
    else begin
        if (tick_enable) begin
            day_rollover <= 1'b0;
            if (second == 6'd59) begin
                second <= 6'd0;
                if (minute == 6'd59) begin
                    minute <= 6'd0;
                    if (hour == 5'd23) begin
                        hour <= 5'd0;
                        day_rollover <= 1'b1;
                    end
                    else 
                        hour <= hour + 5'd1;
                end
                else
                    minute <= minute + 6'd1;
            end
            else begin
                second <= second + 6'd1;
            end
        end

        //Manual editing of time 
        else begin
            if (state == SET_HOUR && inc_pulse) begin
                if (hour == 5'd23) hour <= 5'd0;
                else hour <= hour + 5'd1;
            end

            else if (state == SET_MIN && inc_pulse) begin
                if (minute == 6'd59) minute <= 6'd0;
                else minute <= minute + 6'd1;
            end
        end
    end
end

//Max day calculation to prevent illegal states
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

//Calendar DDMMYYYY handling
reg [5:0] day_n;
reg [3:0] month_n; 
reg [15:0] year_n;

always @(posedge clk) begin
    if (rst) begin
        day <= 6'd1;
        month <= 6'd1;
        year <= 16'd2026;
    end
    else begin
        day <= day_n;
        month <= month_n;
        year <= year_n;
    end
end

always @(*) begin
    day_n = day;
    month_n = month;
    year_n = year;

    if (day_rollover) begin
        if (day == max_day(month, year)) begin
            day_n = 6'd1;
            if (month == 4'd12) begin
                month_n = 6'd1;
                year_n = year + 16'd1;
            end
            else    
                month_n = month + 4'd1;
        end
        else
            day_n = day + 6'd1;
    end

    //Manual edit
    else begin
        if (state == SET_DAY && inc_pulse) begin
            if (day == max_day(month, year)) day_n = 6'd1;
            else day_n = day + 6'd1;
        end

        else if (state == SET_MONTH && inc_pulse) begin
            if (month == 4'd12) month_n = 4'd1;
            else month_n = month + 4'd1;

            if (day_n > max_day(month_n, year_n)) 
                day_n = max_day(month_n, year_n);
        end

        else if (state == SET_YEAR && inc_pulse) begin
            year_n = year + 16'd1;

            if (day_n > max_day(month_n, year_n))
                day_n = max_day(month_n, year_n);
        end
    end
end


endmodule