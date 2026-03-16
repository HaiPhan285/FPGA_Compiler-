`timescale 1ns/1ps

module sync_debounce #(
  parameter int DEBOUNCE_COUNT = 200000  // adjust based on clk freq (e.g., 100 MHz)
)(
  input  logic clk,
  input  logic rst,        // active-high synchronous reset
  input  logic btn_async,  // raw pushbutton (asynchronous, bouncy)

  output logic btn_level,  // debounced stable level
  output logic btn_press_evt // 1-cycle pulse on rising edge of btn_level
);

  // 2-flop synchronizer
  logic btn_ff1, btn_ff2;
  always_ff @(posedge clk) begin
    if (rst) begin
      btn_ff1 <= 1'b0;
      btn_ff2 <= 1'b0;
    end else begin
      btn_ff1 <= btn_async;
      btn_ff2 <= btn_ff1;
    end
  end

  // Debounce: require DEBOUNCE_COUNT consecutive cycles of stability before updating btn_level
  localparam int DB_W = (DEBOUNCE_COUNT <= 1) ? 1 : $clog2(DEBOUNCE_COUNT);
  logic [DB_W-1:0] stable_cnt;
  logic last_sync;

  always_ff @(posedge clk) begin
    if (rst) begin
      btn_level  <= 1'b0;
      stable_cnt <= '0;
      last_sync  <= 1'b0;
    end else begin
      if (btn_ff2 == last_sync) begin
        // still stable, count up to DEBOUNCE_COUNT-1
        if (stable_cnt != DEBOUNCE_COUNT-1)
          stable_cnt <= stable_cnt + 1'b1;
      end else begin
        // changed -> restart stability counting
        stable_cnt <= '0;
        last_sync  <= btn_ff2;
      end

      // once stable long enough, accept new level
      if (stable_cnt == DEBOUNCE_COUNT-1) begin
        btn_level <= last_sync;
      end
    end
  end

  // rising-edge event pulse
  logic btn_level_d;
  always_ff @(posedge clk) begin
    if (rst) begin
      btn_level_d   <= 1'b0;
      btn_press_evt <= 1'b0;
    end else begin
      btn_press_evt <= (btn_level && !btn_level_d);
      btn_level_d   <= btn_level;
    end
  end

endmodule