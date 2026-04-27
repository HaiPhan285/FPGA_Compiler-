`timescale 1ns/1ps

module top (
    input        CLK100MHZ,
    input        CPU_RESETN,
    input [1:0]   SW,
    input         BTNC,
    input         BTNL,
    input         BTNR,
    
    output [5:0]    LED,
    output reg      CA,
    output reg      CB,
    output reg      CC,
    output reg      CD,
    output reg      CE,
    output reg      CF,
    output reg      CG,
    output wire      DP,
    output wire [7:0] AN
);

    wire rst;
    assign rst = ~CPU_RESETN;

//Do buttons for manual increment of time units 
    wire next_pulse, inc_pulse, mode_pulse;
    wire btnc_sync, btnl_sync, btnr_sync;

    //Sync and deboucne and edge detect the button 
    button_sync u_sync_c (
        .clk(CLK100MHZ),
        .rst(rst),
        .btn_raw(BTNC),
        .btn_raw_sync(btnc_sync)
    );
    debounce_onepulse #(
        .DEBOUNCE_CYCLES(2000000)
    ) u_dbe_c (
        .clk(CLK100MHZ),
        .rst(rst),
        .async_in(btnc_sync),
        .pulse_out(next_pulse)
    );

    button_sync u_sync_l (
        .clk(CLK100MHZ),
        .rst(rst),
        .btn_raw(BTNL),
        .btn_raw_sync(btnl_sync)
    );
    debounce_onepulse #(
        .DEBOUNCE_CYCLES(2000000)
    ) u_dbe_l (
        .clk(CLK100MHZ),
        .rst(rst),
        .async_in(btnl_sync),
        .pulse_out(inc_pulse)
    );

    button_sync u_sync_r (
        .clk(CLK100MHZ),
        .rst(rst),
        .btn_raw(BTNR),
        .btn_raw_sync(btnr_sync)
    );
    debounce_onepulse #(
        .DEBOUNCE_CYCLES(2000000)
    ) u_dbe_r (
        .clk(CLK100MHZ),
        .rst(rst),
        .async_in(btnr_sync),
        .pulse_out(mode_pulse)
    );

//--------------------------------------------------------------------------
    // Rtc_edit_datapath and rtc_set_fsm to check the state and output the bitmask and pulses
//--------------------------------------------------------------------------
localparam RUN = 3'd0,
           SET_MINUTE = 3'd1,
           SET_HOUR = 3'd2,
           SET_DAY = 3'd3,
           SET_MONTH = 3'd4,
           SET_YEAR = 3'd5;

wire [2:0] state;
wire [7:0] blink_mask;
wire [1:0] display_mode;
assign display_mode = SW[1:0];
wire min_pulse, hr_pulse, day_pulse, month_pulse, year_pulse;

rtc_set_fsm u_fsm (
    .clk(CLK100MHZ),
    .rst(rst),
    .mode_pulse(mode_pulse),
    .next_pulse(next_pulse),
    .state(state)
);
rtc_edit_datapath u_edit (
    .state(state),
    .display_mode(display_mode),
    .inc_pulse(inc_pulse),
    .min_pulse (min_pulse),
    .hr_pulse (hr_pulse),
    .day_pulse (day_pulse),
    .month_pulse (month_pulse),
    .year_pulse (year_pulse),
    .blink_mask (blink_mask) 
);

//--------------------------------------------------------------------------
    // Time and calendar handle
//--------------------------------------------------------------------------
    wire tick_1hz;

    tick_gen #(
        .DIVISOR(100_000_000)
    ) u_tick_gen (
        .clk (CLK100MHZ),
        .rst (rst),
        .tick (tick_1hz)
    );
    
    wire rtc_tick, day_enable;
    assign rtc_tick = tick_1hz & (state == RUN);

    wire [5:0] second;
    wire [5:0] minute;
    wire [4:0] hour;
    wire [4:0] day;
    wire [3:0] month;
    wire [15:0] year;

    time_core u_time (
        .clk(CLK100MHZ),
        .rst(rst),
        .tick_enable(rtc_tick),
        .min_pulse(min_pulse),
        .hr_pulse(hr_pulse),
        .second(second),
        .minute(minute),
        .hour(hour),
        .day_enable(day_enable)
    );
    calendar_core u_cal (
        .clk(CLK100MHZ),
        .rst(rst),
        .day_tick(day_enable),
        .day_pulse(day_pulse),
        .month_pulse(month_pulse),
        .year_pulse(year_pulse),
        .day(day),
        .month(month),
        .year(year)
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
        .second (second),
        .minute (minute),
        .hour (hour),
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

    //Handle the blinking of digit based on current state
    reg [25:0] blink_ctr;
    always @(posedge CLK100MHZ) begin
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