`timescale 1ns/1ps

module  rtc_mode_mux(
    input [1:0] display_mode,
    
    input [3:0] sec_tens,
    input [3:0] sec_ones,
    input [3:0] min_tens,
    input [3:0] min_ones,
    input [3:0] hour_tens,
    input [3:0] hour_ones,
    input [3:0] day_tens,
    input [3:0] day_ones,
    input [3:0] month_tens,
    input [3:0] month_ones,
    input [3:0] year_thousands,
    input [3:0] year_hundreds,
    input [3:0] year_tens,
    input [3:0] year_ones,

    output reg [3:0] d7,
    output reg [3:0] d6,
    output reg [3:0] d5,
    output reg [3:0] d4,
    output reg [3:0] d3,
    output reg [3:0] d2,
    output reg [3:0] d1,
    output reg [3:0] d0
);

    always @(*) begin
        d7 = 4'hF; d6 = 4'hF; d5 = 4'hF; d4 = 4'hF; 
        d3 = 4'hF; d2 = 4'hF; d1 = 4'hF; d0 = 4'hF;

        case (display_mode)
            2'b00: begin
                d5 = hour_tens; d4 = hour_ones;
                d3 = min_tens; d2 = min_ones;
                d1 = sec_tens; d0 = sec_ones;
            end
            2'b01: begin
                d7 = year_thousands; d6 = year_hundreds;
                d5 = year_tens; d4 = year_ones;
                d3 = month_tens; d2 = month_ones;
                d1 = day_tens; d0 = day_ones;
            end
            default: begin 
            end
        endcase
    end
    
endmodule