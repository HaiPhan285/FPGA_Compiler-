module top
#(
    parameter integer DIVISOR = 100_000_000
)
(
    input  wire clk,
    input  wire rst,     // BTNC: active-high
    output wire led
);

    wire tick;

    tick_gen #(
        .DIVISOR(DIVISOR)
    ) u_tick (
        .clk  (clk),
        .rst  (rst),      // no inversion
        .tick (tick)
    );

    reg led_reg = 1'b0;

    always @(posedge clk) begin
        if (rst)
            led_reg <= 1'b0;
        else if (tick)
            led_reg <= ~led_reg;
    end

    assign led = led_reg;

endmodule