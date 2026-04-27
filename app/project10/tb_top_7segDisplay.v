`timescale 1ns/1ps

module tb_top_7segDisplay_edgecases;

    reg         CLK100MHZ;
    reg         CPU_RESETN;
    reg  [2:0]  SW;
    reg         BTNC;
    reg         BTNL;
    reg         BTNR;
    reg         BTNU;
    reg         BTND;

    wire        CA;
    wire        CB;
    wire        CC;
    wire        CD;
    wire        CE;
    wire        CF;
    wire        CG;
    wire        DP;
    wire [7:0]  AN;

    top dut (
        .CLK100MHZ  (CLK100MHZ),
        .CPU_RESETN (CPU_RESETN),
        .SW         (SW),
        .BTNC       (BTNC),
        .BTNL       (BTNL),
        .BTNR       (BTNR),
        .BTNU       (BTNU),
        .BTND       (BTND),
        .CA         (CA),
        .CB         (CB),
        .CC         (CC),
        .CD         (CD),
        .CE         (CE),
        .CF         (CF),
        .CG         (CG),
        .DP         (DP),
        .AN         (AN)
    );

    initial CLK100MHZ = 1'b0;
    always #5 CLK100MHZ = ~CLK100MHZ;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top_7segDisplay_edgecases);
    end

    task check_extracted_digits;
        input [3:0] exp_hour_tens;
        input [3:0] exp_hour_ones;
        input [3:0] exp_min_tens;
        input [3:0] exp_min_ones;
        input [3:0] exp_sec_tens;
        input [3:0] exp_sec_ones;
        input [3:0] exp_month_tens;
        input [3:0] exp_month_ones;
        input [3:0] exp_day_tens;
        input [3:0] exp_day_ones;
        input [3:0] exp_year_thousands;
        input [3:0] exp_year_hundreds;
        input [3:0] exp_year_tens;
        input [3:0] exp_year_ones;
        begin
            if (dut.hour_tens !== exp_hour_tens || dut.hour_ones !== exp_hour_ones) begin
                $display("FAIL: Hour digits wrong. Got %0d%0d expected %0d%0d at time %0t",
                         dut.hour_tens, dut.hour_ones, exp_hour_tens, exp_hour_ones, $time);
                $finish;
            end

            if (dut.min_tens !== exp_min_tens || dut.min_ones !== exp_min_ones) begin
                $display("FAIL: Minute digits wrong. Got %0d%0d expected %0d%0d at time %0t",
                         dut.min_tens, dut.min_ones, exp_min_tens, exp_min_ones, $time);
                $finish;
            end

            if (dut.sec_tens !== exp_sec_tens || dut.sec_ones !== exp_sec_ones) begin
                $display("FAIL: Second digits wrong. Got %0d%0d expected %0d%0d at time %0t",
                         dut.sec_tens, dut.sec_ones, exp_sec_tens, exp_sec_ones, $time);
                $finish;
            end

            if (dut.month_tens !== exp_month_tens || dut.month_ones !== exp_month_ones) begin
                $display("FAIL: Month digits wrong. Got %0d%0d expected %0d%0d at time %0t",
                         dut.month_tens, dut.month_ones, exp_month_tens, exp_month_ones, $time);
                $finish;
            end

            if (dut.day_tens !== exp_day_tens || dut.day_ones !== exp_day_ones) begin
                $display("FAIL: Day digits wrong. Got %0d%0d expected %0d%0d at time %0t",
                         dut.day_tens, dut.day_ones, exp_day_tens, exp_day_ones, $time);
                $finish;
            end

            if (dut.year_thousands !== exp_year_thousands ||
                dut.year_hundreds  !== exp_year_hundreds  ||
                dut.year_tens      !== exp_year_tens      ||
                dut.year_ones      !== exp_year_ones) begin
                $display("FAIL: Year digits wrong. Got %0d%0d%0d%0d expected %0d%0d%0d%0d at time %0t",
                         dut.year_thousands, dut.year_hundreds, dut.year_tens, dut.year_ones,
                         exp_year_thousands, exp_year_hundreds, exp_year_tens, exp_year_ones, $time);
                $finish;
            end
        end
    endtask

    task check_mode_blank_and_mapping;
        input [1:0] mode;
        input [3:0] exp_d7;
        input [3:0] exp_d6;
        input [3:0] exp_d5;
        input [3:0] exp_d4;
        input [3:0] exp_d3;
        input [3:0] exp_d2;
        input [3:0] exp_d1;
        input [3:0] exp_d0;
        begin
            SW[1:0] = mode;
            #2;

            if (dut.d7 !== exp_d7 || dut.d6 !== exp_d6 || dut.d5 !== exp_d5 || dut.d4 !== exp_d4 ||
                dut.d3 !== exp_d3 || dut.d2 !== exp_d2 || dut.d1 !== exp_d1 || dut.d0 !== exp_d0) begin
                $display("FAIL: Mode=%b mux digits wrong at time %0t", mode, $time);
                $display("      Got      d7..d0 = %h %h %h %h %h %h %h %h",
                         dut.d7, dut.d6, dut.d5, dut.d4, dut.d3, dut.d2, dut.d1, dut.d0);
                $display("      Expected d7..d0 = %h %h %h %h %h %h %h %h",
                         exp_d7, exp_d6, exp_d5, exp_d4, exp_d3, exp_d2, exp_d1, exp_d0);
                $finish;
            end
        end
    endtask

    initial begin
        BTNC       = 1'b0;
        BTNL       = 1'b0;
        BTNR       = 1'b0;
        BTNU       = 1'b0;
        BTND       = 1'b0;
        SW         = 3'b000;
        CPU_RESETN = 1'b0;

        $display("INFO: Starting RTC digit-extraction edge-case testbench...");

        repeat (5) @(posedge CLK100MHZ);
        CPU_RESETN = 1'b1;
        repeat (2) @(posedge CLK100MHZ);

        // -------------------------------------------------------------
        // Edge Case 1: hours=0, month=12, day=1, year=2000
        // -------------------------------------------------------------
        force dut.hours   = 5'd0;
        force dut.minutes = 6'd0;
        force dut.seconds = 6'd0;
        force dut.month   = 4'd12;
        force dut.day     = 6'd1;
        force dut.year    = 16'd2000;
        #2;

        check_extracted_digits(
            4'd0, 4'd0,
            4'd0, 4'd0,
            4'd0, 4'd0,
            4'd1, 4'd2,
            4'd0, 4'd1,
            4'd2, 4'd0, 4'd0, 4'd0
        );

        check_mode_blank_and_mapping(
            2'b00,
            4'hF, 4'hF, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0
        );

        check_mode_blank_and_mapping(
            2'b01,
            4'hF, 4'hF, 4'hF, 4'hF, 4'd1, 4'd2, 4'd0, 4'd1
        );

        check_mode_blank_and_mapping(
            2'b10,
            4'hF, 4'hF, 4'hF, 4'hF, 4'd2, 4'd0, 4'd0, 4'd0
        );

        $display("PASS: Edge case 1 correct (hours=0, month=12, day=1, year=2000).");

        // -------------------------------------------------------------
        // Edge Case 2: hours=9, month=1, day=9, year=2001
        // -------------------------------------------------------------
        force dut.hours   = 5'd9;
        force dut.minutes = 6'd9;
        force dut.seconds = 6'd9;
        force dut.month   = 4'd1;
        force dut.day     = 6'd9;
        force dut.year    = 16'd2001;
        #2;

        check_extracted_digits(
            4'd0, 4'd9,
            4'd0, 4'd9,
            4'd0, 4'd9,
            4'd0, 4'd1,
            4'd0, 4'd9,
            4'd2, 4'd0, 4'd0, 4'd1
        );

        check_mode_blank_and_mapping(
            2'b00,
            4'hF, 4'hF, 4'd0, 4'd9, 4'd0, 4'd9, 4'd0, 4'd9
        );

        check_mode_blank_and_mapping(
            2'b01,
            4'hF, 4'hF, 4'hF, 4'hF, 4'd0, 4'd1, 4'd0, 4'd9
        );

        check_mode_blank_and_mapping(
            2'b10,
            4'hF, 4'hF, 4'hF, 4'hF, 4'd2, 4'd0, 4'd0, 4'd1
        );

        $display("PASS: Edge case 2 correct (hours=9, month=1, day=9, year=2001).");

        // -------------------------------------------------------------
        // Edge Case 3: hours=10, month=10, day=10, year=2026
        // -------------------------------------------------------------
        force dut.hours   = 5'd10;
        force dut.minutes = 6'd10;
        force dut.seconds = 6'd10;
        force dut.month   = 4'd10;
        force dut.day     = 6'd10;
        force dut.year    = 16'd2026;
        #2;

        check_extracted_digits(
            4'd1, 4'd0,
            4'd1, 4'd0,
            4'd1, 4'd0,
            4'd1, 4'd0,
            4'd1, 4'd0,
            4'd2, 4'd0, 4'd2, 4'd6
        );

        check_mode_blank_and_mapping(
            2'b00,
            4'hF, 4'hF, 4'd1, 4'd0, 4'd1, 4'd0, 4'd1, 4'd0
        );

        check_mode_blank_and_mapping(
            2'b01,
            4'hF, 4'hF, 4'hF, 4'hF, 4'd1, 4'd0, 4'd1, 4'd0
        );

        check_mode_blank_and_mapping(
            2'b10,
            4'hF, 4'hF, 4'hF, 4'hF, 4'd2, 4'd0, 4'd2, 4'd6
        );

        $display("PASS: Edge case 3 correct (hours=10, month=10, day=10, year=2026).");

        // -------------------------------------------------------------
        // Edge Case 4: hours=23, month=12, day=31, year=2099
        // -------------------------------------------------------------
        force dut.hours   = 5'd23;
        force dut.minutes = 6'd59;
        force dut.seconds = 6'd59;
        force dut.month   = 4'd12;
        force dut.day     = 6'd31;
        force dut.year    = 16'd2099;
        #2;

        check_extracted_digits(
            4'd2, 4'd3,
            4'd5, 4'd9,
            4'd5, 4'd9,
            4'd1, 4'd2,
            4'd3, 4'd1,
            4'd2, 4'd0, 4'd9, 4'd9
        );

        check_mode_blank_and_mapping(
            2'b00,
            4'hF, 4'hF, 4'd2, 4'd3, 4'd5, 4'd9, 4'd5, 4'd9
        );

        check_mode_blank_and_mapping(
            2'b01,
            4'hF, 4'hF, 4'hF, 4'hF, 4'd1, 4'd2, 4'd3, 4'd1
        );

        check_mode_blank_and_mapping(
            2'b10,
            4'hF, 4'hF, 4'hF, 4'hF, 4'd2, 4'd0, 4'd9, 4'd9
        );

        $display("PASS: Edge case 4 correct (hours=23, month=12, day=31, year=2099).");

        // -------------------------------------------------------------
        // Edge Case 5: year=9999 stress case
        // -------------------------------------------------------------
        force dut.hours   = 5'd23;
        force dut.minutes = 6'd59;
        force dut.seconds = 6'd59;
        force dut.month   = 4'd12;
        force dut.day     = 6'd31;
        force dut.year    = 16'd9999;
        #2;

        check_extracted_digits(
            4'd2, 4'd3,
            4'd5, 4'd9,
            4'd5, 4'd9,
            4'd1, 4'd2,
            4'd3, 4'd1,
            4'd9, 4'd9, 4'd9, 4'd9
        );

        check_mode_blank_and_mapping(
            2'b10,
            4'hF, 4'hF, 4'hF, 4'hF, 4'd9, 4'd9, 4'd9, 4'd9
        );

        $display("PASS: Edge case 5 correct (year=9999).");

        release dut.hours;
        release dut.minutes;
        release dut.seconds;
        release dut.month;
        release dut.day;
        release dut.year;
        #1;

        $display("PASS: All RTC digit-extraction edge-case tests passed.");
        $finish;
    end

endmodule