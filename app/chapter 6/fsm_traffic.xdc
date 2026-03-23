## =================== Clock ===================
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports {clk}]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports {clk}]

## =================== Reset ===================
set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports {rst}]

## =================== Pedestrian Request ===================
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports {ped_req_evt}]

## =================== Car Traffic Light ===================
set_property -dict {PACKAGE_PIN N15 IOSTANDARD LVCMOS33} [get_ports {car_g}]
set_property -dict {PACKAGE_PIN M16 IOSTANDARD LVCMOS33} [get_ports {car_y}]
set_property -dict {PACKAGE_PIN R12 IOSTANDARD LVCMOS33} [get_ports {car_r}]

## =================== Pedestrian Signal ===================
set_property -dict {PACKAGE_PIN N16 IOSTANDARD LVCMOS33} [get_ports {ped_walk}]
set_property -dict {PACKAGE_PIN R11 IOSTANDARD LVCMOS33} [get_ports {ped_dont}]

## =================== Debug Output ===================
set_property -dict {PACKAGE_PIN G14 IOSTANDARD LVCMOS33} [get_ports {state_out[0]}]
set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports {state_out[1]}]
