property p_illegal_state;
  @(posedge clk) disable iff (!rst_n)
    state_out inside {G, Y, R, W};
endproperty
assert property (p_illegal_state);

property p_car_mutual_exclusion;
  @(posedge clk) disable iff (!rst_n)
    !(car_g + car_y + car_r > 1);
endproperty
assert property (p_car_mutual_exclusion);

property p_ped_safety;
  @(posedge clk) disable iff (!rst_n)
    ped_walk |-> car_r;
endproperty
assert property (p_ped_safety);

property p_ped_mutual_exclusion;
  @(posedge clk) disable iff (!rst_n)
    !(ped_walk && ped_dont);
endproperty
assert property (p_ped_mutual_exclusion);

property p_min_green;
  @(posedge clk) disable iff (!rst_n)
    (state_out == G && $rose(state_out == G)) |-> ##[GREEN_COUNT-1] state_out == G;
endproperty
assert property (p_min_green);

property p_min_yellow;
  @(posedge clk) disable iff (!rst_n)
    (state_out == Y && $rose(state_out == Y)) |-> ##[YELLOW_COUNT-1] state_out == Y;
endproperty
assert property (p_min_yellow);

property p_min_red;
  @(posedge clk) disable iff (!rst_n)
    (state_out == R && $rose(state_out == R)) |-> ##[RED_COUNT-1] state_out == R;
endproperty
assert property (p_min_red);

property p_min_walk;
  @(posedge clk) disable iff (!rst_n)
    (state_out == W && $rose(state_out == W)) |-> ##[WALK_COUNT-1] state_out == W;
endproperty
assert property (p_min_walk);

property p_service_guarantee;
  @(posedge clk) disable iff (!rst_n)
    (ped_req_latched && state_out == R) |=> state_out == W;
endproperty
assert property (p_service_guarantee);