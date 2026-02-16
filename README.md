# FPGA_Compiler

Open-Source FPGA Build & Programming Flow
Target Board: **Nexys A7-100T (XC7A100T-CSG324)**

---

## Overview

This repository provides a complete open-source FPGA workflow for building and programming designs on the **Nexys A7-100T** using the F4PGA toolchain.

The flow replaces proprietary vendor tools with a fully open-source stack consisting of synthesis, place & route, bitstream generation, and device programming.

---

# Toolchain Architecture

## 1. Yosys — Synthesis

Repository: [https://github.com/YosysHQ/yosys](https://github.com/YosysHQ/yosys)

* Converts Verilog/SystemVerilog into a gate-level netlist
* Maps logic to FPGA primitives (LUTs, Flip-Flops, BRAM, DSP, etc.)
* Outputs JSON netlist for nextpnr

---

## 2. Nextpnr — Place & Route

Repository: [https://github.com/YosysHQ/nextpnr](https://github.com/YosysHQ/nextpnr)

* Places logic elements onto FPGA fabric
* Routes interconnections
* Uses FPGA architecture database (chipdb)
* Outputs FASM representation

---

## 3. Project X-Ray (prjxray) — Bitstream Generation

Repository: [https://github.com/f4pga/prjxray](https://github.com/f4pga/prjxray)

* Converts FASM into FPGA configuration frames
* Tools used:

  * fasm2frames
  * xc7frames2bit
* Produces final `.bit` bitstream

---

## 4. OpenFPGALoader — Programming

Repository: [https://github.com/OpenFPGA/openFPGALoader](https://github.com/OpenFPGA/openFPGALoader)

* Open-source JTAG programmer
* Programs FPGA over USB
* Supports Nexys A7 board

---

# VSCode Integration

Open Command Palette:

```
Ctrl + Shift + P
```

Available tasks:

* FPGA: Build
* FPGA: Program
* FPGA: Build & Program
* FPGA: Clean

---

# Terminal Usage

## USB Pass-Through (WSL Users)

Run PowerShell as Administrator:

```
usbipd attach --wsl --busid 1-2
```

---

## Build Project

Initialize environment:

```
source /home/user/f4pga/prjxray-env.sh
```

Navigate to project directory:

```
cd /home/user/f4pga/fpga-project
```

Build default project:

```
./build.sh
```

---

### Build Specific Project

```
./build.sh \
  --source-dir app/project1 \
  --top <top_module_name> \
  --project run \
  --constraints <constraint_file.xdc>
```

---

## Program FPGA

```
openFPGALoader -b nexys_a7_100 test.bit
```

---

# Project Structure

```
f4pga/
 ├── fpga-project/
 │   ├── app/
 │   │   ├── project1/
 │   │   ├── project2/
 │   ├── build.sh
 ├── prjxray/
 ├── prjxray-db/
 ├── prjxray-env.sh
 ├── setup-prjxray.sh
```

---

# Target Device

* Board: Digilent Nexys A7-100T
* FPGA: XC7A100T-CSG324
* Architecture: Xilinx 7-Series

---

# Features

* Fully open-source FPGA toolchain
* VSCode task integration
* Customizable build script
* WSL compatible
* Direct JTAG programming

---

# Notes

* Ensure `prjxray-env.sh` is sourced before building.
* USB must be attached to WSL before programming.
* Generated `.bit` files are located in the build directory.
* Clean builds are recommended when switching projects.

---

# License

Specify your preferred license (MIT, Apache 2.0, etc.) here.
