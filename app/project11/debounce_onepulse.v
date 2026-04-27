`timescale 1ns/1ps

module debounce_onepulse #(parameter DEBOUNCE_CYCLES = 2000000)
(
    input clk,
    input rst,
    input async_in,
    output wire pulse_out
);

    reg [31:0] stable_counter; 
    reg state, debounce_level;
    always @(posedge clk) begin
        if (rst) begin
            state <= 1'b0;
            stable_counter <= 32'd0;
            debounce_level <= 1'b0;
        end
        else begin
            if (async_in != state) begin
                state <= async_in;
                stable_counter <= 32'd0;
            end
            else begin
                if (stable_counter <= DEBOUNCE_CYCLES-1) begin
                    stable_counter <= stable_counter+ 1;
                end
                else begin
                    debounce_level <= state;
                    stable_counter <= 32'd0;
                end
            end
        end
    end
    
    //Edge detect 
    reg level_out_d;
    always @(posedge clk) begin
        if (rst) level_out_d <= 1'b0;
        else level_out_d <= debounce_level;
    end
    assign pulse_out = debounce_level && !level_out_d;

endmodule