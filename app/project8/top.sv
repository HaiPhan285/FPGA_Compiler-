`timescale 1ns/1ps

module top (
    input  logic       CLK100MHZ,
    input  logic       CPU_RESETN,
    input logic        BTNC,
    input logic        BTNL,
    input logic        BTNR,

    output logic       CA,
    output logic       CB,
    output logic       CC,
    output logic       CD,
    output logic       CE,
    output logic       CF,
    output logic       CG,
    output logic       DP,
    output logic [7:0] AN
);

    //Convert to reset logic high
    logic rst;
    assign rst = ~CPU_RESETN;

    //--------------------------------------------------------------------------
    // Intermediate signal
    //--------------------------------------------------------------------------
    logic tick_1hz;
    logic sec_rollover;
    logic min_rollover;

    //Button pulse generator
    logic btn_sec_pulse, btn_min_pulse, btn_hr_pulse;
    sync_deb_edge u_btn_hr (
        .clk       (CLK100MHZ),
        .reset     (rst),
        .async_in  (BTNL),
        .pulse_out (btn_hr_pulse)
    );

    sync_deb_edge u_btn_min (
        .clk (CLK100MHZ),
        .reset (rst),
        .async_in (BTNC),
        .pulse_out (btn_min_pulse)
    );

    sync_deb_edge u_btn_sec (
        .clk (CLK100MHZ),
        .reset (rst),
        .async_in (BTNR),
        .pulse_out (btn_sec_pulse)
    );

    logic [5:0] seconds;
    logic [5:0] minutes;
    logic [4:0] hours;


    tick_gen #(
        .DIVISOR(100_000_000)
    ) u_tick_gen (
        .clk  (CLK100MHZ),
        .rst  (rst),
        .tick (tick_1hz)
    );

    second_counter u_second_counter (
        .clk           (CLK100MHZ),
        .rst           (rst),
        .tick_1hz      (tick_1hz),
        .btn_sec_pulse (btn_sec_pulse),
        .sec_rollover  (sec_rollover),
        .seconds       (seconds)
    );

    minute_counter u_minute_counter (
        .clk          (CLK100MHZ),
        .rst          (rst),
        .sec_rollover (sec_rollover),
        .btn_min_pulse (btn_min_pulse),
        .minutes      (minutes),
        .min_rollover (min_rollover)
    );

    hour_counter u_hour_counter (
        .clk          (CLK100MHZ),
        .rst          (rst),
        .btn_hr_pulse (btn_hr_pulse),
        .min_rollover (min_rollover),
        .hours        (hours)
    );

    //--------------------------------------------------------------------------
    // Break HH:MM:SS into decimal digits
    //--------------------------------------------------------------------------
    logic [3:0] hr_tens,  hr_ones,
       min_tens, min_ones,
       sec_tens, sec_ones;

    always_comb begin
        hr_tens  = hours   / 10;
        hr_ones  = hours   % 10;
        min_tens = minutes / 10;
        min_ones = minutes % 10;
        sec_tens = seconds / 10;
        sec_ones = seconds % 10;
    end

    //--------------------------------------------------------------------------
    // Display multiplexing
    // Use refresh counter to scan all 8 digits fast enough
    //--------------------------------------------------------------------------
    logic [16:0] refresh_counter;
    logic [2:0]  digit_sel;
    logic [3:0]  current_digit;
    logic        blank_digit;

    always_ff @(posedge CLK100MHZ) begin
        if (rst)
            refresh_counter <= '0;
        else
            refresh_counter <= refresh_counter + 1'b1;
    end

    assign digit_sel = refresh_counter[16:14];

    //--------------------------------------------------------------------------
    // Digit select
    // Active-low AN on Nexys A7
    // Rightmost digit is AN[0]
    
    always_comb begin
        AN          = 8'b1111_1111;
        DP          = 1'b1;       // decimal point off (active-low)
        current_digit = 4'd0;
        blank_digit = 1'b0;

        case (digit_sel)
            3'd0: begin
                AN = 8'b1111_1110;   // AN[0]
                current_digit = sec_ones;
            end
            3'd1: begin
                AN = 8'b1111_1101;   // AN[1]
                current_digit = sec_tens;
            end
            3'd2: begin
                AN = 8'b1111_1011;   // AN[2]
                current_digit = min_ones;
            end
            3'd3: begin
                AN = 8'b1111_0111;   // AN[3]
                current_digit = min_tens;
            end
            3'd4: begin
                AN = 8'b1110_1111;   // AN[4]
                current_digit = hr_ones;
            end
            3'd5: begin
                AN = 8'b1101_1111;   // AN[5]
                current_digit = hr_tens;
            end
            3'd6: begin
                AN = 8'b1011_1111;   // AN[6]
                blank_digit = 1'b1;
            end
            3'd7: begin
                AN = 8'b0111_1111;   // AN[7]
                blank_digit = 1'b1;
            end
            default: begin
                AN = 8'b1111_1111;
                blank_digit = 1'b1;
            end
        endcase
    end

    //--------------------------------------------------------------------------
    // 7-segment decoder
    // Active-low segments: 0 = ON
    // Segment order: {CA, CB, CC, CD, CE, CF, CG}
    //--------------------------------------------------------------------------
    always_comb begin
        if (blank_digit) begin
            {CA, CB, CC, CD, CE, CF, CG} = 7'b111_1111;
        end
        else begin
            case (current_digit)
                4'd0: {CA, CB, CC, CD, CE, CF, CG} = 7'b000_0001;
                4'd1: {CA, CB, CC, CD, CE, CF, CG} = 7'b100_1111;
                4'd2: {CA, CB, CC, CD, CE, CF, CG} = 7'b001_0010;
                4'd3: {CA, CB, CC, CD, CE, CF, CG} = 7'b000_0110;
                4'd4: {CA, CB, CC, CD, CE, CF, CG} = 7'b100_1100;
                4'd5: {CA, CB, CC, CD, CE, CF, CG} = 7'b010_0100;
                4'd6: {CA, CB, CC, CD, CE, CF, CG} = 7'b010_0000;
                4'd7: {CA, CB, CC, CD, CE, CF, CG} = 7'b000_1111;
                4'd8: {CA, CB, CC, CD, CE, CF, CG} = 7'b000_0000;
                4'd9: {CA, CB, CC, CD, CE, CF, CG} = 7'b000_0100;
                default:
                      {CA, CB, CC, CD, CE, CF, CG} = 7'b111_1111;
            endcase
        end
    end

endmodule