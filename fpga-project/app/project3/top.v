module top (
    input  wire        CLK100MHZ,
    input  wire        btnc,
    input  wire        sw0,
    output wire [7:0]  led
);
    wire rst = sw0;

    // 1) sync
    wire btn_sync;
    sync_2ff u_sync (
        .clk(CLK100MHZ),
        .rst(rst),
        .async_in(btnc),
        .sync_out(btn_sync)
    );

    // 2) debounce (20ms @100MHz)
    wire btn_db;
    debounce_counter #(.STABLE_CYCLES(2000000)) u_db (
        .clk(CLK100MHZ),
        .rst(rst),
        .in_sync(btn_sync),
        .debounced(btn_db)
    );

    // 3) rising edge pulse
    wire press_pulse;
    edge_rise u_edge (
        .clk(CLK100MHZ),
        .rst(rst),
        .level_in(btn_db),
        .pulse_out(press_pulse)
    );

    // 4) counter with CE
    wire [7:0] count;
    counter_ce #(.WIDTH(8)) u_cnt (
        .clk(CLK100MHZ),
        .rst(rst),
        .ce(press_pulse),
        .q(count)
    );

    // 5) display mapping
    assign led = count;

endmodule