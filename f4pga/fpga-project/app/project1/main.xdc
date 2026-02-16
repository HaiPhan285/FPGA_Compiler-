## ================================
## Nexys A7-100T (XC7A100T-1CSG324C)
## full_adder W=8
## ================================

## ---- A[7:0] on SW[7:0] ----
set_property PACKAGE_PIN J15 [get_ports {A[0]}]
set_property PACKAGE_PIN L16 [get_ports {A[1]}]
set_property PACKAGE_PIN M13 [get_ports {A[2]}]
set_property PACKAGE_PIN R15 [get_ports {A[3]}]
set_property PACKAGE_PIN R17 [get_ports {A[4]}]
set_property PACKAGE_PIN T18 [get_ports {A[5]}]
set_property PACKAGE_PIN U18 [get_ports {A[6]}]
set_property PACKAGE_PIN R13 [get_ports {A[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {A[*]}]

## ---- B[7:0] on SW[15:8] ----
set_property PACKAGE_PIN T8  [get_ports {B[0]}]   ;# SW[8]
set_property PACKAGE_PIN U8  [get_ports {B[1]}]   ;# SW[9]
set_property PACKAGE_PIN R16 [get_ports {B[2]}]   ;# SW[10]
set_property PACKAGE_PIN T13 [get_ports {B[3]}]   ;# SW[11]
set_property PACKAGE_PIN H6  [get_ports {B[4]}]   ;# SW[12]
set_property PACKAGE_PIN U12 [get_ports {B[5]}]   ;# SW[13]
set_property PACKAGE_PIN U11 [get_ports {B[6]}]   ;# SW[14]
set_property PACKAGE_PIN V10 [get_ports {B[7]}]   ;# SW[15]
set_property IOSTANDARD LVCMOS33 [get_ports {B[*]}]

## ---- Control inputs ----
set_property PACKAGE_PIN N17 [get_ports sub]         ;# BTNC
set_property PACKAGE_PIN M18 [get_ports signed_mode] ;# BTNU
set_property IOSTANDARD LVCMOS33 [get_ports {sub signed_mode}]

## ---- Y[7:0] on LED[7:0] ----
set_property PACKAGE_PIN H17 [get_ports {Y[0]}]
set_property PACKAGE_PIN K15 [get_ports {Y[1]}]
set_property PACKAGE_PIN J13 [get_ports {Y[2]}]
set_property PACKAGE_PIN N14 [get_ports {Y[3]}]
set_property PACKAGE_PIN R18 [get_ports {Y[4]}]
set_property PACKAGE_PIN V17 [get_ports {Y[5]}]
set_property PACKAGE_PIN U17 [get_ports {Y[6]}]
set_property PACKAGE_PIN U16 [get_ports {Y[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {Y[*]}]

## ---- Flags on LED[11:8] ----
set_property PACKAGE_PIN V16 [get_ports carry_no_borrow]  ;# LED[8]
set_property PACKAGE_PIN T15 [get_ports overflow]         ;# LED[9]
set_property PACKAGE_PIN U14 [get_ports zero]             ;# LED[10]
set_property PACKAGE_PIN T16 [get_ports negative]         ;# LED[11]
