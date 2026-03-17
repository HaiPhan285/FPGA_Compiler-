module second_tick_gen #(parameter DIVISOR = 100000000)
(
    input logic clk,
    input logic rst,
    output logic tick
);

    reg[26:0]  count;
    always @(posedge clk) begin
        
    end

endmodule