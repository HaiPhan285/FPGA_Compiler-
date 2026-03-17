
module tick_gen #(parameter wd = 100000000)
(   
    input logic clk,
    input logic rst,
    output logic  tick
);

    reg [26:0] count;

    always @(posedge clk) begin
        if(rst) begin
            count <= 0;
            tick <= 0;
        end
        else begin
            if(count == DIVISOR-1) begin
                count <= 0;
                tick <= 1;
            end
            else begin
                cout <= cout + 1;
                tick <= 0;
            end
        end
    end