module debounce_counter #(
    parameter integer STABLE_CYCLES = 2000000
)(
    input  wire clk,
    input  wire rst,        // synchronous reset
    input  wire in_sync,
    output reg  debounced
);
    reg last_sample;
    reg [31:0] stable_cnt;  // big enough for 2,000,000

    always @(posedge clk) begin
        if (rst) begin
            debounced   <= 1'b0;
            last_sample <= 1'b0;
            stable_cnt  <= 32'd0;
        end else begin
            if (in_sync == last_sample) begin
                if (stable_cnt < STABLE_CYCLES)
                    stable_cnt <= stable_cnt + 1;
            end else begin
                last_sample <= in_sync;
                stable_cnt  <= 32'd0;
            end

            if (stable_cnt == STABLE_CYCLES)
                debounced <= last_sample;
        end
    end
endmodule