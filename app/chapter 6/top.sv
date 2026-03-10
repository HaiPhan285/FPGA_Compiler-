// =============================================================================
// top_nexys_a7.sv  —  Board Top-Level Wrapper
// CECS-301  Lab 6  |  Nexys A7-100T
//
// I/O mapping
// ───────────────────────────────────────────────────────────────────────────
//  CLK100MHZ  (E3)   100 MHz oscillator
//  CPU_RESETN (C12)  Active-LOW push-to-reset  →  inverted to active-HIGH rst
//  BTNC       (N17)  Pedestrian request (center button)
//
//  RGB LED LD16  —  Car traffic light (color mixed)
//    ST_RED    : R=1 G=0  →  RED
//    ST_YELLOW : R=1 G=1  →  YELLOW  (R+G mixed)
//    ST_GREEN  : R=0 G=1  →  GREEN
//
//  RGB LED LD17  —  Pedestrian signal
//    PED_DONT  : R=1 G=0  →  RED   (don't walk)
//    PED_WALK  : R=0 G=1  →  GREEN (walk)
//
//  Discrete LEDs — individual signal indicators for checkoff
//    LED[0] H17  = CAR_G
//    LED[1] K15  = CAR_Y
//    LED[2] J13  = CAR_R
//    LED[3] N14  = PED_WALK
//    LED[4] R18  = PED_DONT
//
// Hardware timing  (100 MHz clock):
//   GREEN  = 500 000 000 cycles = 5 s
//   YELLOW = 200 000 000 cycles = 2 s
//   RED    = 300 000 000 cycles = 3 s
//   WALK   = 400 000 000 cycles = 4 s
//   DEBOUNCE = 1 000 000 cycles = 10 ms
// =============================================================================
module top_nexys_a7 (
    input  logic CLK100MHZ,
    input  logic CPU_RESETN,   // active-LOW
    input  logic BTNC,         // pedestrian request

    // LD16 — car traffic light (RGB color mixing)
    output logic LED16_R,
    output logic LED16_G,
    output logic LED16_B,

    // LD17 — pedestrian signal (RGB color mixing)
    output logic LED17_R,
    output logic LED17_G,
    output logic LED17_B,

    // Discrete LEDs — one per signal for clear checkoff visibility
    output logic [4:0] LED   // [0]=CAR_G [1]=CAR_Y [2]=CAR_R [3]=PED_WALK [4]=PED_DONT
);

    // -------------------------------------------------------------------------
    // Internal wires
    // -------------------------------------------------------------------------
    logic rst;
    logic btn_clean_unused, btn_pulse;
    logic car_g, car_y, car_r;
    logic ped_walk, ped_dont;
    logic [2:0] state_out;

    // -------------------------------------------------------------------------
    // Active-HIGH reset from active-LOW board button
    // -------------------------------------------------------------------------
    assign rst = ~CPU_RESETN;

    // -------------------------------------------------------------------------
    // Synchronizer + debounce
    // -------------------------------------------------------------------------
    sync_debounce #(
        .DEBOUNCE_COUNT(1_000_000)   // 10 ms @ 100 MHz
    ) u_deb (
        .clk      (CLK100MHZ),
        .rst      (rst),
        .btn_raw  (BTNC),
        .btn_clean(btn_clean_unused),
        .btn_pulse(btn_pulse)
    );

    // -------------------------------------------------------------------------
    // Traffic-light FSM
    // -------------------------------------------------------------------------
    fsm_traffic #(
        .GREEN_COUNT (500_000_000),
        .YELLOW_COUNT(200_000_000),
        .RED_COUNT   (300_000_000),
        .WALK_COUNT  (400_000_000)
    ) u_fsm (
        .clk          (CLK100MHZ),
        .rst          (rst),
        .ped_btn_pulse(btn_pulse),
        .car_g        (car_g),
        .car_y        (car_y),
        .car_r        (car_r),
        .ped_walk     (ped_walk),
        .ped_dont     (ped_dont),
        .state_out    (state_out)
    );

    // -------------------------------------------------------------------------
    // LD16 — car traffic light color mixing
    //   RED    : R=1 G=0  →  red
    //   YELLOW : R=1 G=1  →  yellow (R+G mixed)
    //   GREEN  : R=0 G=1  →  green
    // -------------------------------------------------------------------------
    assign LED16_R = car_r | car_y;
    assign LED16_G = car_g | car_y;
    assign LED16_B = 1'b0;

    // -------------------------------------------------------------------------
    // LD17 — pedestrian signal
    //   DON'T WALK : R=1 G=0  →  red
    //   WALK       : R=0 G=1  →  green
    // -------------------------------------------------------------------------
    assign LED17_R = ped_dont;
    assign LED17_G = ped_walk;
    assign LED17_B = 1'b0;

    // -------------------------------------------------------------------------
    // Discrete LEDs — individual signal per LED for demo/checkoff
    // -------------------------------------------------------------------------
    assign LED[0] = car_g;
    assign LED[1] = car_y;
    assign LED[2] = car_r;
    assign LED[3] = ped_walk;
    assign LED[4] = ped_dont;

endmodule