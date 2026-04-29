`timescale 1ns/1ps

module top #(
    parameter DIVISOR = 100_000_000,
    parameter DEBOUNCE_CYCLES = 2_000_000
)
(
    input         CLK100MHZ,
    input         CPU_RESETN,
    input  [1:0]  SW,
    input         BTNC,
    input         BTNL,
    input         BTNR,
    input         BTND,
    output [6:0]  SEG,
    output        DP,
    output [7:0]  AN
);

wire rst = ~CPU_RESETN;
wire mode_pulse, inc_pulse, next_pulse, dec_pulse;

sync_deb_edge #(
    .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
) u_mode(
    .clk(CLK100MHZ),
    .reset(rst),
    .async_in(BTNL),
    .pulse_out(mode_pulse)
);

sync_deb_edge #(
    .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
) u_inc(
    .clk(CLK100MHZ),
    .reset(rst),
    .async_in(BTNC),
    .pulse_out(inc_pulse)
);

sync_deb_edge #(
    .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
) u_next(
    .clk(CLK100MHZ),
    .reset(rst),
    .async_in(BTNR),
    .pulse_out(next_pulse)
);

sync_deb_edge #(
    .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
) u_dec(
    .clk(CLK100MHZ),
    .reset(rst),
    .async_in(BTND),
    .pulse_out(dec_pulse)
); 

wire tick_1hz;
tick_divider #(
    .DIVISOR(DIVISOR)
) u_tick (
    .clk(CLK100MHZ),
    .rst(rst),
    .tick(tick_1hz)
);

localparam RUN = 3'd0,
           SET_MINUTE = 3'd1,
           SET_HOUR = 3'd2,
           SET_DAY = 3'd3,
           SET_MONTH = 3'd4,
           SET_YEAR = 3'd5;

wire [1:0] display_mode = SW;
wire [2:0] state;
rtc_set_fsm u_fsm(
    .clk(CLK100MHZ),
    .rst(rst),
    .mode_pulse(mode_pulse),
    .next_pulse(next_pulse),
    .state(state)
);

wire tick_enable = tick_1hz && (state == RUN);

wire [5:0] second;
wire [5:0] minute;
wire [4:0] hour;
wire [4:0] day;
wire [3:0] month;
wire [15:0] year;
 
rtc_datapath u_data(
    .clk(CLK100MHZ),
    .rst(rst),
    .tick_enable(tick_enable),
    .state(state),
    .inc_pulse(inc_pulse),
    .dec_pulse(dec_pulse),
    .second(second),
    .minute(minute),
    .hour(hour),
    .day(day),
    .month(month),
    .year(year)
);

rtc_display u_display (
    .clk(CLK100MHZ),
    .rst(rst),
    .second(second),
    .minute(minute),
    .hour(hour),
    .day(day),
    .month(month),
    .year(year),
    .state(state),
    .display_mode(display_mode),
    .seg_n(SEG),
    .AN(AN),
    .DP(DP)
);
    
endmodule