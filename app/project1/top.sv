`timescale 1ns / 1ps

// top.sv — board integration for `main`
//
// Default mapping (common, convenient):
//   sw[7:0]    -> A[7:0]
//   sw[15:8]   -> B[7:0]
//   btn0       -> sub          (0 add, 1 subtract)
//   btn1       -> signed_mode  (0 unsigned, 1 signed overflow)
//
// LED mapping:
//   led[7:0]   -> Y[7:0]
//   led[8]     -> carry_no_borrow
//   led[9]     -> overflow
//   led[10]    -> zero
//   led[11]    -> negative
//   led[15:12] -> 0
//
// Notes:
// - If your board buttons are active-low (very common), use btn_n and invert.
// - If you have fewer LEDs, you can pack flags into upper bits you do have.

module top #(
    parameter int W     = 8,
    parameter int N_SW  = 16,
    parameter int N_BTN = 4,
    parameter int N_LED = 16
)(
    input  logic                  clk,    // not used by `main`, but boards usually provide it
    input  logic                  rst_n,  // not used by `main`, kept for consistency

    input  logic [N_SW-1:0]       sw,
    input  logic [N_BTN-1:0]      btn,    // assume ACTIVE-HIGH; if active-low, see below

    output logic [N_LED-1:0]      led
);

    // -----------------------------
    // Inputs from board
    // -----------------------------
    logic [W-1:0] A, B;
    logic         sub;
    logic         signed_mode;

    // Safe slicing even if N_SW differs; any missing bits become 0
    always_comb begin
        A = '0;
        B = '0;

        // A from sw[W-1:0]
        for (int i = 0; i < W && i < N_SW; i++) begin
            A[i] = sw[i];
        end

        // B from sw[2W-1:W]
        for (int i = 0; i < W && (i+W) < N_SW; i++) begin
            B[i] = sw[i+W];
        end

        sub         = (N_BTN > 0) ? btn[0] : 1'b0;
        signed_mode = (N_BTN > 1) ? btn[1] : 1'b0;
    end

    // If your board buttons are ACTIVE-LOW, replace the two lines above with:
    //   sub         = (N_BTN > 0) ? ~btn_n[0] : 1'b0;
    //   signed_mode = (N_BTN > 1) ? ~btn_n[1] : 1'b0;

    // -----------------------------
    // DUT instance: your `main`
    // -----------------------------
    logic [W-1:0] Y;
    logic         carry_no_borrow, overflow, zero, negative;

    main #(.W(W)) u_main (
        .A(A),
        .B(B),
        .sub(sub),
        .signed_mode(signed_mode),
        .Y(Y),
        .carry_no_borrow(carry_no_borrow),
        .overflow(overflow),
        .zero(zero),
        .negative(negative)
    );

    // -----------------------------
    // Outputs to board LEDs
    // -----------------------------
    always_comb begin
        led = '0;

        // led[W-1:0] = Y
        for (int i = 0; i < W && i < N_LED; i++) begin
            led[i] = Y[i];
        end

        if (N_LED > 8)  led[8]  = carry_no_borrow;
        if (N_LED > 9)  led[9]  = overflow;
        if (N_LED > 10) led[10] = zero;
        if (N_LED > 11) led[11] = negative;
    end

endmodule   