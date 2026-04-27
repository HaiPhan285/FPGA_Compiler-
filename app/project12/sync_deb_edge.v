`timescale 1ns/1ps

module sync_deb_edge #(parameter DEBOUNCE_CYCLES = 2000000)(
        input clk,
        input reset,
        input async_in,
        output wire pulse_out
    );
    
    reg ff1, ff2;
    wire sync_out;
    always @(posedge clk) begin
        if (reset) begin
            ff1 <= 1'b0;
            ff2 <= 1'b0;
        end
        else begin
            ff1 <= async_in;
            ff2 <= ff1;
        end
    end 
    
    assign sync_out = ff2;
    
    reg [31:0] stable_counter; 
    reg state, debounce_level;
    always @(posedge clk) begin
        if (reset) begin
            state <= 1'b0;
            stable_counter <= 32'd0;
            debounce_level <= 1'b0;
        end
        else begin
            if (sync_out != state) begin
                state <= sync_out;
                stable_counter <= 32'd0;
            end
            else begin
                if (stable_counter <= DEBOUNCE_CYCLES) begin
                    stable_counter <= stable_counter+ 1;
                end
                else begin
                    debounce_level <= state;
                end
            end
        end
    end
    
    //Edge detect 
    reg level_out_d;
    always @(posedge clk) begin
        if (reset) level_out_d <= 1'b0;
        else level_out_d <= debounce_level;
    end
    assign pulse_out = debounce_level && !level_out_d;
    
endmodule
