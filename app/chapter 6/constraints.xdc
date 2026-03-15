## =================== Clock ===================
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports {clk}]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports {clk}]

## =================== Reset ===================
set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports {rst}]

## =================== Pedestrian Request ===================
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports {ped_press_evt}]

## =================== Car Traffic Light ===================
set_property -dict {PACKAGE_PIN N15 IOSTANDARD LVCMOS33} [get_ports {CAR_G}]
set_property -dict {PACKAGE_PIN M16 IOSTANDARD LVCMOS33} [get_ports {CAR_Y}]
set_property -dict {PACKAGE_PIN R12 IOSTANDARD LVCMOS33} [get_ports {CAR_R}]

## =================== Pedestrian Signal ===================
set_property -dict {PACKAGE_PIN N16 IOSTANDARD LVCMOS33} [get_ports {PED_WALK}]
set_property -dict {PACKAGE_PIN R11 IOSTANDARD LVCMOS33} [get_ports {PED_DONT}]

## =================== Debug Output ===================
set_property -dict {PACKAGE_PIN G14 IOSTANDARD LVCMOS33} [get_ports {ped_req_latched}]
set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports {clk_1hz}]
