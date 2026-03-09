// ======================= fsm_traffic.v =======================
`timescale 1ns/1ps
// Traffic light FSM + timers + latched pedestrian request (Verilog-2001)

module fsm_traffic #(
    parameter integer GREEN_TICKS      = 100,
    parameter integer YELLOW_TICKS     = 30,
    parameter integer RED_TICKS        = 60,
    parameter integer WALK_TICKS       = 40,
    parameter integer DEBOUNCE_STABLE  = 20
)(
    input  wire clk,
    input  wire rst_n,
    input  wire ped_btn_async,

    output reg  car_g,
    output reg  car_y,
    output reg  car_r,
    output reg  ped_walk,
    output reg  ped_dont
);

    // ---- button conditioning ----
    wire ped_level;
    wire ped_press;

    sync_debounce #(.STABLE_CYCLES(DEBOUNCE_STABLE)) u_btn (
        .clk(clk),
        .rst_n(rst_n),
        .async_btn(ped_btn_async),
        .clean_level(ped_level),
        .press_pulse(ped_press)
    );

    // ---- request latch ----
    reg ped_req_latched;

    // ---- FSM states ----
    localparam [1:0] S_GREEN  = 2'b00;
    localparam [1:0] S_YELLOW = 2'b01;
    localparam [1:0] S_RED    = 2'b10;
    localparam [1:0] S_WALK   = 2'b11;

    reg [1:0] state, next_state;

    // ---- timer ----
    reg [31:0] tick_cnt;
    reg [31:0] tick_limit;
    wire       time_done;

    assign time_done = (tick_cnt >= (tick_limit - 1));

    // tick_limit based on state
    always @(*) begin
        case (state)
            S_GREEN:  tick_limit = GREEN_TICKS;
            S_YELLOW: tick_limit = YELLOW_TICKS;
            S_RED:    tick_limit = RED_TICKS;
            S_WALK:   tick_limit = WALK_TICKS;
            default:  tick_limit = GREEN_TICKS;
        endcase
    end

    // ---- sequential: state + timer + latch ----
    always @(posedge clk) begin
        if (!rst_n) begin
            state           <= S_GREEN;
            tick_cnt        <= 32'd0;
            ped_req_latched <= 1'b0;
        end else begin
            // latch request on press
            if (ped_press)
                ped_req_latched <= 1'b1;

            // update state
            state <= next_state;

            // timer reset on state change
            if (state != next_state)
                tick_cnt <= 32'd0;
            else if (!time_done)
                tick_cnt <= tick_cnt + 32'd1;

            // clear request after WALK completes
            if ((state == S_WALK) && time_done)
                ped_req_latched <= 1'b0;
        end
    end

    // ---- next-state logic ----
    always @(*) begin
        next_state = state;
        case (state)
            S_GREEN:  if (time_done) next_state = S_YELLOW;
            S_YELLOW: if (time_done) next_state = S_RED;

            S_RED: begin
                if (time_done) begin
                    if (ped_req_latched) next_state = S_WALK;
                    else                 next_state = S_GREEN;
                end
            end

            S_WALK: if (time_done) next_state = S_GREEN;

            default: next_state = S_GREEN;
        endcase
    end

    // ---- outputs (Moore) ----
    always @(*) begin
        // defaults
        car_g    = 1'b0;
        car_y    = 1'b0;
        car_r    = 1'b0;
        ped_walk = 1'b0;
        ped_dont = 1'b1;

        case (state)
            S_GREEN: begin
                car_g    = 1'b1;
                ped_dont = 1'b1;
            end
            S_YELLOW: begin
                car_y    = 1'b1;
                ped_dont = 1'b1;
            end
            S_RED: begin
                car_r    = 1'b1;
                ped_dont = 1'b1;
            end
            S_WALK: begin
                car_r    = 1'b1;  // cars stopped during walk
                ped_walk = 1'b1;
                ped_dont = 1'b0;
            end
            default: begin
            end
        endcase
    end

endmodule