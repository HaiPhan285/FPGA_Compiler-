`timescale 1ns/1ps

module button_sync (
    input clk,
    input rst,
    input btn_raw,
    output btn_raw_sync
);

reg btn_meta, btn_sync;

always @(posedge clk) begin
    if (rst) begin
        btn_meta <= 0;
        btn_sync <= 0;
    end
    else begin
        btn_meta <= btn_raw;
        btn_sync <= btn_meta;
    end
end

assign btn_raw_sync = btn_sync;

endmodule