`timescale 1ns/1ps

module tb_top;

  logic clk;
  logic rst;
  logic ped_press_evt;

  logic CAR_G, CAR_Y, CAR_R;
  logic PED_WALK, PED_DONT;
  logic ped_req_latched;
  logic clk_1hz;

  top #(
    .SIM_MODE(1)
  ) dut (
    .clk(clk),
    .rst(rst),
    .ped_press_evt(ped_press_evt),
    .CAR_G(CAR_G),
    .CAR_Y(CAR_Y),
    .CAR_R(CAR_R),
    .PED_WALK(PED_WALK),
    .PED_DONT(PED_DONT),
    .ped_req_latched(ped_req_latched),
    .clk_1hz(clk_1hz)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
  end

  task automatic wait_cycles(input int n);
    for (int i = 0; i < n; i++) @(posedge clk);
  endtask

  initial begin
    rst = 1'b1;
    ped_press_evt = 1'b0;
    wait_cycles(10);
    rst = 1'b0;
    wait_cycles(10);

    $display("Testing traffic light FSM...");
    $display("Green=%b Yellow=%b Red=%b Walk=%b Dont=%b", CAR_G, CAR_Y, CAR_R, PED_WALK, PED_DONT);

    wait_cycles(50);

    $display("Testing pedestrian request...");
    ped_press_evt = 1'b1;
    wait_cycles(1);
    ped_press_evt = 1'b0;

    wait_cycles(100);

    $display("Green=%b Yellow=%b Red=%b Walk=%b Dont=%b", CAR_G, CAR_Y, CAR_R, PED_WALK, PED_DONT);

    $display("TEST PASSED");
    $finish;
  end

endmodule
