`timescale 1ns/1ps
`default_nettype none

module tb_top;

    // Use a small debounce for simulation speed
    localparam integer SIM_STABLE_COUNT = 50;

    reg  clk = 0;
    reg  rst = 1;
    reg  btn = 0;
    wire [7:0] led;

    // Internal wires
    wire btn_sync, btn_db, btn_pulse;

    // DUT chain
    sync_2ff u_sync (
        .clk(clk),
        .rst(rst),
        .async_in(btn),
        .sync_out(btn_sync)
    );

    debounce_counter #(.STABLE_COUNT(SIM_STABLE_COUNT)) u_db (
        .clk(clk),
        .rst(rst),
        .noisy_in(btn_sync),
        .debounced(btn_db)
    );

    edge_rise u_edge (
        .clk(clk),
        .rst(rst),
        .level_in(btn_db),
        .pulse_out(btn_pulse)
    );

    counter_ce #(.WIDTH(8)) u_cnt (
        .clk(clk),
        .rst(rst),
        .ce(btn_pulse),
        .q(led)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    integer expected = 0;

    task expect_count;
        begin
            if (led !== expected[7:0]) begin
                $display("FAIL @%0t ns expected=%0d actual=%0d btn=%b sync=%b db=%b pulse=%b",
                         $time, expected, led, btn, btn_sync, btn_db, btn_pulse);
                $fatal;
            end
        end
    endtask

    task press_with_bounce;
        input integer toggles;
        input integer gap_ns;
        integer i;
        begin
            // Bounce on press
            for (i = 0; i < toggles; i = i + 1) begin
                btn = ~btn;
                #(gap_ns);
            end
            btn = 1'b1;

            // Hold long enough to pass debounce
            repeat (SIM_STABLE_COUNT + 10) @(posedge clk);

            // Bounce on release
            for (i = 0; i < toggles; i = i + 1) begin
                btn = ~btn;
                #(gap_ns);
            end
            btn = 1'b0;

            // Let settle
            repeat (SIM_STABLE_COUNT + 10) @(posedge clk);
        end
    endtask

    initial begin
        // ===== ENABLE GTKWave dump =====
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_top);

        $display("TB start");

        // Reset sequence
        repeat (5) @(posedge clk);
        rst = 1;
        repeat (5) @(posedge clk);
        rst = 0;

        expected = 0;
        repeat (SIM_STABLE_COUNT + 10) @(posedge clk);
        expect_count();

        // Case 1: short bounce
        press_with_bounce(6, 20);
        expected = expected + 1;
        expect_count();

        // Case 2: longer bounce
        press_with_bounce(10, 10);
        expected = expected + 1;
        expect_count();

        // Case 3: pathological burst
        press_with_bounce(40, 5);
        expected = expected + 1;
        expect_count();

        // Randomized bounce bursts
        repeat (5) begin
            press_with_bounce(5 + ($urandom % 30), 5 + ($urandom % 40));
            expected = expected + 1;
            expect_count();
        end

        $display("PASS: all tests. final=%0d", led);
        $finish;
    end

endmodule

`default_nettype wire