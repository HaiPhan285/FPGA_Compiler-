// ======================= sync_debounce.v =======================
`timescale 1ns/1ps
// Synchronizer + Debounce + Rising-edge Pulse (press event)

module sync_2ff (
    input  wire clk,
    input  wire rst_n,
    input  wire async_in,
    output reg  sync_out
);
    reg ff1;
    always @(posedge clk) begin
        if (!rst_n) begin
            ff1      <= 1'b0;
            sync_out <= 1'b0;
        end else begin
            ff1      <= async_in;
            sync_out <= ff1;
        end
    end
endmodule

module debounce #(
    parameter integer STABLE_CYCLES = 20
)(
    input  wire clk,
    input  wire rst_n,
    input  wire din,
    output reg  dout
);
    reg din_prev;

    function integer clog2;
        input integer value;
        integer i;
        begin
            value = value - 1;
            for (i = 0; value > 0; i = i + 1)
                value = value >> 1;
            clog2 = i;
        end
    endfunction

    localparam integer CNTW    = (STABLE_CYCLES <= 1) ? 1 : clog2(STABLE_CYCLES + 1);
    localparam integer STABLE_M1 = STABLE_CYCLES - 1;
    reg [CNTW-1:0] cnt;

    always @(posedge clk) begin
        if (!rst_n) begin
            din_prev <= 1'b0;
            dout     <= 1'b0;
            cnt      <= {CNTW{1'b0}};
        end else begin
            if (din == din_prev) begin
                if (cnt < STABLE_CYCLES[CNTW-1:0])
                    cnt <= cnt + {{(CNTW-1){1'b0}},1'b1};

                if (cnt == STABLE_M1[CNTW-1:0])
                    dout <= din;
            end else begin
                din_prev <= din;
                cnt      <= {CNTW{1'b0}};
            end
        end
    end
endmodule

module edge_pulse (
    input  wire clk,
    input  wire rst_n,
    input  wire level_in,
    output reg  pulse_out
);
    reg level_d;
    always @(posedge clk) begin
        if (!rst_n) begin
            level_d   <= 1'b0;
            pulse_out <= 1'b0;
        end else begin
            pulse_out <= level_in & ~level_d; // 1-cycle rising edge
            level_d   <= level_in;
        end
    end
endmodule

module sync_debounce #(
    parameter integer STABLE_CYCLES = 20
)(
    input  wire clk,
    input  wire rst_n,
    input  wire async_btn,
    output wire clean_level,
    output wire press_pulse
);
    wire sync_level;

    sync_2ff u_sync (
        .clk(clk), .rst_n(rst_n),
        .async_in(async_btn),
        .sync_out(sync_level)
    );

    debounce #(.STABLE_CYCLES(STABLE_CYCLES)) u_db (
        .clk(clk), .rst_n(rst_n),
        .din(sync_level),
        .dout(clean_level)
    );

    edge_pulse u_ep (
        .clk(clk), .rst_n(rst_n),
        .level_in(clean_level),
        .pulse_out(press_pulse)
    );
endmodule