`timescale 1ns/1ps

module time_core(
    input clk,
    input rst,
    input tick_enable,
    input min_pulse,
    input hr_pulse,
    output reg[5:0] second,
    output reg[5:0] minute,
    output reg[4:0] hour,
    output reg day_enable
);

always @(posedge clk) begin
    if (rst) begin
        second <= 0;
        minute <= 0;
        hour <= 0;
        day_enable <= 0;
    end
    else begin
        day_enable <= 0;

        //TIme control by tick_1hz signal (Synchrnous)
        if (tick_enable) begin
            if (second == 59) begin
                second <= 0;
                
                if (minute == 59) begin
                    minute <= 0;

                    if (hour == 23) begin
                        hour <= 0;
                        day_enable <= 1;
                    end
                    else hour <= hour + 1;
                end
                else minute <= minute + 1;
            end
            else second <= second + 1;
        end
        
        //Manual Editing
        else begin

            if (hr_pulse) begin
                second <= 6'd0;

                if (hour == 5'd23)
                    hour <= 5'd0;
                else
                    hour <= hour + 5'd1;
            end
            else if (min_pulse) begin
                second <= 6'd0;

                if (minute == 6'd59)
                    minute <= 6'd0;
                else
                    minute <= minute + 6'd1;
            end
        end
    end
end

endmodule