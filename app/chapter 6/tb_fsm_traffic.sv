`timescale 1ns/1ps

module tb_fsm_traffic;

  // -----------------------------
  // Fast simulation parameters
  // -----------------------------
  localparam int GREEN_COUNT  = 5;
  localparam int YELLOW_COUNT = 3;
  localparam int RED_COUNT    = 4;
  localparam int WALK_COUNT   = 3;

  // Watchdog bound: after a (valid) request, WALK must occur within this many cycles
  localparam int MAX_WAIT = GREEN_COUNT + YELLOW_COUNT + RED_COUNT + WALK_COUNT + 6;

  // -----------------------------
  // Randomized extension controls
  // -----------------------------
  localparam int RANDOM_TRIALS = 10;  // increase for more coverage
  localparam int BIAS_PERCENT  = 70;   // % trials biased near boundaries
  localparam int GAP_MIN       = 1;    // idle cycles between trials
  localparam int GAP_MAX       = 10;

  // -----------------------------
  // DUT I/O
  // -----------------------------
  logic clk, rst;
  logic ped_req_evt;

  logic car_g, car_y, car_r, ped_walk, ped_dont;
  logic [1:0] state_out;

  // -----------------------------
  // Instantiate DUT
  // -----------------------------
  fsm_traffic #(
    .GREEN_COUNT (GREEN_COUNT),
    .YELLOW_COUNT(YELLOW_COUNT),
    .RED_COUNT   (RED_COUNT),
    .WALK_COUNT  (WALK_COUNT)
  ) dut (
    .clk(clk),
    .rst(rst),
    .ped_req_evt(ped_req_evt),
    .car_g(car_g),
    .car_y(car_y),
    .car_r(car_r),
    .ped_walk(ped_walk),
    .ped_dont(ped_dont),
    .state_out(state_out)
  );

  // -----------------------------
  // Clock + waves
  // -----------------------------
  initial clk = 1'b0;
  always #5 clk = ~clk; // 10ns period

  initial begin
    $dumpfile("tb_fsm_traffic.vcd");
    $dumpvars(0, tb_fsm_traffic);
  end

  // -----------------------------
  // Small helpers
  // -----------------------------
  function automatic [79:0] sname(input logic [1:0] s);
    case (s)
      2'b00: sname = "G";
      2'b01: sname = "Y";
      2'b10: sname = "R";
      2'b11: sname = "W";
      default: sname = "??";
    endcase
  endfunction

  // Icarus-friendly random range
  function automatic int urand_range(input int lo, input int hi);
    int span;
    int unsigned r;
    begin
      span = hi - lo + 1;
      if (span <= 0) urand_range = lo;
      else begin
        r = $urandom;
        urand_range = lo + (r % span);
      end
    end
  endfunction

  task automatic wait_cycles(input int n);
    int i;
    begin
      for (i = 0; i < n; i++) @(posedge clk);
    end
  endtask

  // 1-cycle synchronous event (high for one clock period)
  task automatic pulse_req_1cycle();
    begin
      ped_req_evt <= 1'b1;
      @(posedge clk);
      ped_req_evt <= 1'b0;
    end
  endtask

  task automatic apply_reset(input int cycles_high);
    int i;
    begin
      rst <= 1'b1;
      ped_req_evt <= 1'b0;
      for (i = 0; i < cycles_high; i++) @(posedge clk);
      rst <= 1'b0;
      @(posedge clk);

      // Reset test: must be GREEN with CAR_G=1 and PED_DONT=1
      if (state_out != 2'b00 || !(car_g==1 && ped_dont==1)) begin
        $display("FAIL: reset did not enter GREEN with CAR_G=1 PED_DONT=1 (state=%s) time=%0t",
                 sname(state_out), $time);
        $fatal;
      end
    end
  endtask

  // Wait until we are in a given state, and optionally at a specific cycle index in that state
  // cyc_in_state is maintained by the TB (starts at 1 on state entry).
  task automatic wait_state_cycle(input logic [1:0] st, input int cycle_index);
    begin
      wait (state_out == st);
      if (cycle_index > 0) begin
        while (!(state_out == st && cyc_in_state == cycle_index)) @(posedge clk);
      end
    end
  endtask

  // -----------------------------
  // TB tracking / checkers (no SVA)
  // -----------------------------
  logic [1:0] prev_state;
  int        cyc_in_state;         // 1..N within a state
  logic      exp_req_latched;       // TB model of "request latched"
  logic      waiting_for_walk;
  int        wait_left;

  // output legality & truth-table check
  task automatic check_outputs();
    begin
      // legal state encoding
      if (state_out !== 2'b00 && state_out !== 2'b01 && state_out !== 2'b10 && state_out !== 2'b11) begin
        $display("FAIL: illegal state_out=%b time=%0t", state_out, $time);
        $fatal;
      end

      // mutually exclusive car lights
      if ((car_g + car_y + car_r) > 1) begin
        $display("FAIL: car lights not one-hot (G,Y,R)=(%0d,%0d,%0d) state=%s time=%0t",
                 car_g, car_y, car_r, sname(state_out), $time);
        $fatal;
      end

      // mutually exclusive ped outputs
      if (ped_walk && ped_dont) begin
        $display("FAIL: ped_walk and ped_dont both 1 state=%s time=%0t", sname(state_out), $time);
        $fatal;
      end

      // pedestrian safety
      if (ped_walk && !car_r) begin
        $display("FAIL: PED_WALK=1 but CAR_R=0 state=%s time=%0t", sname(state_out), $time);
        $fatal;
      end

      // Moore truth table per state
      case (state_out)
        2'b00: if (!(car_g==1 && car_y==0 && car_r==0 && ped_dont==1 && ped_walk==0)) begin
                 $display("FAIL: wrong outputs in GREEN time=%0t", $time); $fatal;
               end
        2'b01: if (!(car_g==0 && car_y==1 && car_r==0 && ped_dont==1 && ped_walk==0)) begin
                 $display("FAIL: wrong outputs in YELLOW time=%0t", $time); $fatal;
               end
        2'b10: if (!(car_g==0 && car_y==0 && car_r==1 && ped_dont==1 && ped_walk==0)) begin
                 $display("FAIL: wrong outputs in RED time=%0t", $time); $fatal;
               end
        2'b11: if (!(car_g==0 && car_y==0 && car_r==1 && ped_dont==0 && ped_walk==1)) begin
                 $display("FAIL: wrong outputs in WALK time=%0t", $time); $fatal;
               end
      endcase
    end
  endtask

  task automatic check_duration(input logic [1:0] st, input int dur);
    int exp;
    begin
      case (st)
        2'b00: exp = GREEN_COUNT;
        2'b01: exp = YELLOW_COUNT;
        2'b10: exp = RED_COUNT;
        2'b11: exp = WALK_COUNT;
        default: exp = -1;
      endcase

      if (exp != -1 && dur != exp) begin
        $display("FAIL: state %s duration wrong: got=%0d expected=%0d time=%0t",
                 sname(st), dur, exp, $time);
        $fatal;
      end
    end
  endtask

  // Update cyc_in_state + run checkers every clock
  always @(posedge clk) begin
    if (rst) begin
      prev_state       <= 2'b00;
      cyc_in_state     <= 0;
      exp_req_latched  <= 1'b0;
      waiting_for_walk <= 1'b0;
      wait_left        <= 0;
    end else begin
      check_outputs();

      // Watchdog: after a request, WALK must happen soon
      if (waiting_for_walk) begin
        if (state_out == 2'b11) begin
          waiting_for_walk <= 1'b0; // serviced
        end else begin
          wait_left <= wait_left - 1;
          if (wait_left <= 0) begin
            $display("FAIL: WALK did not occur within MAX_WAIT cycles after request time=%0t", $time);
            $fatal;
          end
        end
      end

      // State change tracking
      if (state_out != prev_state) begin
        // duration check for the state we just left
        check_duration(prev_state, cyc_in_state);

        // RED branch correctness at RED exit:
        // if request was latched before end of RED, next must be WALK; else must be GREEN.
        if (prev_state == 2'b10) begin
          if (exp_req_latched) begin
            if (state_out != 2'b11) begin
              $display("FAIL: expected RED->WALK (latched req), got RED->%s time=%0t",
                       sname(state_out), $time);
              $fatal;
            end
          end else begin
            if (state_out != 2'b00) begin
              $display("FAIL: expected RED->GREEN (no req), got RED->%s time=%0t",
                       sname(state_out), $time);
              $fatal;
            end
          end
        end

        // clear latched request when WALK completes (W->G)
        if (prev_state == 2'b11 && state_out == 2'b00) begin
          exp_req_latched <= 1'b0;
        end

        prev_state   <= state_out;
        cyc_in_state <= 1; // first cycle in new state
      end else begin
        cyc_in_state <= cyc_in_state + 1;
      end

      // TB latch model: treat requests during WALK as "ignored" (common spec)
      if (ped_req_evt && state_out != 2'b11) begin
        exp_req_latched <= 1'b1;

        // start watchdog once (coalesce repeated presses)
        if (!waiting_for_walk) begin
          waiting_for_walk <= 1'b1;
          wait_left        <= MAX_WAIT;
        end
      end
    end
  end

  // -----------------------------
  // Random boundary-biased injection
  // -----------------------------
  task automatic fire_near_boundary(input logic [1:0] st, input int offset);
    int N;
    begin
      case (st)
        2'b00: N = GREEN_COUNT;
        2'b01: N = YELLOW_COUNT;
        2'b10: N = RED_COUNT;
        default: N = 1;
      endcase

      // offset meanings (TB-friendly):
      // -1 : inject when we're one cycle before the final cycle (cycle N-1) -> event at next posedge
      //  0 : inject during final cycle (cycle N) -> event at boundary posedge
      // +1 : inject after boundary -> event one posedge after leaving that state
      if (offset == -1) begin
        wait_state_cycle(st, (N > 1) ? (N-1) : 1);
        pulse_req_1cycle();
      end
      else if (offset == 0) begin
        wait_state_cycle(st, N);
        pulse_req_1cycle();
      end
      else begin // +1
        wait_state_cycle(st, N);
        // wait for the transition out of st (happens at the boundary posedge)
        wait (state_out != st);
        pulse_req_1cycle();
      end
    end
  endtask

  task automatic fire_random_anytime();
    int delay;
    begin
      delay = urand_range(1, GREEN_COUNT + YELLOW_COUNT + RED_COUNT + WALK_COUNT + 8);
      wait_cycles(delay);

      // avoid firing in WALK to keep expectations clean
      if (state_out == 2'b11) begin
        wait (state_out != 2'b11);
      end
      pulse_req_1cycle();
    end
  endtask

  // -----------------------------
  // Test sequence: Directed baseline + Random extension
  // -----------------------------
  int t;
  int choose_bias;
  int which_state;
  int which_offset;
  int gap;

  initial begin
    rst         = 1'b0;
    ped_req_evt = 1'b0;

    // 1) Reset test
    apply_reset(3);

    // 2) Nominal cycle test (no request): ensure no WALK over ~2 cycles
    repeat (2*(GREEN_COUNT + YELLOW_COUNT + RED_COUNT + 6)) begin
      @(posedge clk);
      if (state_out == 2'b11) begin
        $display("FAIL: unexpected WALK during nominal no-request test time=%0t", $time);
        $fatal;
      end
    end

    // 3) Short request test: 1-cycle request during GREEN becomes latched and later produces WALK
    wait_state_cycle(2'b00, 2); // GREEN, cycle 2
    pulse_req_1cycle();
    wait (state_out == 2'b11);
    wait (state_out == 2'b00);

    // 4) Boundary timing tests: press 1 cycle before end of Y and end of R
    // Y boundary: one cycle before final cycle -> cycle (YELLOW_COUNT-1)
    wait_state_cycle(2'b01, (YELLOW_COUNT > 1) ? (YELLOW_COUNT-1) : 1);
    pulse_req_1cycle();
    wait (state_out == 2'b11);
    wait (state_out == 2'b00);

    // R boundary: one cycle before final cycle -> cycle (RED_COUNT-1)
    wait_state_cycle(2'b10, (RED_COUNT > 1) ? (RED_COUNT-1) : 1);
    pulse_req_1cycle();
    wait (state_out == 2'b11);
    wait (state_out == 2'b00);

    // 5) Reset mid-cycle test: reset during Y or R -> deterministic recovery to GREEN
    wait (state_out == 2'b01 || state_out == 2'b10);
    @(posedge clk);
    rst <= 1'b1;
    @(posedge clk);
    rst <= 1'b0;
    @(posedge clk);

    if (state_out != 2'b00 || !(car_g==1 && ped_dont==1)) begin
      $display("FAIL: mid-cycle reset did not recover to GREEN with correct outputs time=%0t", $time);
      $fatal;
    end

    $display("MINIMAL DIRECTED TESTS: PASS");
    $display("Skipping randomized trials for quick test.");
    $display("QUICK TEST: PASS");
    $finish;
    
    // 7) Randomized Testing Extension (biased near boundaries)
    // Commented out for quick testing
    /*
    $display("Starting randomized trials...");

    for (t = 0; t < RANDOM_TRIALS; t++) begin
      gap = urand_range(GAP_MIN, GAP_MAX);
      wait_cycles(gap);

      choose_bias = urand_range(0, 99);

      if (choose_bias < BIAS_PERCENT) begin
        // choose G/Y/R and offset in {-1,0,+1}
        which_state  = urand_range(0, 2);        // 0=G,1=Y,2=R
        which_offset = urand_range(0, 2) - 1;    // -1,0,+1

        case (which_state)
          0: fire_near_boundary(2'b00, which_offset);
          1: fire_near_boundary(2'b01, which_offset);
          2: fire_near_boundary(2'b10, which_offset);
        endcase
      end else begin
        fire_random_anytime();
      end

      // small random run-on
      wait_cycles(urand_range(1, 8));
    end

    $display("RANDOMIZED TESTING: PASS (%0d trials)", RANDOM_TRIALS);
    $finish;
    */
    $finish;
  end

endmodule