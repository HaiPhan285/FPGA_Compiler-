## SW0 -> a  (J15), SW1 -> b (L16), LED0 -> y (H17)
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports {a}]
set_property -dict {PACKAGE_PIN L16 IOSTANDARD LVCMOS33} [get_ports {b}]
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports {y}]