`timescale 1ns/1ps

module top_calendar_core (
    input  logic       CLK100MHZ,
    input  logic       CPU_RESETN,
    input logic        BTNU,
    input logic        BTNC,
    input logic        BTNL,
    input logic        BTNR,
    
    output logic[5:0]   LED,

    output logic       CA,
    output logic       CB,
    output logic       CC,
    output logic       CD,
    output logic       CE,
    output logic       CF,
    output logic       CG,
    output logic       DP,
    output logic [7:0] AN
);

logic rst;
assign rst = ~CPU_RESETN;

//--------------------------------------------------------------------------
    // Intermediate signal for HH:MM:SS
    //--------------------------------------------------------------------------
    logic tick_1hz;
    logic sec_rollover;
    logic min_rollover;
    logic hour_rollover;

    logic [5:0] seconds;
    logic [5:0] minutes;
    logic [4:0] hours;

    //Button hour pulse
    logic btn_hr_pulse;
    sync_deb_edge u_btn_hour (
        .clk       (CLK100MHZ),
        .reset     (rst),
        .async_in  (BTNU),
        .pulse_out (btn_hr_pulse)
    );

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
        .sec_rollover  (sec_rollover),
        .seconds       (seconds)
    );

    min_gen u_min_counter (
        .clk          (CLK100MHZ),
        .rst          (rst),
        .sec_rollover (sec_rollover),
        .minutes      (minutes),
        .min_rollover (min_rollover)
    );

    hour_gen u_hour_counter (
        .clk          (CLK100MHZ),
        .rst          (rst),
        .btn_hr_pulse (btn_hr_pulse),
        .min_rollover (min_rollover),
        .hours        (hours),
        .hour_rollover (hour_rollover)
    );

    //Intermediate signals and handle YYYY:MM:DD 
    logic [15:0] year;
    logic [3:0] month;
    logic [5:0] day;
    logic [5:0] max_day;
    logic leap;
    logic btn_year_pulse, btn_month_pulse, btn_day_pulse;
    logic month_rollover, day_rollover;

    leap_year u_leap (
        .year (year),
        .leap (leap)
    );
    month_length u_month_length (
        .month (month),
        .leap (leap),
        .max_day (max_day)
    );

    sync_deb_edge u_btn_year (
        .clk       (CLK100MHZ),
        .reset     (rst),
        .async_in  (BTNL),
        .pulse_out (btn_year_pulse)
    );
    sync_deb_edge u_btn_month (
        .clk       (CLK100MHZ),
        .reset     (rst),
        .async_in  (BTNC),
        .pulse_out (btn_month_pulse)
    );
    sync_deb_edge u_btn_day (
        .clk       (CLK100MHZ),
        .reset     (rst),
        .async_in  (BTNR),
        .pulse_out (btn_day_pulse)
    );

    day_counter u_day_counter (
        .clk           (CLK100MHZ),
        .rst           (rst),
        .day_enable    (hour_rollover),
        .day_btn_pulse (btn_day_pulse),
        .max_day         (max_day),
        .day            (day),
        .day_rollover   (day_rollover)
    );
    month_counter u_month_counter (
        .clk           (CLK100MHZ),
        .rst           (rst),
        .month_enable   (day_rollover),
        .month_btn_pulse (btn_month_pulse),
        .month          (month),
        .month_rollover (month_rollover)
    );
    year_counter u_year_counter (
        .clk           (CLK100MHZ),
        .rst           (rst),
        .btn_year_pulse (btn_year_pulse),
        .year_enable   (month_rollover),
        .year          (year)
    );

    assign LED[4:0] = hours;
    assign LED[5] = leap;

//--------------------------------------------------------------------------
    logic [3:0] year_thousands, year_hundreds, year_tens, year_ones,
                month_tens, month_ones,
                day_tens, day_ones;
    always_comb begin
        year_thousands = year / 1000;
        year_hundreds = (year %1000) / 100;
        year_tens = (year % 100) / 10;
        year_ones = year % 10;
        month_tens = month /10;
        month_ones = month % 10;
        day_tens = day /10;
        day_ones = day % 10;
    end

    //--------------------------------------------------------------------------
    // Display multiplexing
    // Use refresh counter to scan all 8 digits fast enough
    //--------------------------------------------------------------------------
    logic [16:0] refresh_counter;
    logic [2:0]  digit_sel;
    logic [3:0]  current_digit;
    logic        blank_digit;

    always_ff @(posedge CLK100MHZ) begin
        if (rst)
            refresh_counter <= '0;
        else
            refresh_counter <= refresh_counter + 1'b1;
    end

    assign digit_sel = refresh_counter[16:14];

    //--------------------------------------------------------------------------
    // Digit select
    // Active-low AN on Nexys A7
    // Rightmost digit is AN[0]
    
    always_comb begin
        AN          = 8'b1111_1111;
        DP          = 1'b1;       // decimal point off (active-low)
        current_digit = 4'd0;
        blank_digit = 1'b0;

        case (digit_sel)
            3'd0: begin
                AN = 8'b1111_1110;   // AN[0]
                current_digit = day_ones;
            end
            3'd1: begin
                AN = 8'b1111_1101;   // AN[1]
                current_digit = day_tens;
            end
            3'd2: begin
                AN = 8'b1111_1011;   // AN[2]
                current_digit = month_ones;
            end
            3'd3: begin
                AN = 8'b1111_0111;   // AN[3]
                current_digit = month_tens;
            end
            3'd4: begin
                AN = 8'b1110_1111;   // AN[4]
                current_digit = year_ones;
            end
            3'd5: begin
                AN = 8'b1101_1111;   // AN[5]
                current_digit = year_tens;
            end
            3'd6: begin
                AN = 8'b1011_1111;   // AN[6]
                current_digit = year_hundreds;
            end
            3'd7: begin
                AN = 8'b0111_1111;   // AN[7]
                current_digit = year_thousands;
            end
            default: begin
                AN = 8'b1111_1111;
                blank_digit = 1'b1;
            end
        endcase
    end

    //--------------------------------------------------------------------------
    // 7-segment decoder
    // Active-low segments: 0 = ON
    // Segment order: {CA, CB, CC, CD, CE, CF, CG}
    //--------------------------------------------------------------------------
    always_comb begin
        if (blank_digit) begin
            {CA, CB, CC, CD, CE, CF, CG} = 7'b111_1111;
        end
        else begin
            case (current_digit)
                4'd0: {CA, CB, CC, CD, CE, CF, CG} = 7'b000_0001;
                4'd1: {CA, CB, CC, CD, CE, CF, CG} = 7'b100_1111;
                4'd2: {CA, CB, CC, CD, CE, CF, CG} = 7'b001_0010;
                4'd3: {CA, CB, CC, CD, CE, CF, CG} = 7'b000_0110;
                4'd4: {CA, CB, CC, CD, CE, CF, CG} = 7'b100_1100;
                4'd5: {CA, CB, CC, CD, CE, CF, CG} = 7'b010_0100;
                4'd6: {CA, CB, CC, CD, CE, CF, CG} = 7'b010_0000;
                4'd7: {CA, CB, CC, CD, CE, CF, CG} = 7'b000_1111;
                4'd8: {CA, CB, CC, CD, CE, CF, CG} = 7'b000_0000;
                4'd9: {CA, CB, CC, CD, CE, CF, CG} = 7'b000_0100;
                default:
                      {CA, CB, CC, CD, CE, CF, CG} = 7'b111_1111;
            endcase
        end
    end

endmodule