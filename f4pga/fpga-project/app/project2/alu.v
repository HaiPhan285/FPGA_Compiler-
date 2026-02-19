`timescale 1ns / 1ps

module alu #(parameter w = 8)
(
    input [w-1:0]A, B,
    input [2:0] op,
    output reg [w-1:0] y,
    output reg zero, negative, carry, overflow
    
);
    reg [w:0] temp;
    always @(*)
    begin
        // Default assignments to avoid latches
        y = 0;
        temp = 0;
        carry = 0;
        overflow = 0;
        
        case (op)
            3'd0: y = A & B;          
            3'd1: y = A | B;          
            3'd2: y = A ^ B;
            3'd3: begin               
                temp  = {1'b0,A} + {1'b0,B};
                y     = temp[w-1:0];
                carry = temp[w];
                overflow = (~(A[w-1] ^ B[w-1])) & (y[w-1] ^ A[w-1]);
            end
            3'd4: begin               
                temp  = {1'b0,A} + {1'b0,(~B)} + 1'b1;
                y     = temp[w-1:0];
                carry = temp[w];  
                overflow = (A[w-1] ^ B[w-1]) & (y[w-1] ^ A[w-1]);
            end         
            3'd5: y = A << 1;         
            3'd6: y = A >> 1;        
            3'd7: y = A;  
            default: y = 0;   
        endcase
        zero = (y == 0
        );
        negative = y[w-1];
    end 
    

endmodule
