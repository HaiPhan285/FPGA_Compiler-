## =========================================================
## Nexys A7 constraints for:
##   input  clk_100mhz
##   input  rst        (mapped to BTNC)
##   output led        (mapped to LED0)
## =========================================================

## 100 MHz on-board oscillator
set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33 } [get_ports { clk }]
create_clock -add -name sys_clk -period 10.000 -waveform {0 5} [get_ports { clk }]

## Pushbutton: BTNC (use as active-high reset)
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports { rst }]

## LED0
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports { led }]