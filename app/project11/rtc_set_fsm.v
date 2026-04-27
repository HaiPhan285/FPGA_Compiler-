`timescale 1ns/1ps

module rtc_set_fsm (
    input clk,
    input rst,
    input mode_pulse,
    input next_pulse,
    output reg [2:0] state
);
localparam RUN = 3'd0,
           SET_MINUTE = 3'd1,
           SET_HOUR = 3'd2,
           SET_DAY = 3'd3,
           SET_MONTH = 3'd4,
           SET_YEAR = 3'd5;

reg [2:0] state_n;

always @(posedge clk) begin
    if (rst) begin 
        state <= 0;
    end
    else begin
        state <= state_n;
    end
end

always @(*) begin
    state_n = state;
    case (state) 
        RUN: if (mode_pulse) state_n = SET_MINUTE;
        SET_MINUTE: begin
            if (mode_pulse) state_n = RUN;
            else if (next_pulse) state_n = SET_HOUR;
        end
        SET_HOUR: begin 
            if (mode_pulse) state_n = RUN;
            else if (next_pulse) state_n = SET_DAY;
        end
        SET_DAY: begin
            if (mode_pulse) state_n = RUN;
            else if (next_pulse) state_n = SET_MONTH;
        end
        SET_MONTH: begin
            if (mode_pulse) state_n = RUN;
            else if (next_pulse) state_n = SET_YEAR;
        end
        SET_YEAR: begin
            if (mode_pulse) state_n = RUN;
            else if (next_pulse) state_n = SET_MINUTE;
        end
        default: state_n = RUN;
    endcase
end
           

endmodule