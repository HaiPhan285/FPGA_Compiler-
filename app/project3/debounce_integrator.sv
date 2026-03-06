module debounce_integrator #(
    parameter int unsigned WIDTH = 20
) (
    input  logic clk,
    input  logic rst_n,
    input  logic din_sync,       // MUST already be synchronized
    output logic dout_clean
);

    localparam int unsigned MAX = (1 << WIDTH) - 1;
    logic [WIDTH-1:0] acc;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc        <= '0;
            dout_clean <= 1'b0;
        end else begin
            if (din_sync) begin
                if (acc != MAX[WIDTH-1:0]) acc <= acc + 1'b1;
            end else begin
                if (acc != '0) acc <= acc - 1'b1;
            end

            if (acc == MAX[WIDTH-1:0])      dout_clean <= 1'b1;
            else if (acc == '0)             dout_clean <= 1'b0;
        end
    end

endmodule