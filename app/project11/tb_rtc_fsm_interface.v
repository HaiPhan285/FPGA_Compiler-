`timescale 1ns/1ps

module tb_setting_interface_selfcheck;

    // ============================================================
    // DUT ports (match top exactly)
    // ============================================================
    reg         CLK100MHZ;
    reg         CPU_RESETN;
    reg  [1:0]  SW;
    reg         BTNC;   // NEXT
    reg         BTNL;   // INC
    reg         BTNR;   // MODE

    wire [5:0]  LED;
    wire        CA;
    wire        CB;
    wire        CC;
    wire        CD;
    wire        CE;
    wire        CF;
    wire        CG;
    wire        DP;
    wire [7:0]  AN;

    // ============================================================
    // Instantiate DUT
    // ============================================================
    top dut (
        .CLK100MHZ (CLK100MHZ),
        .CPU_RESETN(CPU_RESETN),
        .SW        (SW),
        .BTNC      (BTNC),
        .BTNL      (BTNL),
        .BTNR      (BTNR),
        .LED       (LED),
        .CA        (CA),
        .CB        (CB),
        .CC        (CC),
        .CD        (CD),
        .CE        (CE),
        .CF        (CF),
        .CG        (CG),
        .DP        (DP),
        .AN        (AN)
    );

    // ============================================================
    // Clock
    // ============================================================
    initial CLK100MHZ = 1'b0;
    always #5 CLK100MHZ = ~CLK100MHZ;   // 100 MHz

    // ============================================================
    // Constants from DUT RTL
    // ============================================================
    localparam integer DEBOUNCE_CYCLES = 2000000; // from top.v instantiations
    localparam integer EXTRA_MARGIN    = 2000;

    localparam [2:0] RUN        = 3'd0;
    localparam [2:0] SET_MINUTE = 3'd1;
    localparam [2:0] SET_HOUR   = 3'd2;
    localparam [2:0] SET_DAY    = 3'd3;
    localparam [2:0] SET_MONTH  = 3'd4;
    localparam [2:0] SET_YEAR   = 3'd5;

    // ============================================================
    // Internal probes
    // ============================================================
    wire        rst_i        = dut.rst;
    wire        next_pulse_i = dut.next_pulse;
    wire        inc_pulse_i  = dut.inc_pulse;
    wire        mode_pulse_i = dut.mode_pulse;

    wire [2:0]  state_i      = dut.state;

    wire [5:0]  second_i     = dut.second;
    wire [5:0]  minute_i     = dut.minute;
    wire [4:0]  hour_i       = dut.hour;
    wire [4:0]  day_i        = dut.day;
    wire [3:0]  month_i      = dut.month;
    wire [15:0] year_i       = dut.year;

    // ============================================================
    // Scorekeeping
    // ============================================================
    integer errors;
    integer mode_pulse_count;
    integer next_pulse_count;
    integer inc_pulse_count;

    initial begin
        errors           = 0;
        mode_pulse_count = 0;
        next_pulse_count = 0;
        inc_pulse_count  = 0;
    end

    always @(posedge CLK100MHZ) begin
        if (mode_pulse_i) mode_pulse_count <= mode_pulse_count + 1;
        if (next_pulse_i) next_pulse_count <= next_pulse_count + 1;
        if (inc_pulse_i)  inc_pulse_count  <= inc_pulse_count  + 1;
    end

    task automatic fail;
        input [8*120-1:0] msg;
        begin
            errors = errors + 1;
            $display("[%0t] FAIL: %0s", $time, msg);
        end
    endtask

    task automatic pass;
        input [8*120-1:0] msg;
        begin
            $display("[%0t] PASS: %0s", $time, msg);
        end
    endtask

    task automatic check_eq_int;
        input integer got;
        input integer exp;
        input [8*120-1:0] msg;
        begin
            if (got !== exp) begin
                $display("[%0t]      got=%0d expected=%0d", $time, got, exp);
                fail(msg);
            end
            else begin
                pass(msg);
            end
        end
    endtask

    // ============================================================
    // Helpers
    // ============================================================
    task automatic wait_clks;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge CLK100MHZ);
        end
    endtask

    function automatic integer is_leap_year;
        input integer y;
        begin
            if (((y % 4) == 0 && (y % 100) != 0) || ((y % 400) == 0))
                is_leap_year = 1;
            else
                is_leap_year = 0;
        end
    endfunction

    function automatic integer max_day_fn;
        input integer m;
        input integer y;
        begin
            case (m)
                1, 3, 5, 7, 8, 10, 12: max_day_fn = 31;
                4, 6, 9, 11:           max_day_fn = 30;
                2:                     max_day_fn = is_leap_year(y) ? 29 : 28;
                default:               max_day_fn = 31;
            endcase
        end
    endfunction

    task automatic check_legal_calendar;
        integer md;
        begin
            md = max_day_fn(month_i, year_i);

            if (month_i < 1 || month_i > 12)
                fail("Illegal month detected");

            if (day_i < 1 || day_i > md)
                fail("Illegal day detected for current month/year");

            if (year_i < 1)
                fail("Illegal year detected");
        end
    endtask

    task automatic check_known_run_state_after_reset;
        begin
            check_eq_int(state_i, RUN, "Reset returns FSM to RUN");
            check_eq_int(second_i, 0, "Reset clears seconds");
            check_eq_int(minute_i, 0, "Reset clears minutes");
            check_eq_int(hour_i,   0, "Reset clears hours");
            check_eq_int(day_i,    1, "Reset sets day=1");
            check_eq_int(month_i,  1, "Reset sets month=1");
            check_eq_int(year_i,   2025, "Reset sets year=2025");
        end
    endtask

    // ============================================================
    // Raw button stimulus
    // These drive the real raw button input with bounce, not clean pulses.
    // Bounce toggles never stay stable long enough to debounce until the
    // final intended press.
    // ============================================================
    task automatic raw_bounce_press_mode;
        integer i;
        begin
            BTNR = 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                BTNR = ~BTNR;
                wait_clks(3000); // 30 us, far below 20 ms debounce window
            end
            BTNR = 1'b1;
            wait_clks(DEBOUNCE_CYCLES + EXTRA_MARGIN);
            BTNR = 1'b0;
            wait_clks(DEBOUNCE_CYCLES + EXTRA_MARGIN);
        end
    endtask

    task automatic raw_bounce_press_next;
        integer i;
        begin
            BTNC = 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                BTNC = ~BTNC;
                wait_clks(2500);
            end
            BTNC = 1'b1;
            wait_clks(DEBOUNCE_CYCLES + EXTRA_MARGIN);
            BTNC = 1'b0;
            wait_clks(DEBOUNCE_CYCLES + EXTRA_MARGIN);
        end
    endtask

    task automatic raw_bounce_press_inc;
        integer i;
        begin
            BTNL = 1'b0;
            for (i = 0; i < 10; i = i + 1) begin
                BTNL = ~BTNL;
                wait_clks(2000);
            end
            BTNL = 1'b1;
            wait_clks(DEBOUNCE_CYCLES + EXTRA_MARGIN);
            BTNL = 1'b0;
            wait_clks(DEBOUNCE_CYCLES + EXTRA_MARGIN);
        end
    endtask

    task automatic hold_inc_high_no_repeat;
        input integer hold_cycles;
        begin
            BTNL = 1'b1;
            wait_clks(hold_cycles);
            BTNL = 1'b0;
            wait_clks(DEBOUNCE_CYCLES + EXTRA_MARGIN);
        end
    endtask

    task automatic reset_counters;
        begin
            mode_pulse_count = 0;
            next_pulse_count = 0;
            inc_pulse_count  = 0;
        end
    endtask

    // ============================================================
    // Invariant checker
    // ============================================================
    always @(posedge CLK100MHZ) begin
        if (!rst_i) begin
            check_legal_calendar();

            if (state_i > SET_YEAR)
                fail("Illegal FSM state detected");
        end
    end

    // ============================================================
    // Main test sequence
    // ============================================================
    integer before_hour;
    integer before_day;
    integer before_month;
    integer before_year;
    integer i;

    initial begin
        CPU_RESETN = 1'b0;
        SW         = 2'b01; // MM:DD display, though FSM/edit logic does not depend on it
        BTNC       = 1'b0;
        BTNL       = 1'b0;
        BTNR       = 1'b0;

        wait_clks(50);

        // Release reset
        CPU_RESETN = 1'b1;
        wait_clks(20);

        // --------------------------------------------------------
        // Test 1: Reset behavior returns to known run state
        // --------------------------------------------------------
        check_known_run_state_after_reset();

        // --------------------------------------------------------
        // Test 2: Enter set mode with bouncing MODE and confirm
        // exactly one mode transition / one pulse
        // --------------------------------------------------------
        reset_counters();
        raw_bounce_press_mode();

        check_eq_int(mode_pulse_count, 1, "Bouncing MODE creates exactly one mode pulse");
        check_eq_int(state_i, SET_MINUTE, "MODE from RUN enters SET_MINUTE exactly once");

        // --------------------------------------------------------
        // Move to SET_HOUR for hour increment test
        // --------------------------------------------------------
        reset_counters();
        raw_bounce_press_next();

        check_eq_int(next_pulse_count, 1, "Bouncing NEXT creates exactly one next pulse");
        check_eq_int(state_i, SET_HOUR, "NEXT advances SET_MINUTE -> SET_HOUR");

        // --------------------------------------------------------
        // Test 3: Increment hours with bouncing INC and confirm
        // exactly one increment
        // --------------------------------------------------------
        before_hour = hour_i;

        reset_counters();
        raw_bounce_press_inc();

        check_eq_int(inc_pulse_count, 1, "Bouncing INC creates exactly one inc pulse");
        check_eq_int(hour_i, ((before_hour + 1) % 24), "Bouncing INC increments hour exactly once");

        // --------------------------------------------------------
        // Test 4: Advance through all editable fields with NEXT
        // and confirm sequence wraps correctly
        // Current state: SET_HOUR
        // Expected path: DAY -> MONTH -> YEAR -> MINUTE -> HOUR
        // --------------------------------------------------------
        reset_counters();

        raw_bounce_press_next();
        check_eq_int(state_i, SET_DAY, "NEXT advances SET_HOUR -> SET_DAY");

        raw_bounce_press_next();
        check_eq_int(state_i, SET_MONTH, "NEXT advances SET_DAY -> SET_MONTH");

        raw_bounce_press_next();
        check_eq_int(state_i, SET_YEAR, "NEXT advances SET_MONTH -> SET_YEAR");

        raw_bounce_press_next();
        check_eq_int(state_i, SET_MINUTE, "NEXT wraps SET_YEAR -> SET_MINUTE");

        raw_bounce_press_next();
        check_eq_int(state_i, SET_HOUR, "NEXT continues SET_MINUTE -> SET_HOUR after wrap");

        check_eq_int(next_pulse_count, 5, "Five bouncing NEXT presses create exactly five next pulses");

        // --------------------------------------------------------
        // Test 5: Show holding INC high does not auto-repeat
        // Current state: SET_HOUR
        // --------------------------------------------------------
        before_hour = hour_i;

        reset_counters();
        hold_inc_high_no_repeat(DEBOUNCE_CYCLES * 3 + EXTRA_MARGIN);

        check_eq_int(inc_pulse_count, 1, "Holding INC high produces one pulse only");
        check_eq_int(hour_i, ((before_hour + 1) % 24), "Holding INC high does not repeatedly increment hour");

        // --------------------------------------------------------
        // Move to SET_DAY for calendar tests
        // --------------------------------------------------------
        reset_counters();
        raw_bounce_press_next();
        check_eq_int(state_i, SET_DAY, "NEXT enters SET_DAY for date tests");

        // --------------------------------------------------------
        // Test 6: Set year to leap year, edit February day,
        // confirm 29 allowed only when legal
        // --------------------------------------------------------
        // Force calendar to known values at clock edge boundaries.
        // This is acceptable in TB to place DUT in specific preconditions.
        force dut.u_cal.year  = 16'd2024;
        force dut.u_cal.month = 4'd2;
        force dut.u_cal.day   = 5'd28;
        wait_clks(2);
        release dut.u_cal.year;
        release dut.u_cal.month;
        release dut.u_cal.day;
        wait_clks(2);

        check_eq_int(year_i,  2024, "Forced setup year=2024");
        check_eq_int(month_i, 2,    "Forced setup month=2");
        check_eq_int(day_i,   28,   "Forced setup day=28");

        before_day = day_i;
        reset_counters();
        raw_bounce_press_inc();

        check_eq_int(inc_pulse_count, 1, "Leap-year day edit gets one inc pulse");
        check_eq_int(day_i, 29, "Leap year allows February 29");

        // Now non-leap year
        force dut.u_cal.year  = 16'd2023;
        force dut.u_cal.month = 4'd2;
        force dut.u_cal.day   = 5'd28;
        wait_clks(2);
        release dut.u_cal.year;
        release dut.u_cal.month;
        release dut.u_cal.day;
        wait_clks(2);

        check_eq_int(year_i,  2023, "Forced setup year=2023");
        check_eq_int(month_i, 2,    "Forced setup month=2");
        check_eq_int(day_i,   28,   "Forced setup day=28");

        reset_counters();
        raw_bounce_press_inc();

        check_eq_int(inc_pulse_count, 1, "Non-leap-year day edit gets one inc pulse");
        check_eq_int(day_i, 1, "Non-leap year disallows Feb 29 by wrapping 28 -> 1");

        // --------------------------------------------------------
        // Move to SET_MONTH for month clamp test
        // --------------------------------------------------------
        reset_counters();
        raw_bounce_press_next();
        check_eq_int(state_i, SET_MONTH, "NEXT enters SET_MONTH");

        // --------------------------------------------------------
        // Test 7: Change from a 31-day month to a 30-day month and
        // confirm day clamps correctly
        // Example: Jan 31 -> Feb clamps to max valid day for year
        // In 2025, Feb max day = 28
        // --------------------------------------------------------
        force dut.u_cal.year  = 16'd2025;
        force dut.u_cal.month = 4'd1;
        force dut.u_cal.day   = 5'd31;
        wait_clks(2);
        release dut.u_cal.year;
        release dut.u_cal.month;
        release dut.u_cal.day;
        wait_clks(2);

        check_eq_int(year_i,  2025, "Forced setup year=2025 for clamp test");
        check_eq_int(month_i, 1,    "Forced setup month=Jan");
        check_eq_int(day_i,   31,   "Forced setup day=31");

        before_month = month_i;
        before_day   = day_i;

        reset_counters();
        raw_bounce_press_inc(); // month_pulse in SET_MONTH: Jan -> Feb

        check_eq_int(inc_pulse_count, 1, "Month edit gets one inc pulse");
        check_eq_int(month_i, 2, "Month increments Jan -> Feb");
        check_eq_int(day_i, 28, "Day clamps correctly when moving 31-day month to Feb 2025");

        // Optional stronger clamp check for 31->30 specifically
        force dut.u_cal.year  = 16'd2025;
        force dut.u_cal.month = 4'd3;  // March
        force dut.u_cal.day   = 5'd31;
        wait_clks(2);
        release dut.u_cal.year;
        release dut.u_cal.month;
        release dut.u_cal.day;
        wait_clks(2);

        reset_counters();
        raw_bounce_press_inc(); // March -> April

        check_eq_int(month_i, 4, "Month increments Mar -> Apr");
        check_eq_int(day_i, 30, "Day clamps correctly when moving 31-day month to 30-day month");

        // --------------------------------------------------------
        // Test 8: Assert reset while in set mode and confirm
        // return cleanly to RUN mode
        // Current state is still SET_MONTH
        // --------------------------------------------------------
        if (state_i == RUN)
            fail("Precondition failed: expected to be in set mode before reset-in-set-mode test");

        CPU_RESETN = 1'b0;
        wait_clks(10);
        CPU_RESETN = 1'b1;
        wait_clks(20);

        check_known_run_state_after_reset();

        // --------------------------------------------------------
        // Final result
        // --------------------------------------------------------
        if (errors == 0) begin
            $display("");
            $display("======================================");
            $display("ALL SELF-CHECKING TESTS PASSED");
            $display("======================================");
        end
        else begin
            $display("");
            $display("======================================");
            $display("TESTBENCH FAILED WITH %0d ERROR(S)", errors);
            $display("======================================");
        end

        $finish;
    end

endmodule