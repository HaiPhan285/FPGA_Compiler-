`timescale 1ns/1ps

module fsm_traffic #(
  parameter int GREEN_COUNT  = 50,
  parameter int YELLOW_COUNT = 10,
  parameter int RED_COUNT    = 40,
  parameter int WALK_COUNT   = 20
)(
  input  logic clk,
  input  logic rst,            // active-high synchronous reset
  input  logic ped_req_evt,    // 1-cycle event: debounced rising edge of button

  output logic car_g,
  output logic car_y,
  output logic car_r,
  output logic ped_walk,
  output logic ped_dont,

  output logic [1:0] state_out // 00=G, 01=Y, 10=R, 11=W (debug/verification)
);

  // -----------------------------
  // State encoding (Moore)
  // -----------------------------
  typedef enum logic [1:0] { S_G=2'b00, S_Y=2'b01, S_R=2'b10, S_W=2'b11 } state_t;
  state_t state, next_state;

  assign state_out = state;

  // -----------------------------
  // Shared phase timer (counts cycles spent in current state)
  // -----------------------------
  localparam int MAX_COUNT = (GREEN_COUNT > YELLOW_COUNT) ? GREEN_COUNT : YELLOW_COUNT;
  localparam int MAX_COUNT2 = (RED_COUNT > WALK_COUNT) ? RED_COUNT : WALK_COUNT;
  localparam int MAX_PHASE  = (MAX_COUNT > MAX_COUNT2) ? MAX_COUNT : MAX_COUNT2;

  localparam int CNT_W = (MAX_PHASE <= 1) ? 1 : $clog2(MAX_PHASE);

  logic [CNT_W-1:0] phase_cnt;

  // "done" flags are asserted in the last cycle of each state
  logic tG_done, tY_done, tR_done, tW_done;

  always_comb begin
    tG_done = (state == S_G) && (phase_cnt == GREEN_COUNT-1);
    tY_done = (state == S_Y) && (phase_cnt == YELLOW_COUNT-1);
    tR_done = (state == S_R) && (phase_cnt == RED_COUNT-1);
    tW_done = (state == S_W) && (phase_cnt == WALK_COUNT-1);
  end

  // Reset phase counter on state change; otherwise increment
  always_ff @(posedge clk) begin
    if (rst) begin
      phase_cnt <= '0;
    end else begin
      if (state != next_state) begin
        phase_cnt <= '0;
      end else begin
        phase_cnt <= phase_cnt + 1'b1;
      end
    end
  end

  // -----------------------------
  // Pedestrian request latch
  // -----------------------------
  logic req_latched;

  // Latch any request event; clear after WALK completes (when leaving WALK)
  always_ff @(posedge clk) begin
    if (rst) begin
      req_latched <= 1'b0;
    end else begin
      // set
      if (ped_req_evt) begin
        req_latched <= 1'b1;
      end
      // clear when WALK finishes (transition W -> G on tW_done)
      if (state == S_W && tW_done) begin
        req_latched <= 1'b0;
      end
    end
  end

  // -----------------------------
  // Next-state logic
  // -----------------------------
  always_comb begin
    next_state = state;

    unique case (state)
      S_G: begin
        if (tG_done) next_state = S_Y;
      end

      S_Y: begin
        if (tY_done) next_state = S_R;
      end

      S_R: begin
        if (tR_done) begin
          // Only decision point: at end of Red
          if (req_latched) next_state = S_W;
          else             next_state = S_G;
        end
      end

      S_W: begin
        if (tW_done) next_state = S_G;
      end

      default: begin
        // illegal-state recovery
        next_state = S_G;
      end
    endcase
  end

  // State register
  always_ff @(posedge clk) begin
    if (rst) state <= S_G;
    else     state <= next_state;
  end

  // -----------------------------
  // Moore outputs (depend only on state)
  // -----------------------------
  always_comb begin
    // defaults
    car_g     = 1'b0;
    car_y     = 1'b0;
    car_r     = 1'b0;
    ped_walk  = 1'b0;
    ped_dont  = 1'b1;

    unique case (state)
      S_G: begin
        car_g    = 1'b1;
        ped_dont = 1'b1;
      end
      S_Y: begin
        car_y    = 1'b1;
        ped_dont = 1'b1;
      end
      S_R: begin
        car_r    = 1'b1;
        ped_dont = 1'b1;
      end
      S_W: begin
        car_r    = 1'b1;  // safety: cars stopped during walk
        ped_walk = 1'b1;
        ped_dont = 1'b0;
      end
      default: begin
        // safe default (all red, dont walk)
        car_r    = 1'b1;
        ped_dont = 1'b1;
      end
    endcase
  end

endmodule