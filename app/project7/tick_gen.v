module tick_gen 
#(
    parameter DIVISOR = 100000000 

)
( 
    input  clk, 
    input  rst, 
    output reg tick 
);

// 27 bits covers up to 134,217,728 (> 100,000,000) 
    reg [26:0] count; 
 
    always @(posedge clk) begin 
        if (rst) begin 
            count <= 0; 
            tick  <= 0; 
        end 
        else begin 
            if (count == DIVISOR-1) begin 
                count <= 0; 
                tick  <= 1;   // one-cycle pulse 
            end 
            else begin 
                count <= count + 1; 
                tick  <= 0; 
            end 
        end 
    end 
 
endmodule