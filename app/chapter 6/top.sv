// fsm_traffic.sv
// Moore FSM: G -> Y -> R -> (W optional) -> G
// ped_press_evt is a 1-cycle clean pulse from sync+debounce.
// ped_req_latched stores the request until WALK completes.
// Includes clock divider for real-time second-based timing

module top #(
  parameter int unsigned CLK_FREQ_MHZ = 100,
  parameter int unsigned G_SEC = 5,
  parameter int unsigned Y_SEC = 2,
  parameter int unsigned R_SEC = 4,
  parameter int unsigned W_SEC = 3,
  parameter int unsigned SIM_MODE = 0
) (
  input  logic clk,
  input  logic rst,
  input  logic ped_press_evt,

  output logic CAR_G,
  output logic CAR_Y,
  output logic CAR_R,
  output logic PED_WALK,
  output logic PED_DONT,
  output logic ped_req_latched,
  output logic clk_1hz
);

  localparam int unsigned DIVIDER = SIM_MODE ? 10 : (CLK_FREQ_MHZ * 1000000 / 2);
  localparam int unsigned CNT_W = $clog2(DIVIDER);

  localparam [1:0] G_STATE = 2'b00;
  localparam [1:0] Y_STATE = 2'b01;
  localparam [1:0] R_STATE = 2'b10;
  localparam [1:0] W_STATE = 2'b11;

  logic clk_div;
  logic [CNT_W-1:0] div_cnt;

  always_ff @(posedge clk) begin
    if (rst) begin
      div_cnt <= '0;
      clk_div <= 1'b0;
    end else begin
      if (div_cnt >= DIVIDER - 1) begin
        div_cnt <= '0;
        clk_div <= ~clk_div;
      end else begin
        div_cnt <= div_cnt + 1'b1;
      end
    end
  end

  assign clk_1hz = clk_div;

  localparam int unsigned G_TICKS = G_SEC;
  localparam int unsigned Y_TICKS = Y_SEC;
  localparam int unsigned R_TICKS = R_SEC;
  localparam int unsigned W_TICKS = W_SEC;

  logic [1:0] state, next_state;

  always_ff @(posedge clk_div) begin
    if (rst) begin
      ped_req_latched <= 1'b0;
    end else begin
      if (ped_press_evt) ped_req_latched <= 1'b1;
      if (state == W_STATE && next_state == G_STATE) ped_req_latched <= 1'b0;
    end
  end

  logic [31:0] tick_cnt;
  logic [31:0] limit;
  logic        t_done;

  always_comb begin
    case (state)
      G_STATE: limit = (G_TICKS == 0) ? 0 : (G_TICKS - 1);
      Y_STATE: limit = (Y_TICKS == 0) ? 0 : (Y_TICKS - 1);
      R_STATE: limit = (R_TICKS == 0) ? 0 : (R_TICKS - 1);
      W_STATE: limit = (W_TICKS == 0) ? 0 : (W_TICKS - 1);
      default: limit = 0;
    endcase
  end

  assign t_done = (tick_cnt >= limit);

  always_ff @(posedge clk_div) begin
    if (rst) begin
      tick_cnt <= 32'd0;
    end else begin
      if (state != next_state) tick_cnt <= 32'd0;
      else if (!t_done)        tick_cnt <= tick_cnt + 32'd1;
      else                     tick_cnt <= tick_cnt;
    end
  end

  always_ff @(posedge clk_div) begin
    if (rst) state <= G_STATE;
    else     state <= next_state;
  end

  always_comb begin
    next_state = state;

    case (state)
      G_STATE: if (t_done) next_state = Y_STATE;
      Y_STATE: if (t_done) next_state = R_STATE;
      R_STATE: if (t_done) next_state = ped_req_latched ? W_STATE : G_STATE;
      W_STATE: if (t_done) next_state = G_STATE;
      default: next_state = G_STATE;
    endcase
  end

  always_comb begin
    CAR_G    = 1'b0;
    CAR_Y    = 1'b0;
    CAR_R    = 1'b0;
    PED_WALK = 1'b0;
    PED_DONT = 1'b0;

    case (state)
      G_STATE: begin
        CAR_G    = 1'b1;
        PED_DONT = 1'b1;
      end
      Y_STATE: begin
        CAR_Y    = 1'b1;
        PED_DONT = 1'b1;
      end
      R_STATE: begin
        CAR_R    = 1'b1;
        PED_DONT = 1'b1;
      end
      W_STATE: begin
        CAR_R    = 1'b1;
        PED_WALK = 1'b1;
        PED_DONT = 1'b0;
      end
      default: begin
        CAR_G    = 1'b1;
        PED_DONT = 1'b1;
      end
    endcase
  end

endmodule
