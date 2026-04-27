module main#(parameter W = 8)
(
    input [W-1:0] a,
    input [W-1:0] b,
    input sub,
    input signed_mode,
    output [W-1:0] y,
    output carry_no_borrow,
    output zero,
    output negative,
    output overflow
);
    // addition when sub = 0 
    always @(*) begin 
        assign overflow = 0;
        assign y = 0;
        assign sub = 0;
        if(sub == 0) begin
            .half_adder u_decoder (

            );
        end else begin
            y = a + (~b +1);
            overflow = (a[W-1] == b[W-1]) && (y[W-1] != a[W-1]);

        end
    end



endmodule