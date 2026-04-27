`timescale 1ns/1ps

module rtc_edit_datapath(
    input[2:0] state,
    input[1:0] display_mode,
    input inc_pulse,

    output min_pulse,
    output hr_pulse,
    output day_pulse,
    output month_pulse,
    output year_pulse,
    output reg[7:0] blink_mask      //Mask the bit that are not set in the current state (keep those lighting up and standing still)
);

localparam RUN = 3'd0,
           SET_MINUTE = 3'd1,
           SET_HOUR = 3'd2,
           SET_DAY = 3'd3,
           SET_MONTH = 3'd4,
           SET_YEAR = 3'd5;


assign min_pulse   = (state == SET_MINUTE) && inc_pulse;
assign hr_pulse    = (state == SET_HOUR)   && inc_pulse;
assign day_pulse   = (state == SET_DAY)    && inc_pulse;
assign month_pulse = (state == SET_MONTH)  && inc_pulse;
assign year_pulse  = (state == SET_YEAR)   && inc_pulse;

always @(*) begin
    blink_mask = 8'b0000_0000;

    //Control d0 - d7 depend on the mode and only during SET mode
    case (display_mode)
        2'b00: begin //Time mode
            case (state)
                SET_MINUTE: blink_mask = 8'b1100_1100;
                SET_HOUR: blink_mask = 8'b1111_0000;
                default: blink_mask = 8'b0000_0000;
            endcase
        end
        2'b01: begin //Calendar mode
            case (state)
                SET_DAY: blink_mask = 8'b0000_0011;
                SET_MONTH: blink_mask = 8'b0000_1100;
                SET_YEAR: blink_mask = 8'b1111_0000;
                default: blink_mask = 8'b0000_0000;
            endcase
        end
    default: blink_mask = 8'b0000_0000;
    endcase
end            

endmodule