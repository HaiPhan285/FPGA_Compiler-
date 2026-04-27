`timescale 1ns/1ps
module tb_calendar_core;

    // ============================================================
    // Testbench signals
    // ============================================================
    logic clk;
    logic rst;

    logic day_enable;
    logic day_btn_pulse;
    logic month_btn_pulse;
    logic btn_year_pulse;

    logic [15:0] year;
    logic [3:0]  month;
    logic [5:0]  day;
    logic [5:0]  max_day;
    logic        leap;
    logic        day_rollover;
    logic        month_rollover;

    // ============================================================
    // Scoreboard expected state
    // ============================================================
    logic [15:0] exp_year;
    logic [3:0]  exp_month;
    logic [5:0]  exp_day;

    integer test_count;
    integer error_count;

    // ============================================================
    // Seed registers for force/release
    // ============================================================
    logic [5:0]  seed_day_reg;
    logic [3:0]  seed_month_reg;
    logic [15:0] seed_year_reg;

    // ============================================================
    // DUT pieces
    // ============================================================
    leap_year u_leap (
        .year(year),
        .leap(leap)
    );

    month_length u_month_length (
        .month(month),
        .leap(leap),
        .max_day(max_day)
    );

    day_counter u_day_counter (
        .clk(clk),
        .rst(rst),
        .day_enable(day_enable),
        .day_btn_pulse(day_btn_pulse),
        .max_day(max_day),
        .day(day),
        .day_rollover(day_rollover)
    );

    month_counter u_month_counter (
        .clk(clk),
        .rst(rst),
        .month_enable(day_rollover),
        .month_btn_pulse(month_btn_pulse),
        .month(month),
        .month_rollover(month_rollover)
    );

    year_counter u_year_counter (
        .clk(clk),
        .rst(rst),
        .btn_year_pulse(btn_year_pulse),
        .year_enable(month_rollover),
        .year(year)
    );

    // ============================================================
    // Clock
    // ============================================================
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ============================================================
    // Dump waves
    // ============================================================
    initial begin
        $dumpfile("tb_calendar_core.vcd");
        $dumpvars(0, tb_calendar_core);
    end

    // ============================================================
    // Scoreboard helper functions
    // ============================================================
    function automatic bit sb_is_leap(input [15:0] y);
        begin
            sb_is_leap = (((y % 4) == 0) && ((y % 100) != 0)) || ((y % 400) == 0);
        end
    endfunction

    function automatic [5:0] sb_max_day(
        input [3:0]  m,
        input [15:0] y
    );
        begin
            case (m)
                4'd1, 4'd3, 4'd5, 4'd7, 4'd8, 4'd10, 4'd12: sb_max_day = 6'd31;
                4'd4, 4'd6, 4'd9, 4'd11:                    sb_max_day = 6'd30;
                4'd2:                                       sb_max_day = sb_is_leap(y) ? 6'd29 : 6'd28;
                default:                                    sb_max_day = 6'd31;
            endcase
        end
    endfunction

    // ============================================================
    // Scoreboard tasks
    // ============================================================
    task sb_reset_expected;
    begin
        // Match your RTL reset values
        exp_day   = 6'd1;
        exp_month = 4'd1;
        exp_year  = 16'd2026;
    end
    endtask

    task sb_advance_one_day;
        reg [5:0] md;
    begin
        md = sb_max_day(exp_month, exp_year);

        if (exp_day == md) begin
            exp_day = 6'd1;
            if (exp_month == 4'd12) begin
                exp_month = 4'd1;
                exp_year  = exp_year + 16'd1;
            end
            else begin
                exp_month = exp_month + 4'd1;
            end
        end
        else begin
            exp_day = exp_day + 6'd1;
        end
    end
    endtask

    task check_date(input [255:0] tag);
    begin
        test_count = test_count + 1;

        if ((day !== exp_day) || (month !== exp_month) || (year !== exp_year)) begin
            error_count = error_count + 1;
            $display("FAIL %-24s DUT=%0d/%0d/%0d EXP=%0d/%0d/%0d t=%0t",
                     tag, month, day, year, exp_month, exp_day, exp_year, $time);
            $finish;
        end
        else begin
            $display("PASS %-24s DUT=%0d/%0d/%0d",
                     tag, month, day, year);
        end
    end
    endtask

    // ============================================================
    // Drive helpers
    // ============================================================
task pulse_day_step;
begin
    day_enable = 1'b1;
    @(posedge clk);
    #1;
    day_enable = 1'b0;

    // Allow rollover chain to propagate:
    // day -> month -> year
    @(posedge clk);
    #1;
    @(posedge clk);
    #1;
end
endtask

    task seed_date(
        input [5:0]  seed_day,
        input [3:0]  seed_month,
        input [15:0] seed_year
    );
    begin
        seed_day_reg   = seed_day;
        seed_month_reg = seed_month;
        seed_year_reg  = seed_year;

        force u_day_counter.day     = seed_day_reg;
        force u_month_counter.month = seed_month_reg;
        force u_year_counter.year   = seed_year_reg;

        @(posedge clk);
        #1;

        release u_day_counter.day;
        release u_month_counter.month;
        release u_year_counter.year;

        exp_day   = seed_day;
        exp_month = seed_month;
        exp_year  = seed_year;

        check_date("Seeded state");
    end
    endtask

    task do_one_day_and_check(input [255:0] tag);
    begin
        sb_advance_one_day();
        pulse_day_step();
        check_date(tag);
    end
    endtask

    // ============================================================
    // Directed tests
    // ============================================================
    task test_feb28_to_mar1_nonleap;
    begin
        $display("\n[TEST] Non-leap Feb 28 -> Mar 1");
        seed_date(6'd28, 4'd2, 16'd2025);
        do_one_day_and_check("2025 Feb28->Mar1");
    end
    endtask

    task test_feb28_to_feb29_leap;
    begin
        $display("\n[TEST] Leap Feb 28 -> Feb 29");
        seed_date(6'd28, 4'd2, 16'd2024);
        do_one_day_and_check("2024 Feb28->Feb29");
    end
    endtask

    task test_feb29_to_mar1_leap;
    begin
        $display("\n[TEST] Leap Feb 29 -> Mar 1");
        seed_date(6'd29, 4'd2, 16'd2024);
        do_one_day_and_check("2024 Feb29->Mar1");
    end
    endtask

    task test_apr30_to_may1;
    begin
        $display("\n[TEST] Apr 30 -> May 1");
        seed_date(6'd30, 4'd4, 16'd2026);
        do_one_day_and_check("Apr30->May1");
    end
    endtask

    task test_dec31_to_jan1;
    begin
        $display("\n[TEST] Dec 31 -> Jan 1");
        seed_date(6'd31, 4'd12, 16'd2026);
        do_one_day_and_check("Dec31->Jan1");
    end
    endtask

    task test_reset_mid_month;
    begin
        $display("\n[TEST] Reset mid-month");
        seed_date(6'd17, 4'd7, 16'd2031);

        rst = 1'b1;
        @(posedge clk);
        #1;
        rst = 1'b0;
        #1;

        sb_reset_expected();
        check_date("Reset mid-month");
    end
    endtask

    task test_year_2000_leap_century;
    begin
        $display("\n[TEST] Year 2000 leap century");
        seed_date(6'd28, 4'd2, 16'd2000);
        do_one_day_and_check("2000 Feb28->Feb29");
    end
    endtask

    task test_year_1900_not_leap_century;
    begin
        $display("\n[TEST] Year 1900 not leap century");
        seed_date(6'd28, 4'd2, 16'd1900);
        do_one_day_and_check("1900 Feb28->Mar1");
    end
    endtask

    task test_multi_day_run;
        integer i;
    begin
        $display("\n[TEST] Long multi-day run");
        seed_date(6'd25, 4'd1, 16'd2024);
        for (i = 0; i < 50; i = i + 1) begin
            do_one_day_and_check("Long run step");
        end
    end
    endtask

    // ============================================================
    // Main stimulus
    // ============================================================
    initial begin
        test_count       = 0;
        error_count      = 0;

        rst              = 1'b1;
        day_enable       = 1'b0;
        day_btn_pulse    = 1'b0;
        month_btn_pulse  = 1'b0;
        btn_year_pulse   = 1'b0;

        seed_day_reg     = 6'd0;
        seed_month_reg   = 4'd0;
        seed_year_reg    = 16'd0;

        sb_reset_expected();

        repeat (3) @(posedge clk);
        #1;
        rst = 1'b0;
        #1;

        check_date("After reset");

        test_feb28_to_mar1_nonleap();
        test_feb28_to_feb29_leap();
        test_feb29_to_mar1_leap();
        test_apr30_to_may1();
        test_dec31_to_jan1();
        test_reset_mid_month();
        test_year_2000_leap_century();
        test_year_1900_not_leap_century();
        test_multi_day_run();

        $display("\n========================================");
        $display("Tests run : %0d", test_count);
        $display("Errors    : %0d", error_count);
        if (error_count == 0)
            $display("RESULT    : PASS");
        else
            $display("RESULT    : FAIL");
        $display("========================================\n");

        #20;
        $finish;
    end

endmodule