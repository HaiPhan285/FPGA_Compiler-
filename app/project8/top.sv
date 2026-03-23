module top (
    input  logic clk,
    input  logic rst,
    output logic CA,
    output logic CB,
    output logic CC,
    output logic CD,
    output logic CE,
    output logic CF,
    output logic CG,
    output logic DP,
    output logic [7:0] AN
);

    logic tick;
    logic [3:0] digit;
    logic [6:0] seg_n;

    tick_gen #(
        .DIVISOR(100_000_000)
    ) u_tick_gen (
        .clk(clk),
        .rst(rst),
        .tick(tick)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            digit <= 4'h1;
        end else if (tick) begin
            if (digit == 4'h9) begin
                digit <= 4'h1;
            end else begin
                digit <= digit + 4'h1;
            end
        end
    end

    always_comb begin
        case (digit)
            4'h1: seg_n = 7'b1001111;
            4'h2: seg_n = 7'b0010010;
            4'h3: seg_n = 7'b0000110;
            4'h4: seg_n = 7'b1001100;
            4'h5: seg_n = 7'b0100100;
            4'h6: seg_n = 7'b0100000;
            4'h7: seg_n = 7'b0001111;
            4'h8: seg_n = 7'b0000000;
            4'h9: seg_n = 7'b0000100;
            default: seg_n = 7'b1111111;
        endcase
    end

    always_comb begin
        // seg_n literals are written in abcdefg order.
        CA = seg_n[6];
        CB = seg_n[5];
        CC = seg_n[4];
        CD = seg_n[3];
        CE = seg_n[2];
        CF = seg_n[1];
        CG = seg_n[0];
        DP = 1'b1;
        AN = 8'b11111110;
    end

endmodule
