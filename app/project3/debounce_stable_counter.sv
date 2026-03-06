module debounce_stable_counter #(
    parameter int unsigned STABLE_CYCLES = 1_000_000
) (
    input  logic clk,
    input  logic rst_n,
    input  logic din_sync,       // already synchronized
    output logic dout_clean
);

    logic din_q;
    int unsigned cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            din_q      <= 1'b0;
            dout_clean <= 1'b0;
            cnt        <= 0;
        end else begin
            if (din_sync == din_q) begin
                if (cnt < STABLE_CYCLES) cnt <= cnt + 1;
                if (cnt == STABLE_CYCLES - 1) dout_clean <= din_q;
            end else begin
                din_q <= din_sync;
                cnt   <= 0;
            end
        end
    end

endmodule