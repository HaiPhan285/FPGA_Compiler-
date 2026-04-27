`timescale 1ns/1ps

module top_7 (
    input        CLK100MHZ,
    input        CPU_RESETN,
    input[2:0]   SW,
    input         BTNC,
    input         BTNL,
    input         BTNR,
    input         BTNU,
    input         BTND,  

    
    output reg      CA,
    output reg      CB,
    output reg      CC,
    output reg      CD,
    output reg      CE,
    output reg      CF,
    output reg      CG,
    output wire      DP,
    output wire[7:0] AN
);

    wire rst;
    assign rst = ~CPU_RESETN;

//Do buttons for manual increment of time units 
    wire sec_pulse, min_pulse, hr_pulse, day_pulse, month_pulse, year_pulse;
    sync_deb_edge u_sec_btn (
        .clk (CLK100MHZ),
        .reset (rst),
        .async_in (BTNR),
        .pulse_out (sec_pulse)
    );
    sync_deb_edge u_min_btn (
        .clk (CLK100MHZ),
        .reset (rst),
        .async_in (BTNC),
        .pulse_out (min_pulse)
    );
    sync_deb_edge u_hr_btn (
        .clk (CLK100MHZ),
        .reset (rst),
        .async_in (BTNL),
        .pulse_out (hr_pulse)
    );
    sync_deb_edge u_day_btn (
        .clk (CLK100MHZ),
        .reset (rst),
        .async_in (BTNU), 
        .pulse_out (day_pulse)
    );
    sync_deb_edge u_month_btn (
        .clk (CLK100MHZ),
        .reset (rst),
        .async_in (BTND), 
        .pulse_out (month_pulse)
    );
    sync_deb_edge u_year_btn (
        .clk (CLK100MHZ),
        .reset (rst),
        .async_in (SW[2]), 
        .pulse_out (year_pulse)
    );


//--------------------------------------------------------------------------
    // Intermediate signal for HH:MM:SS
    //--------------------------------------------------------------------------
    wire tick_1hz, sec_rollover, min_rollover, hour_rollover;

    wire [5:0] seconds;
    wire [5:0] minutes;
    wire [4:0] hours;


    tick_gen #(
        .DIVISOR(100_000_000)
    ) u_tick_gen (
        .clk (CLK100MHZ),
        .rst (rst),
        .tick (tick_1hz)
    );

    sec_gen u_sec_counter (
        .clk           (CLK100MHZ),
        .rst           (rst),
        .tick_1hz      (tick_1hz),
        .sec_pulse     (sec_pulse),
        .sec_rollover  (sec_rollover),
        .seconds       (seconds)
    );

    min_gen u_min_counter (
        .clk          (CLK100MHZ),
        .rst          (rst),
        .min_pulse     (min_pulse),
        .sec_rollover (sec_rollover),
        .minutes      (minutes),
        .min_rollover (min_rollover)
    );

    hour_gen u_hour_counter (
        .clk          (CLK100MHZ),
        .rst          (rst),
        .hr_pulse     (hr_pulse),
        .min_rollover (min_rollover),
        .hours        (hours),
        .hour_rollover (hour_rollover)
    );

    //Intermediate signals and handle YYYY:MM:DD 
    wire [15:0] year;
    wire [3:0] month;
    wire [5:0] day;
    wire [5:0] max_day;
    wire leap;
    wire month_rollover, day_rollover;

    leap_year u_leap (
        .year (year),
        .leap (leap)
    );
    month_length u_month_length (
        .month (month),
        .leap (leap),
        .max_day (max_day)
    );


    day_counter u_day_counter (
        .clk           (CLK100MHZ),
        .rst           (rst),
        .day_pulse     (day_pulse),
        .day_enable    (hour_rollover),
        .max_day         (max_day),
        .day            (day),
        .day_rollover   (day_rollover)
    );
    month_counter u_month_counter (
        .clk           (CLK100MHZ),
        .rst           (rst),
        .month_pulse     (month_pulse),
        .month_enable   (day_rollover),
        .month          (month),
        .month_rollover (month_rollover)
    );
    year_counter u_year_counter (
        .clk           (CLK100MHZ),
        .rst           (rst),
        .year_pulse     (year_pulse),
        .year_enable   (month_rollover),
        .year          (year)
    );

//--------------------------------------------------------------------------
//Digit extraction for 7-seg display
//--------------------------------------------------------------------------
    wire [3:0] year_thousands, year_hundreds, year_tens, year_ones;
    wire [3:0] month_tens, month_ones;
    wire [3:0] day_tens, day_ones;
    wire [3:0] hour_tens, hour_ones;
    wire [3:0] min_tens, min_ones;
    wire [3:0] sec_tens, sec_ones;

    rtc_digit_extract u_rtc_digit_extract (
        .seconds (seconds),
        .minutes (minutes),
        .hours (hours),
        .day (day),
        .month (month),
        .year (year),
        .sec_tens (sec_tens),
        .sec_ones (sec_ones),
        .min_tens (min_tens),
        .min_ones (min_ones),
        .hour_tens (hour_tens),
        .hour_ones (hour_ones),
        .day_tens (day_tens),
        .day_ones (day_ones),
        .month_tens (month_tens),
        .month_ones (month_ones),
        .year_thousands (year_thousands),
        .year_hundreds (year_hundreds),
        .year_tens (year_tens),
        .year_ones (year_ones)
    );

    //--------------------------------------------------------------------------
    // Display multiplexing
    // Use refresh counter to scan all 8 digits fast enough
    //--------------------------------------------------------------------------
     reg [16:0] refresh_counter;
     wire [2:0]  digit_sel;
     reg [3:0]  current_digit;
     wire       blank_digit;

    scan_engine u_scan_engine (
        .clk (CLK100MHZ),
        .rst (rst),
        .AN (AN),
        .DP (DP),
        .blank_digit (blank_digit),
        .digit_sel (digit_sel)
    );

    //Decide the current mode using switch 
    //3 modes 00, 01, 10 for YYYY, MM:DD, HH:MM respectively
    wire [3:0] d7, d6, d5, d4, d3, d2, d1, d0;
    wire[1:0] display_mode;
    assign display_mode = SW[1:0];
    rtc_mode_mux u_rtc_mode_mux (
        .display_mode (display_mode),
        .sec_tens (sec_tens),
        .sec_ones (sec_ones),
        .min_tens (min_tens),
        .min_ones (min_ones),
        .hour_tens (hour_tens),
        .hour_ones (hour_ones),
        .day_tens (day_tens),
        .day_ones (day_ones),
        .month_tens (month_tens),
        .month_ones (month_ones),
        .year_thousands (year_thousands),
        .year_hundreds (year_hundreds),
        .year_tens (year_tens),
        .year_ones (year_ones),
        .d7 (d7), .d6(d6), .d5(d5), .d4(d4), 
        .d3(d3), .d2(d2), .d1(d1), .d0(d0)
    );

    //Assign the current digit based on display_mode
    always @(*) begin
        current_digit = 4'hF;
        case(digit_sel) 
            3'd0: current_digit = d0;
            3'd1: current_digit = d1;
            3'd2: current_digit = d2;
            3'd3: current_digit = d3;
            3'd4: current_digit = d4;
            3'd5: current_digit = d5;
            3'd6: current_digit = d6;
            3'd7: current_digit = d7;
        endcase
    end

    //--------------------------------------------------------------------------
    // 7-segment decoder
    // Active-low segments: 0 = ON
    // Segment order: {CA, CB, CC, CD, CE, CF, CG}
    //--------------------------------------------------------------------------
    wire [6:0] seg_n;
    
    bcd7seg u_bcf7seg (
        .digit(current_digit),
        .seg_n(seg_n)
    );

    always @(*) begin
        if (blank_digit) begin
            {CA, CB, CC, CD, CE, CF, CG} = 7'b111_1111;
        end
        else begin
            {CA, CB, CC, CD, CE, CF, CG} = seg_n;
        end
    end

endmodule