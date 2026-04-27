`timescale 1ns/1ps

module tb_time_core;

    logic clk;
    logic rst;
    logic tick_1hz;

    logic sec_rollover;
    logic min_rollover;
    logic [5:0] seconds;
    logic [5:0] minutes;
    logic [4:0] hours;

    logic [5:0] prev_seconds;
    logic [5:0] prev_minutes;
    logic [4:0] prev_hours;
    logic prev_sec_rollover;
    logic prev_min_rollover;

    integer cycle_count;

    // Scoreboard
    integer exp_s, exp_m, exp_h;

    // Rollover pulse width counters
    integer sec_roll_high_cycles;
    integer min_roll_high_cycles;

    tick_gen #(
        .DIVISOR(4)
    ) u_tick_gen (
        .clk  (clk),
        .rst  (rst),
        .tick (tick_1hz)
    );

    second_counter u_second_counter (
        .clk          (clk),
        .rst          (rst),
        .tick_1hz     (tick_1hz),
        .sec_rollover (sec_rollover),
        .seconds      (seconds)
    );

    minute_counter u_minute_counter (
        .clk          (clk),
        .rst          (rst),
        .sec_rollover (sec_rollover),
        .minutes      (minutes),
        .min_rollover (min_rollover)
    );

    hour_counter u_hour_counter (
        .clk          (clk),
        .rst          (rst),
        .min_rollover (min_rollover),
        .hours        (hours)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task fail;
        input [8*120-1:0] msg;
        begin
            $display("FAIL @ t=%0t cycle=%0d : %0s", $time, cycle_count, msg);
            $display("DUT  hr=%0d min=%0d sec=%0d  sr=%0b mr=%0b",
                     hours, minutes, seconds, sec_rollover, min_rollover);
            $display("EXP  hr=%0d min=%0d sec=%0d",
                     exp_h, exp_m, exp_s);
            $fatal;
        end
    endtask

    task reset_expected;
        begin
            exp_s = 0;
            exp_m = 0;
            exp_h = 0;
        end
    endtask

    task step_expected;
        begin
            exp_s = exp_s + 1;
            if (exp_s == 60) begin
                exp_s = 0;
                exp_m = exp_m + 1;
                if (exp_m == 60) begin
                    exp_m = 0;
                    exp_h = exp_h + 1;
                    if (exp_h == 24)
                        exp_h = 0;
                end
            end
        end
    endtask

    task check_scoreboard;
        input [8*120-1:0] msg;
        begin
            if (seconds !== exp_s[5:0] ||
                minutes !== exp_m[5:0] ||
                hours   !== exp_h[4:0]) begin
                fail(msg);
            end
        end
    endtask

    task apply_reset;
        integer i;
        begin
            rst = 1'b1;
            for (i = 0; i < 5; i = i + 1)
                @(posedge clk);
            #1;
            rst = 1'b0;
            @(posedge clk);
            #1;
            reset_expected();
        end
    endtask

    task wait_tick_cycle;
        begin
            @(posedge clk);
            while (tick_1hz !== 1'b1)
                @(posedge clk);
            #1;
            step_expected();
        end
    endtask

    task wait_n_ticks;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                wait_tick_cycle();
        end
    endtask

    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        prev_seconds <= seconds;
        prev_minutes <= minutes;
        prev_hours <= hours;
        prev_sec_rollover <= sec_rollover;
        prev_min_rollover <= min_rollover;
    end

    always @(posedge clk) begin
        #1;
        if (!rst) begin
            if (seconds > 59) fail("seconds out of range");
            if (minutes > 59) fail("minutes out of range");
            if (hours   > 23) fail("hours out of range");

            if ((minutes != prev_minutes) && !prev_sec_rollover)
                fail("minutes changed without sec_rollover");

            if ((hours != prev_hours) && !prev_min_rollover)
                fail("hours changed without min_rollover");
        end
    end

    always @(posedge clk) begin
        #1;
        if (rst) begin
            sec_roll_high_cycles <= 0;
            min_roll_high_cycles <= 0;
        end
        else begin
            if (sec_rollover == 1'b1)
                sec_roll_high_cycles <= sec_roll_high_cycles + 1;
            else
                sec_roll_high_cycles <= 0;

            if (min_rollover == 1'b1)
                min_roll_high_cycles <= min_roll_high_cycles + 1;
            else
                min_roll_high_cycles <= 0;

            if (sec_roll_high_cycles > 1)
                fail("sec_rollover stayed high more than 1 cycle");

            if (min_roll_high_cycles > 1)
                fail("min_rollover stayed high more than 1 cycle");
        end
    end

    initial begin
        cycle_count = 0;
        prev_seconds = 0;
        prev_minutes = 0;
        prev_hours = 0;
        prev_sec_rollover = 0;
        prev_min_rollover = 0;
        sec_roll_high_cycles = 0;
        min_roll_high_cycles = 0;
        reset_expected();

        apply_reset();

        if (seconds !== 0 || minutes !== 0 || hours !== 0)
            fail("reset failed");
        check_scoreboard("scoreboard mismatch after reset");

        $display("TEST 1: 58 -> 59 -> 00 seconds rollover");
        wait_n_ticks(58);
        if (seconds !== 6'd58)
            fail("expected seconds = 58");
        check_scoreboard("scoreboard mismatch at second 58");

        wait_tick_cycle();
        if (seconds !== 6'd59)
            fail("58->59 failed");
        if (sec_rollover !== 1'b0)
            fail("sec_rollover asserted early");
        check_scoreboard("scoreboard mismatch at second 59");

        wait_tick_cycle();
        if (seconds !== 6'd0)
            check_scoreboard("scoreboard mismatch at second rollover 59->00");
            fail("59->00 seconds rollover failed");
        if (sec_rollover !== 1'b1)
            fail("sec_rollover missing at 59->00");

        @(posedge clk); #1;
        if (sec_rollover !== 1'b0)
            fail("sec_rollover did not clear");
        check_scoreboard("scoreboard mismatch after seconds rollover settle");

        $display("TEST 2: 58 -> 59 -> 00 minutes rollover");
        apply_reset();
        wait_n_ticks(58*60 + 59);
        if (minutes !== 6'd58 || seconds !== 6'd59)
            fail("failed to reach 58:59");
        check_scoreboard("scoreboard mismatch at 58:59");

        wait_tick_cycle();
        if (seconds !== 6'd0)
            fail("seconds did not roll at 58:59");

        @(posedge clk); #1;
        if (minutes !== 6'd59)
            fail("58->59 minutes step failed");
        if (min_rollover !== 1'b0)
            fail("min_rollover asserted early");
        check_scoreboard("scoreboard mismatch at 59:00");

        wait_n_ticks(59);
        if (minutes !== 6'd59 || seconds !== 6'd59)
            fail("failed to reach 59:59");
        check_scoreboard("scoreboard mismatch at 59:59");

        wait_tick_cycle();
        if (seconds !== 6'd0)
            fail("seconds did not roll at 59:59");

        @(posedge clk); #1;
        if (minutes !== 6'd0)
            fail("59->00 minutes rollover failed");
        if (min_rollover !== 1'b1)
            fail("min_rollover missing at 59->00");

        @(posedge clk); #1;
        if (min_rollover !== 1'b0)
            fail("min_rollover did not clear");
        check_scoreboard("scoreboard mismatch after minutes rollover settle");

        $display("TEST 3: 23:59:59 -> 00:00:00");
        apply_reset();
        wait_n_ticks(23*3600 + 59*60 + 59);
        if (hours !== 5'd23 || minutes !== 6'd59 || seconds !== 6'd59)
            fail("failed to reach 23:59:59");
        check_scoreboard("scoreboard mismatch at 23:59:59");

        wait_tick_cycle();
        if (sec_rollover !== 1'b1)
            fail("sec_rollover missing at midnight");

        @(posedge clk); #1;
        if (min_rollover !== 1'b1)
            fail("min_rollover missing at midnight");

        @(posedge clk); #1;
        if (hours !== 5'd0 || minutes !== 6'd0 || seconds !== 6'd0)
            fail("midnight rollover failed");
        check_scoreboard("scoreboard mismatch after midnight settle");

        $display("TEST 4: reset during rollover");
        apply_reset();
        wait_n_ticks(59);
        if (seconds !== 6'd59)
            fail("failed to reach second 59");
        check_scoreboard("scoreboard mismatch before reset during rollover");

        @(posedge clk);
        while (tick_1hz !== 1'b1)
            @(posedge clk);
        rst = 1'b1;
        #1;
        if (seconds !== 6'd0 || minutes !== 6'd0 || hours !== 5'd0)
            fail("reset during rollover did not clear state");

        @(posedge clk); #1;
        rst = 1'b0;
        @(posedge clk); #1;
        reset_expected();
        check_scoreboard("scoreboard mismatch after reset during rollover");

        $display("TEST 5: idle stability between ticks");
        apply_reset();
        @(posedge clk); #1;
        if (seconds !== 6'd0 || minutes !== 6'd0 || hours !== 5'd0)
            fail("post-reset state wrong");
        check_scoreboard("scoreboard mismatch after idle reset");

        @(posedge clk); #1;
        if (tick_1hz == 1'b0) begin
            if (seconds !== 6'd0 || minutes !== 6'd0 || hours !== 5'd0)
                fail("state changed without tick");
        end
        check_scoreboard("scoreboard mismatch during idle stability");

        $display("TEST 6: sec_rollover and min_rollover are one-cycle pulses");
        apply_reset();

        wait_n_ticks(59);
        if (seconds !== 6'd59)
            fail("failed to reach 00:00:59 for sec_rollover width test");

        wait_tick_cycle();
        if (sec_rollover !== 1'b1)
            fail("sec_rollover missing during width test");

        @(posedge clk); #1;
        if (sec_rollover !== 1'b0)
            fail("sec_rollover did not clear after 1 cycle");

        apply_reset();
        wait_n_ticks(59*60 + 59);
        if (minutes !== 6'd59 || seconds !== 6'd59)
            fail("failed to reach 00:59:59 for min_rollover width test");

        wait_tick_cycle();
        @(posedge clk); #1;
        if (min_rollover !== 1'b1)
            fail("min_rollover missing during width test");

        @(posedge clk); #1;
        if (min_rollover !== 1'b0)
            fail("min_rollover did not clear after 1 cycle");

        $display("PASS: tb_time_core completed all checks.");
        $finish;
    end

endmodule