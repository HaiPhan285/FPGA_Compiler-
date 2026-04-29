`timescale 1ns/1ps

// Module: rtc_ch12_6cases_tb
// Purpose: Focused Chapter 12 integration testbench for 6 selected whole-system concerns.

module rtc_ch12_6cases_tb;

    parameter CLK_PERIOD_NS   = 10;
    parameter FAST_DIVISOR    = 4;
    parameter BTN_HOLD_CYCLES = 8;

    localparam RUN       = 3'd0;
    localparam SET_MIN   = 3'd1;
    localparam SET_HOUR  = 3'd2;
    localparam SET_DAY   = 3'd3;
    localparam SET_MONTH = 3'd4;
    localparam SET_YEAR  = 3'd5;

    reg         CLK100MHZ;
    reg         CPU_RESETN;
    reg  [1:0]  SW;
    reg         BTNC;
    reg         BTNL;
    reg         BTNR;
    reg         BTND;
    wire [6:0]  SEG;
    wire        DP;
    wire [7:0]  AN;

    integer sampled_digits [0:7];
    integer idx;
    integer before_sec, before_min, before_hour, before_day, before_month, before_year;

    top #(
        .DIVISOR(FAST_DIVISOR),
        .DEBOUNCE_CYCLES(4)
    ) dut (
        .CLK100MHZ  (CLK100MHZ),
        .CPU_RESETN (CPU_RESETN),
        .SW         (SW),
        .BTNC       (BTNC),
        .BTNL       (BTNL),
        .BTNR       (BTNR),
        .BTND       (BTND),
        .SEG        (SEG),
        .DP         (DP),
        .AN         (AN)
    );

    initial begin
        CLK100MHZ = 1'b0;
        forever #(CLK_PERIOD_NS/2) CLK100MHZ = ~CLK100MHZ;
    end

    function integer seg_to_digit;
        input [6:0] seg;
        begin
            case (seg)
                7'b1000000: seg_to_digit = 0;
                7'b1111001: seg_to_digit = 1;
                7'b0100100: seg_to_digit = 2;
                7'b0110000: seg_to_digit = 3;
                7'b0011001: seg_to_digit = 4;
                7'b0010010: seg_to_digit = 5;
                7'b0000010: seg_to_digit = 6;
                7'b1111000: seg_to_digit = 7;
                7'b0000000: seg_to_digit = 8;
                7'b0010000: seg_to_digit = 9;
                7'b1111111: seg_to_digit = -1;
                default:    seg_to_digit = -2;
            endcase
        end
    endfunction

    task expect_true;
        input cond;
        input [1023:0] msg;
        begin
            if (!cond) begin
                $display("FAIL: %0s", msg);
                $display("DEBUG: state=%0d date=%0d-%0d-%0d time=%0d:%0d:%0d",
                    dut.state, dut.year, dut.month, dut.day, dut.hour, dut.minute, dut.second);
                $finish;
            end
            else begin
                $display("PASS: %0s", msg);
            end
        end
    endtask

    task expect_state;
        input [2:0] expected;
        input [1023:0] msg;
        begin
            expect_true(dut.state === expected, msg);
        end
    endtask

    task expect_datetime;
        input integer exp_sec;
        input integer exp_min;
        input integer exp_hour;
        input integer exp_day;
        input integer exp_month;
        input integer exp_year;
        input [1023:0] msg;
        begin
            expect_true(
                (dut.second == exp_sec) &&
                (dut.minute == exp_min) &&
                (dut.hour   == exp_hour) &&
                (dut.day    == exp_day) &&
                (dut.month  == exp_month) &&
                (dut.year   == exp_year),
                msg
            );
        end
    endtask

    task apply_reset;
        begin
            CPU_RESETN = 1'b0;
            BTNC = 1'b0;
            BTNL = 1'b0;
            BTNR = 1'b0;
            BTND = 1'b0;
            SW   = 2'b00;
            repeat (4) @(posedge CLK100MHZ);
            CPU_RESETN = 1'b1;
            @(posedge CLK100MHZ);
            #1;
        end
    endtask

    task press_mode;
        begin
            BTNL = 1'b1;
            repeat (BTN_HOLD_CYCLES) @(posedge CLK100MHZ);
            BTNL = 1'b0;
            repeat (BTN_HOLD_CYCLES) @(posedge CLK100MHZ);
        end
    endtask

    task press_next;
        begin
            BTNR = 1'b1;
            repeat (BTN_HOLD_CYCLES) @(posedge CLK100MHZ);
            BTNR = 1'b0;
            repeat (BTN_HOLD_CYCLES) @(posedge CLK100MHZ);
        end
    endtask

    task press_inc;
        begin
            BTNC = 1'b1;
            repeat (BTN_HOLD_CYCLES) @(posedge CLK100MHZ);
            BTNC = 1'b0;
            repeat (BTN_HOLD_CYCLES) @(posedge CLK100MHZ);
        end
    endtask

    task press_dec;
        begin
            BTND = 1'b1;
            repeat (BTN_HOLD_CYCLES) @(posedge CLK100MHZ);
            BTND = 1'b0;
            repeat (BTN_HOLD_CYCLES) @(posedge CLK100MHZ);
        end
    endtask

    task wait_run_ticks;
        input integer n;
        integer k;
        begin
            for (k = 0; k < n; k = k + 1) begin
                @(posedge dut.tick_1hz);
                @(negedge dut.tick_1hz);
                @(posedge CLK100MHZ);
                #1;
            end
        end
    endtask

    task preload_datetime;
        input integer sec_i;
        input integer min_i;
        input integer hour_i;
        input integer day_i;
        input integer month_i;
        input integer year_i;
        begin
            @(negedge CLK100MHZ);
            dut.u_data.second = sec_i[5:0];
            dut.u_data.minute = min_i[5:0];
            dut.u_data.hour   = hour_i[4:0];
            dut.u_data.day    = day_i[5:0];
            dut.u_data.month  = month_i[3:0];
            dut.u_data.year   = year_i[15:0];
            dut.u_data.day_rollover = 1'b0;
            dut.u_data.day_n   = day_i[5:0];
            dut.u_data.month_n = month_i[3:0];
            dut.u_data.year_n  = year_i[15:0];
            @(posedge CLK100MHZ);
            #1;
        end
    endtask

    task capture_display;
        reg [7:0] seen;
        integer guard;
        integer i;
        begin
            force dut.tick_1hz = 1'b0;
            seen  = 8'h00;
            guard = 0;
            for (i = 0; i < 8; i = i + 1)
                sampled_digits[i] = -3;

            while ((seen != 8'hFF) && (guard < 200000)) begin
                @(posedge CLK100MHZ);
                guard = guard + 1;
                idx = -1;
                case (AN)
                    8'b1111_1110: idx = 0;
                    8'b1111_1101: idx = 1;
                    8'b1111_1011: idx = 2;
                    8'b1111_0111: idx = 3;
                    8'b1110_1111: idx = 4;
                    8'b1101_1111: idx = 5;
                    8'b1011_1111: idx = 6;
                    8'b0111_1111: idx = 7;
                    default: idx = -1;
                endcase
                if (idx >= 0) begin
                    seen[idx] = 1'b1;
                    sampled_digits[idx] = seg_to_digit(SEG);
                end
            end
            release dut.tick_1hz;
            expect_true(seen == 8'hFF, "Captured all 8 multiplexed digits");
        end
    endtask

    task expect_time_display;
        input integer exp_hour;
        input integer exp_min;
        input integer exp_sec;
        input [1023:0] msg;
        integer h_tens, h_ones, m_tens, m_ones, s_tens, s_ones;
        begin
            h_tens = exp_hour / 10;
            h_ones = exp_hour % 10;
            m_tens = exp_min  / 10;
            m_ones = exp_min  % 10;
            s_tens = exp_sec  / 10;
            s_ones = exp_sec  % 10;
            SW = 2'b00;
            capture_display;
            expect_true(
                (sampled_digits[7] == -1) &&
                (sampled_digits[6] == -1) &&
                (sampled_digits[5] == h_tens) &&
                (sampled_digits[4] == h_ones) &&
                (sampled_digits[3] == m_tens) &&
                (sampled_digits[2] == m_ones) &&
                (sampled_digits[1] == s_tens) &&
                (sampled_digits[0] == s_ones),
                msg
            );
        end
    endtask

    task expect_calendar_display;
        input integer exp_year;
        input integer exp_month;
        input integer exp_day;
        input [1023:0] msg;
        integer y_th, y_hu, y_te, y_on, mo_t, mo_o, d_t, d_o;
        begin
            y_th = (exp_year / 1000) % 10;
            y_hu = (exp_year / 100)  % 10;
            y_te = (exp_year / 10)   % 10;
            y_on =  exp_year         % 10;
            mo_t =  exp_month / 10;
            mo_o =  exp_month % 10;
            d_t  =  exp_day   / 10;
            d_o  =  exp_day   % 10;
            SW = 2'b01;
            capture_display;
            expect_true(
                (sampled_digits[7] == y_th) &&
                (sampled_digits[6] == y_hu) &&
                (sampled_digits[5] == y_te) &&
                (sampled_digits[4] == y_on) &&
                (sampled_digits[3] == mo_t) &&
                (sampled_digits[2] == mo_o) &&
                (sampled_digits[1] == d_t)  &&
                (sampled_digits[0] == d_o),
                msg
            );
        end
    endtask

    initial begin
        $display("==== rtc_ch12_6cases_tb starting ====");
        CPU_RESETN = 1'b1;
        SW         = 2'b00;
        BTNC       = 1'b0;
        BTNL       = 1'b0;
        BTNR       = 1'b0;
        BTND       = 1'b0;

        // Case 1: tick path works in RUN mode
        apply_reset;
        preload_datetime(58, 34, 12, 10, 10, 2026);
        wait_run_ticks(1);
        expect_datetime(59, 34, 12, 10, 10, 2026,
            "Case 1: tick reaches datapath correctly in RUN mode");

        // Case 2: tick pauses in set mode
        press_mode;
        expect_state(SET_MIN, "Entered SET_MIN");
        before_sec   = dut.second;
        before_min   = dut.minute;
        before_hour  = dut.hour;
        before_day   = dut.day;
        before_month = dut.month;
        before_year  = dut.year;
        repeat (3) begin
            @(posedge dut.tick_1hz);
            @(negedge dut.tick_1hz);
            @(posedge CLK100MHZ);
            #1;
        end
        expect_datetime(before_sec, before_min, before_hour, before_day, before_month, before_year,
            "Case 2: RTC state does not advance while in set mode");

        // Case 3: display matches canonical state
        apply_reset;
        preload_datetime(45, 23, 14, 9, 12, 2026);
        expect_time_display(14, 23, 45,
            "Case 3a: time display matches canonical HHMMSS state");
        expect_calendar_display(2026, 12, 9,
            "Case 3b: calendar display matches canonical YYYYMMDD state");

        // Case 4: reset during set mode returns to safe state
        apply_reset;
        preload_datetime(0, 12, 7, 15, 8, 2030);
        press_mode;
        expect_state(SET_MIN, "Entered set mode before reset test");
        press_inc;
        apply_reset;
        expect_state(RUN, "Case 4a: reset from set mode returns FSM to RUN");
        expect_datetime(0, 0, 0, 1, 1, 2026,
            "Case 4b: reset from set mode restores documented startup state");

        // Case 5: FSM/datapath state consistency for each edit field
        apply_reset;
        preload_datetime(10, 20, 5, 11, 6, 2026);
        press_mode;
        press_inc;
        expect_datetime(10, 21, 5, 11, 6, 2026,
            "Case 5a: SET_MIN edits minute only");
        press_next;
        press_inc;
        expect_datetime(10, 21, 6, 11, 6, 2026,
            "Case 5b: SET_HOUR edits hour only");
        press_next;
        press_inc;
        expect_datetime(10, 21, 6, 12, 6, 2026,
            "Case 5c: SET_DAY edits day only");
        press_next;
        press_inc;
        expect_datetime(10, 21, 6, 12, 7, 2026,
            "Case 5d: SET_MONTH edits month only");
        press_next;
        press_inc;
        expect_datetime(10, 21, 6, 12, 7, 2027,
            "Case 5e: SET_YEAR edits year only");

        // Case 6: intended field changes and illegal date is corrected
        apply_reset;
        preload_datetime(0, 0, 0, 31, 3, 2026);
        press_mode;
        press_next;
        press_next;
        press_next;
        expect_state(SET_MONTH, "Reached SET_MONTH for legality test");
        press_inc;
        expect_datetime(0, 0, 0, 30, 4, 2026,
            "Case 6: month edit applies to intended field and clamps illegal date");

        $display("==== ALL 6 CHAPTER-12 RTC INTEGRATION TESTS PASSED ====");
        $finish;
    end

endmodule