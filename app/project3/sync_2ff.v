module sync_2ff (
    input  wire clk,
    input  wire rst,        // synchronous reset
    input  wire async_in,
    output wire sync_out
);
    reg ff1, ff2;

    always @(posedge clk) begin
        if (rst) begin
            ff1 <= 1'b0;
            ff2 <= 1'b0;
        end else begin
            ff1 <= async_in;
            ff2 <= ff1;
        end
    end

    assign sync_out = ff2;
endmodule