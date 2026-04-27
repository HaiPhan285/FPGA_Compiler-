## =========================================================
## Nexys A7 constraints for:
##   input  clk
##   input  rst        (mapped to BTNC)
##   output led        (mapped to LED0)
## =========================================================

## 100 MHz on-board oscillator
set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

## Pushbutton: BTNC (use as active-high reset)
set_property PACKAGE_PIN N17 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]

## LED0
set_property PACKAGE_PIN H17 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
