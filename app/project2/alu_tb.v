`timescale 1ns / 1ps

module tb_alu;
    parameter w        = 8;
    parameter NUM_RAND = 10000;
    reg  [w-1:0] A, B;
    reg  [2:0]   op;
    wire [w-1:0] y;
    wire         zero, negative, carry, overflow;
    alu #(.w(w)) dut (
        .A(A), .B(B), .op(op),
        .y(y),
        .zero(zero), .negative(negative),
        .carry(carry), .overflow(overflow)
    );
    reg [w-1:0] exp_y;
    reg         exp_zero, exp_negative, exp_carry, exp_overflow;
    reg [w:0]   temp_ref;

    integer pass_count;
    integer fail_count;
    integer i;
    integer rand_a, rand_b, rand_op;
    initial begin
        $dumpfile("alu_waves.vcd");
        $dumpvars(0, tb_alu);
    end
    task reference_model;
        input [w-1:0] a_in, b_in;
        input [2:0]   op_in;
    begin
        exp_carry    = 1'b0;
        exp_overflow = 1'b0;
        temp_ref     = {(w+1){1'b0}};

        case (op_in)
            3'd0: exp_y = a_in & b_in;
            3'd1: exp_y = a_in | b_in;
            3'd2: exp_y = a_in ^ b_in;

            3'd3: begin  // ADD
                temp_ref     = {1'b0, a_in} + {1'b0, b_in};
                exp_y        = temp_ref[w-1:0];
                exp_carry    = temp_ref[w];
                exp_overflow = (~(a_in[w-1] ^ b_in[w-1])) & (exp_y[w-1] ^ a_in[w-1]);
            end

            3'd4: begin  // SUB
                temp_ref     = {1'b0, a_in} + {1'b0, ~b_in} + {{w{1'b0}}, 1'b1};
                exp_y        = temp_ref[w-1:0];
                exp_carry    = temp_ref[w];
                exp_overflow = (a_in[w-1] ^ b_in[w-1]) & (exp_y[w-1] ^ a_in[w-1]);
            end

            3'd5: begin  // SHL
                exp_carry = a_in[w-1];
                exp_y     = a_in << 1;
            end

            3'd6: begin  // SHR
                exp_carry = a_in[0];
                exp_y     = a_in >> 1;
            end

            3'd7: exp_y = a_in;  // PASS A

            default: exp_y = {w{1'b0}};
        endcase

        exp_zero     = (exp_y == {w{1'b0}});
        exp_negative = exp_y[w-1];
    end
    endtask
    task check;
        input [w-1:0] a_in, b_in;
        input [2:0]   op_in;
        input integer test_num;
        input [8*8:1] label;
    begin
        A  = a_in;
        B  = b_in;
        op = op_in;
        #10;

        reference_model(a_in, b_in, op_in);

        if (y        !== exp_y        ||
            zero     !== exp_zero     ||
            negative !== exp_negative ||
            carry    !== exp_carry    ||
            overflow !== exp_overflow)
        begin
            fail_count = fail_count + 1;
            $display("FAIL [%0d] %-8s | A=0x%02h B=0x%02h op=%0d",
                     test_num, label, a_in, b_in, op_in);
            $display("         Got : y=0x%02h Z=%b N=%b C=%b V=%b",
                     y, zero, negative, carry, overflow);
            $display("         Exp : y=0x%02h Z=%b N=%b C=%b V=%b",
                     exp_y, exp_zero, exp_negative, exp_carry, exp_overflow);
            $finish;
        end else begin
            pass_count = pass_count + 1;
        end
    end
    endtask
    initial begin
        pass_count = 0;
        fail_count = 0;
        A = 0; B = 0; op = 0;
        #5;

        $display("============================================");
        $display("   ALU Self-Checking Testbench             ");
        $display("   W = %0d bits                            ", w);
        $display("============================================");
        $display("--- Directed Edge Cases ---");
        // AND
        check(8'h00, 8'hFF, 3'd0,  1, "AND");
        check(8'hFF, 8'hFF, 3'd0,  2, "AND");
        check(8'hAA, 8'h55, 3'd0,  3, "AND");
        check(8'hFF, 8'h00, 3'd0,  4, "AND");
        // OR
        check(8'h00, 8'hFF, 3'd1,  5, "OR");
        check(8'hAA, 8'h55, 3'd1,  6, "OR");
        check(8'h00, 8'h00, 3'd1,  7, "OR");
        // XOR
        check(8'hFF, 8'hFF, 3'd2,  8, "XOR");
        check(8'hAA, 8'h55, 3'd2,  9, "XOR");
        check(8'h00, 8'h00, 3'd2, 10, "XOR");
        // ADD normal
        check(8'h00, 8'h00, 3'd3, 11, "ADD");
        check(8'h01, 8'h01, 3'd3, 12, "ADD");
        check(8'hFE, 8'h01, 3'd3, 13, "ADD");
        // ADD carry out
        check(8'hFF, 8'h01, 3'd3, 14, "ADD");
        check(8'hFF, 8'hFF, 3'd3, 15, "ADD");
        // ADD overflow pos+pos=neg
        check(8'h7F, 8'h01, 3'd3, 16, "ADD");
        check(8'h40, 8'h40, 3'd3, 17, "ADD");
        // ADD overflow neg+neg=pos
        check(8'h80, 8'h80, 3'd3, 18, "ADD");
        // SUB normal
        check(8'h01, 8'h01, 3'd4, 19, "SUB");
        check(8'hFF, 8'h01, 3'd4, 20, "SUB");
        check(8'hFF, 8'hFF, 3'd4, 21, "SUB");
        // SUB borrow
        check(8'h00, 8'h01, 3'd4, 22, "SUB");
        check(8'h01, 8'hFF, 3'd4, 23, "SUB");
        // SUB overflow pos-neg=neg
        check(8'h7F, 8'hFF, 3'd4, 24, "SUB");
        // SUB overflow neg-pos=pos
        check(8'h80, 8'h01, 3'd4, 25, "SUB");
        // SHL
        check(8'h01, 8'h00, 3'd5, 26, "SHL");
        check(8'h80, 8'h00, 3'd5, 27, "SHL");
        check(8'hFF, 8'h00, 3'd5, 28, "SHL");
        check(8'h40, 8'h00, 3'd5, 29, "SHL");
        // SHR
        check(8'h01, 8'h00, 3'd6, 30, "SHR");
        check(8'h80, 8'h00, 3'd6, 31, "SHR");
        check(8'hFF, 8'h00, 3'd6, 32, "SHR");
        check(8'h02, 8'h00, 3'd6, 33, "SHR");
        // PASS A
        check(8'h00, 8'h00, 3'd7, 34, "PASS");
        check(8'hAB, 8'h00, 3'd7, 35, "PASS");
        check(8'hFF, 8'h00, 3'd7, 36, "PASS");
        check(8'h80, 8'h00, 3'd7, 37, "PASS");

        $display("  Directed tests passed: %0d", pass_count);
        $display("--- Randomized Tests (%0d vectors) ---", NUM_RAND);

        for (i = 0; i < NUM_RAND; i = i + 1) begin
            rand_a  = $random;
            rand_b  = $random;
            rand_op = $random % 8;
            if (rand_op < 0) rand_op = -rand_op;

            check(rand_a[7:0], rand_b[7:0], rand_op[2:0], 100 + i, "RAND");
        end
        $display("  Random tests passed: %0d", pass_count - 37);
        $display("============================================");
        if (fail_count == 0)
            $display("RESULT: PASS  (%0d vectors checked)", pass_count);
        else
            $display("RESULT: FAIL  (%0d/%0d failed)", fail_count, pass_count + fail_count);
        $display("============================================");

        $finish;
    end

endmodule