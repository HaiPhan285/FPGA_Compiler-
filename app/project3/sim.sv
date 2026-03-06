`timescale 1ns/1ps

// ============================================================
// 2-FF Synchronizer
// ============================================================
module sync_2ff (
    input  logic clk,
    input  logic rst_n,
    input  logic async_in,
    output logic sync_out
);

    logic ff1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ff1      <= 1'b0;
            sync_out <= 1'b0;
        end else begin
            ff1      <= async_in;
            sync_out <= ff1;
        end
    end

endmodule


// ============================================================
// Debouncer A: Stable-for-N Counter
// ============================================================
module debounce_stable_counter #(
    parameter int unsigned STABLE_CYCLES = 1_000_000   // ~10ms @ 100MHz
) (
    input  logic clk,
    input  logic rst_n,
    input  logic din_sync,
    output logic dout_clean
);

    logic din_q;
    int unsigned cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            din_q      <= 1'b0;
            dout_clean <= 1'b0;
            cnt        <= 0;
        end else begin
            if (din_sync == din_q) begin
                if (cnt < STABLE_CYCLES)
                    cnt <= cnt + 1;

                if (cnt == STABLE_CYCLES - 1)
                    dout_clean <= din_q;
            end else begin
                din_q <= din_sync;
                cnt   <= 0;
            end
        end
    end

endmodule


// ============================================================
// Debouncer B: Integrator (Up/Down)
// ============================================================
module debounce_integrator #(
    parameter int unsigned WIDTH = 20
) (
    input  logic clk,
    input  logic rst_n,
    input  logic din_sync,
    output logic dout_clean
);

    localparam int unsigned MAX = (1 << WIDTH) - 1;
    logic [WIDTH-1:0] acc;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc        <= '0;
            dout_clean <= 1'b0;
        end else begin
            if (din_sync) begin
                if (acc != MAX[WIDTH-1:0])
                    acc <= acc + 1'b1;
            end else begin
                if (acc != '0)
                    acc <= acc - 1'b1;
            end

            if (acc == MAX[WIDTH-1:0])
                dout_clean <= 1'b1;
            else if (acc == '0)
                dout_clean <= 1'b0;
        end
    end

endmodule


// ============================================================
// TESTBENCH: Compare Debouncers with Realistic Bounce
// ============================================================
module tb_compare_debouncers;

    // -----------------------
    // Clock / Reset
    // -----------------------
    localparam time CLK_PERIOD = 10ns; // 100 MHz
    logic clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    logic rst_n;

    // -----------------------
    // Signals
    // -----------------------
    logic btn_raw;
    logic btn_sync;
    logic clean_A;
    logic clean_B;

    localparam int unsigned STABLE_CYCLES = 1_000_000;
    localparam int unsigned INT_WIDTH     = 20;

    // -----------------------
    // Instantiate Modules
    // -----------------------
    sync_2ff u_sync (
        .clk      (clk),
        .rst_n    (rst_n),
        .async_in (btn_raw),
        .sync_out (btn_sync)
    );

    debounce_stable_counter #(.STABLE_CYCLES(STABLE_CYCLES)) u_A (
        .clk       (clk),
        .rst_n     (rst_n),
        .din_sync  (btn_sync),
        .dout_clean(clean_A)
    );

    debounce_integrator #(.WIDTH(INT_WIDTH)) u_B (
        .clk       (clk),
        .rst_n     (rst_n),
        .din_sync  (btn_sync),
        .dout_clean(clean_B)
    );

    // -----------------------
    // Bounce Generator
    // -----------------------
    task automatic bounce_to_target(
        input logic target_level,
        input int unsigned ms_min,
        input int unsigned ms_max
    );
        int unsigned total_ms;
        time end_t;
        time step_t;
        begin
            total_ms = $urandom_range(ms_min, ms_max);
            end_t    = $time + total_ms * 1ms;

            while ($time < end_t) begin
                btn_raw = ~btn_raw;
                step_t  = $urandom_range(100, 2000) * 1us; // 100us–2ms
                #(step_t);
            end

            btn_raw = target_level;
        end
    endtask

    task automatic press_with_bounce;
        bounce_to_target(1'b1, 5, 20);
    endtask

    task automatic release_with_bounce;
        bounce_to_target(1'b0, 5, 20);
    endtask

    // -----------------------
    // Edge Counting
    // -----------------------
    int press_count;
    int rises_A, rises_B;

    logic A_d, B_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            A_d     <= 0;
            B_d     <= 0;
            rises_A <= 0;
            rises_B <= 0;
        end else begin
            A_d <= clean_A;
            B_d <= clean_B;

            if (!A_d && clean_A) rises_A++;
            if (!B_d && clean_B) rises_B++;
        end
    end

    // -----------------------
    // Simulation
    // -----------------------
    initial begin
        // Waveform dump
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_compare_debouncers);

        btn_raw = 0;
        rst_n   = 0;

        #(200ns);
        rst_n = 1;

        #(1ms);

        press_count = 0;

        repeat (5) begin
            press_count++;

            $display("\n=== Press %0d ===", press_count);
            press_with_bounce();
            #(30ms);

            $display("After press: A=%0b B=%0b", clean_A, clean_B);

            $display("=== Release %0d ===", press_count);
            release_with_bounce();
            #(30ms);
        end

        $display("\nSummary:");
        $display("Presses: %0d", press_count);
        $display("Rises A: %0d", rises_A);
        $display("Rises B: %0d", rises_B);

        if (rises_A != press_count)
            $error("Stable-for-N incorrect!");
        if (rises_B != press_count)
            $error("Integrator incorrect!");

        $display("Simulation finished.");
        $finish;
    end

endmodule