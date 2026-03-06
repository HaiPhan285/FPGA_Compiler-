## ================================
## Nexys A7-100T (XC7A100T-1CSG324C)
## full_adder W=8
## ================================

## ---- A[7:0] on SW[7:0] ----
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports {A[0]}]
set_property -dict {PACKAGE_PIN L16 IOSTANDARD LVCMOS33} [get_ports {A[1]}]
set_property -dict {PACKAGE_PIN M13 IOSTANDARD LVCMOS33} [get_ports {A[2]}]
set_property -dict {PACKAGE_PIN R15 IOSTANDARD LVCMOS33} [get_ports {A[3]}]
set_property -dict {PACKAGE_PIN R17 IOSTANDARD LVCMOS33} [get_ports {A[4]}]
set_property -dict {PACKAGE_PIN T18 IOSTANDARD LVCMOS33} [get_ports {A[5]}]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports {A[6]}]
set_property -dict {PACKAGE_PIN R13 IOSTANDARD LVCMOS33} [get_ports {A[7]}]

## ---- B[7:0] on SW[15:8] ----
set_property -dict {PACKAGE_PIN T8 IOSTANDARD LVCMOS33} [get_ports {B[0]}]
set_property -dict {PACKAGE_PIN U8 IOSTANDARD LVCMOS33} [get_ports {B[1]}]
set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports {B[2]}]
set_property -dict {PACKAGE_PIN T13 IOSTANDARD LVCMOS33} [get_ports {B[3]}]
set_property -dict {PACKAGE_PIN H6 IOSTANDARD LVCMOS33} [get_ports {B[4]}]
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports {B[5]}]
set_property -dict {PACKAGE_PIN U11 IOSTANDARD LVCMOS33} [get_ports {B[6]}]
set_property -dict {PACKAGE_PIN V10 IOSTANDARD LVCMOS33} [get_ports {B[7]}]

## ---- Control inputs ----
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports sub]
set_property -dict {PACKAGE_PIN M18 IOSTANDARD LVCMOS33} [get_ports signed_mode]

## ---- Y[7:0] on LED[7:0] ----
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports {Y[0]}]
set_property -dict {PACKAGE_PIN K15 IOSTANDARD LVCMOS33} [get_ports {Y[1]}]
set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS33} [get_ports {Y[2]}]
set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports {Y[3]}]
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {Y[4]}]
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports {Y[5]}]
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports {Y[6]}]
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports {Y[7]}]

## ---- Flags on LED[11:8] ----
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports carry_no_borrow]
set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS33} [get_ports overflow]
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports zero]
set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS33} [get_ports negative]
