## Nexys A7-100T master constraints template
## Use this file by keeping the HDL top-level port names exactly as listed here.
## If a peripheral is unused, comment out its lines in your project copy.
##
## Recommended top-level names:
##   CLK100MHZ
##   sw[15:0]
##   LED[15:0]
##   BTNC, BTNU, BTNL, BTNR, BTND
##   seg[6:0], dp, an[7:0]
##   JA[1], JA[2], JA[3], JA[4], JA[7], JA[8], JA[9], JA[10]
##   JB[1], JB[2], JB[3], JB[4], JB[7], JB[8], JB[9], JB[10]
##   JC[1], JC[2], JC[3], JC[4], JC[7], JC[8], JC[9], JC[10]
##   JD[1], JD[2], JD[3], JD[4], JD[7], JD[8], JD[9], JD[10]
##   VGA_R[3:0], VGA_G[3:0], VGA_B[3:0], VGA_HS, VGA_VS

## Clock signal
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports { CLK100MHZ }]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { CLK100MHZ }]

## Switches
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports { sw[0] }]
set_property -dict { PACKAGE_PIN L16 IOSTANDARD LVCMOS33 } [get_ports { sw[1] }]
set_property -dict { PACKAGE_PIN M13 IOSTANDARD LVCMOS33 } [get_ports { sw[2] }]
set_property -dict { PACKAGE_PIN R15 IOSTANDARD LVCMOS33 } [get_ports { sw[3] }]
set_property -dict { PACKAGE_PIN R17 IOSTANDARD LVCMOS33 } [get_ports { sw[4] }]
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports { sw[5] }]
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports { sw[6] }]
set_property -dict { PACKAGE_PIN R13 IOSTANDARD LVCMOS33 } [get_ports { sw[7] }]
set_property -dict { PACKAGE_PIN T8 IOSTANDARD LVCMOS18 } [get_ports { sw[8] }]
set_property -dict { PACKAGE_PIN U8 IOSTANDARD LVCMOS18 } [get_ports { sw[9] }]
set_property -dict { PACKAGE_PIN R16 IOSTANDARD LVCMOS33 } [get_ports { sw[10] }]
set_property -dict { PACKAGE_PIN T13 IOSTANDARD LVCMOS33 } [get_ports { sw[11] }]
set_property -dict { PACKAGE_PIN H6 IOSTANDARD LVCMOS33 } [get_ports { sw[12] }]
set_property -dict { PACKAGE_PIN U12 IOSTANDARD LVCMOS33 } [get_ports { sw[13] }]
set_property -dict { PACKAGE_PIN U11 IOSTANDARD LVCMOS33 } [get_ports { sw[14] }]
set_property -dict { PACKAGE_PIN V10 IOSTANDARD LVCMOS33 } [get_ports { sw[15] }]

## LEDs
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports { LED[0] }]
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports { LED[1] }]
set_property -dict { PACKAGE_PIN J13 IOSTANDARD LVCMOS33 } [get_ports { LED[2] }]
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports { LED[3] }]
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports { LED[4] }]
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports { LED[5] }]
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports { LED[6] }]
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports { LED[7] }]
set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports { LED[8] }]
set_property -dict { PACKAGE_PIN T15 IOSTANDARD LVCMOS33 } [get_ports { LED[9] }]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports { LED[10] }]
set_property -dict { PACKAGE_PIN T16 IOSTANDARD LVCMOS33 } [get_ports { LED[11] }]
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports { LED[12] }]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports { LED[13] }]
set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports { LED[14] }]
set_property -dict { PACKAGE_PIN V11 IOSTANDARD LVCMOS33 } [get_ports { LED[15] }]

## RGB LEDs
set_property -dict { PACKAGE_PIN R12 IOSTANDARD LVCMOS33 } [get_ports { LED16_B }]
set_property -dict { PACKAGE_PIN M16 IOSTANDARD LVCMOS33 } [get_ports { LED16_G }]
set_property -dict { PACKAGE_PIN N15 IOSTANDARD LVCMOS33 } [get_ports { LED16_R }]
set_property -dict { PACKAGE_PIN G14 IOSTANDARD LVCMOS33 } [get_ports { LED17_B }]
set_property -dict { PACKAGE_PIN R11 IOSTANDARD LVCMOS33 } [get_ports { LED17_G }]
set_property -dict { PACKAGE_PIN N16 IOSTANDARD LVCMOS33 } [get_ports { LED17_R }]

## 7-segment display
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports { seg[0] }]
set_property -dict { PACKAGE_PIN R10 IOSTANDARD LVCMOS33 } [get_ports { seg[1] }]
set_property -dict { PACKAGE_PIN K16 IOSTANDARD LVCMOS33 } [get_ports { seg[2] }]
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 } [get_ports { seg[3] }]
set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports { seg[4] }]
set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports { seg[5] }]
set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS33 } [get_ports { seg[6] }]
set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33 } [get_ports { dp }]
set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports { an[0] }]
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports { an[1] }]
set_property -dict { PACKAGE_PIN T9 IOSTANDARD LVCMOS33 } [get_ports { an[2] }]
set_property -dict { PACKAGE_PIN J14 IOSTANDARD LVCMOS33 } [get_ports { an[3] }]
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports { an[4] }]
set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS33 } [get_ports { an[5] }]
set_property -dict { PACKAGE_PIN K2 IOSTANDARD LVCMOS33 } [get_ports { an[6] }]
set_property -dict { PACKAGE_PIN U13 IOSTANDARD LVCMOS33 } [get_ports { an[7] }]

## Buttons
set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports { CPU_RESETN }]
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports { BTNC }]
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports { BTNU }]
set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } [get_ports { BTNL }]
set_property -dict { PACKAGE_PIN M17 IOSTANDARD LVCMOS33 } [get_ports { BTNR }]
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports { BTND }]

## Pmod Header JA
set_property -dict { PACKAGE_PIN C17 IOSTANDARD LVCMOS33 } [get_ports { JA[1] }]
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports { JA[2] }]
set_property -dict { PACKAGE_PIN E18 IOSTANDARD LVCMOS33 } [get_ports { JA[3] }]
set_property -dict { PACKAGE_PIN G17 IOSTANDARD LVCMOS33 } [get_ports { JA[4] }]
set_property -dict { PACKAGE_PIN D17 IOSTANDARD LVCMOS33 } [get_ports { JA[7] }]
set_property -dict { PACKAGE_PIN E17 IOSTANDARD LVCMOS33 } [get_ports { JA[8] }]
set_property -dict { PACKAGE_PIN F18 IOSTANDARD LVCMOS33 } [get_ports { JA[9] }]
set_property -dict { PACKAGE_PIN G18 IOSTANDARD LVCMOS33 } [get_ports { JA[10] }]

## Pmod Header JB
set_property -dict { PACKAGE_PIN D14 IOSTANDARD LVCMOS33 } [get_ports { JB[1] }]
set_property -dict { PACKAGE_PIN F16 IOSTANDARD LVCMOS33 } [get_ports { JB[2] }]
set_property -dict { PACKAGE_PIN G16 IOSTANDARD LVCMOS33 } [get_ports { JB[3] }]
set_property -dict { PACKAGE_PIN H14 IOSTANDARD LVCMOS33 } [get_ports { JB[4] }]
set_property -dict { PACKAGE_PIN E16 IOSTANDARD LVCMOS33 } [get_ports { JB[7] }]
set_property -dict { PACKAGE_PIN F13 IOSTANDARD LVCMOS33 } [get_ports { JB[8] }]
set_property -dict { PACKAGE_PIN G13 IOSTANDARD LVCMOS33 } [get_ports { JB[9] }]
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports { JB[10] }]

## Pmod Header JC
set_property -dict { PACKAGE_PIN K1 IOSTANDARD LVCMOS33 } [get_ports { JC[1] }]
set_property -dict { PACKAGE_PIN F6 IOSTANDARD LVCMOS33 } [get_ports { JC[2] }]
set_property -dict { PACKAGE_PIN J2 IOSTANDARD LVCMOS33 } [get_ports { JC[3] }]
set_property -dict { PACKAGE_PIN G6 IOSTANDARD LVCMOS33 } [get_ports { JC[4] }]
set_property -dict { PACKAGE_PIN E7 IOSTANDARD LVCMOS33 } [get_ports { JC[7] }]
set_property -dict { PACKAGE_PIN J3 IOSTANDARD LVCMOS33 } [get_ports { JC[8] }]
set_property -dict { PACKAGE_PIN J4 IOSTANDARD LVCMOS33 } [get_ports { JC[9] }]
set_property -dict { PACKAGE_PIN E6 IOSTANDARD LVCMOS33 } [get_ports { JC[10] }]

## Pmod Header JD
set_property -dict { PACKAGE_PIN H4 IOSTANDARD LVCMOS33 } [get_ports { JD[1] }]
set_property -dict { PACKAGE_PIN H1 IOSTANDARD LVCMOS33 } [get_ports { JD[2] }]
set_property -dict { PACKAGE_PIN G1 IOSTANDARD LVCMOS33 } [get_ports { JD[3] }]
set_property -dict { PACKAGE_PIN G3 IOSTANDARD LVCMOS33 } [get_ports { JD[4] }]
set_property -dict { PACKAGE_PIN H2 IOSTANDARD LVCMOS33 } [get_ports { JD[7] }]
set_property -dict { PACKAGE_PIN G4 IOSTANDARD LVCMOS33 } [get_ports { JD[8] }]
set_property -dict { PACKAGE_PIN G2 IOSTANDARD LVCMOS33 } [get_ports { JD[9] }]
set_property -dict { PACKAGE_PIN F3 IOSTANDARD LVCMOS33 } [get_ports { JD[10] }]

## Pmod Header JXADC
set_property -dict { PACKAGE_PIN A14 IOSTANDARD LVCMOS33 } [get_ports { vauxn3 }]
set_property -dict { PACKAGE_PIN A13 IOSTANDARD LVCMOS33 } [get_ports { vauxp3 }]
set_property -dict { PACKAGE_PIN A16 IOSTANDARD LVCMOS33 } [get_ports { vauxn10 }]
set_property -dict { PACKAGE_PIN A15 IOSTANDARD LVCMOS33 } [get_ports { vauxp10 }]
set_property -dict { PACKAGE_PIN B17 IOSTANDARD LVCMOS33 } [get_ports { vauxn2 }]
set_property -dict { PACKAGE_PIN B16 IOSTANDARD LVCMOS33 } [get_ports { vauxp2 }]
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports { vauxn11 }]
set_property -dict { PACKAGE_PIN B18 IOSTANDARD LVCMOS33 } [get_ports { vauxp11 }]

## VGA Connector
set_property -dict { PACKAGE_PIN A3 IOSTANDARD LVCMOS33 } [get_ports { VGA_R[0] }]
set_property -dict { PACKAGE_PIN B4 IOSTANDARD LVCMOS33 } [get_ports { VGA_R[1] }]
set_property -dict { PACKAGE_PIN C5 IOSTANDARD LVCMOS33 } [get_ports { VGA_R[2] }]
set_property -dict { PACKAGE_PIN A4 IOSTANDARD LVCMOS33 } [get_ports { VGA_R[3] }]
set_property -dict { PACKAGE_PIN C6 IOSTANDARD LVCMOS33 } [get_ports { VGA_G[0] }]
set_property -dict { PACKAGE_PIN A5 IOSTANDARD LVCMOS33 } [get_ports { VGA_G[1] }]
set_property -dict { PACKAGE_PIN B6 IOSTANDARD LVCMOS33 } [get_ports { VGA_G[2] }]
set_property -dict { PACKAGE_PIN A6 IOSTANDARD LVCMOS33 } [get_ports { VGA_G[3] }]
set_property -dict { PACKAGE_PIN B7 IOSTANDARD LVCMOS33 } [get_ports { VGA_B[0] }]
set_property -dict { PACKAGE_PIN C7 IOSTANDARD LVCMOS33 } [get_ports { VGA_B[1] }]
set_property -dict { PACKAGE_PIN D7 IOSTANDARD LVCMOS33 } [get_ports { VGA_B[2] }]
set_property -dict { PACKAGE_PIN D8 IOSTANDARD LVCMOS33 } [get_ports { VGA_B[3] }]
set_property -dict { PACKAGE_PIN B11 IOSTANDARD LVCMOS33 } [get_ports { VGA_HS }]
set_property -dict { PACKAGE_PIN B12 IOSTANDARD LVCMOS33 } [get_ports { VGA_VS }]
