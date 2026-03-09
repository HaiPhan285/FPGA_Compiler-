## ================================
## Nexys A7-100T (XC7A100T-1CSG324C)
## fsm_traffic - Traffic Light FSM
## ================================

## Clock (100 MHz)
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Reset (CPU_RESET button, active low)
set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports rst_n]

## Pedestrian button (BTNC - center button)
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports ped_btn_async]

## Car lights -> LEDs LD0, LD1, LD2
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports car_g]
set_property -dict {PACKAGE_PIN K15 IOSTANDARD LVCMOS33} [get_ports car_y]
set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS33} [get_ports car_r]

## Pedestrian lights -> LEDs LD3, LD4
set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports ped_walk]
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports ped_dont]
