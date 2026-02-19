# FPGA Project Setup & Toolchain Guide

This repository provides a complete open-source FPGA workflow for building and programming designs on the **Nexys A7-100T (XC7A100T-CSG324)** using the F4PGA toolchain.

## 1. Overview

The flow replaces proprietary vendor tools with a fully open-source stack consisting of:
1.  **Yosys** – Synthesis (Verilog → Netlist)
2.  **Nextpnr** – Place & Route (Netlist → FASM)
3.  **Project X-Ray** – Bitstream Generation (FASM → Bitstream)
4.  **OpenFPGALoader** – Device Programming

## 2. Directory Structure

```
f4pga/
├── prjxray/                # Submodule or cloned prjxray repo
├── prjxray-db/             # Database for Xilinx 7-series
├── prjxray-env.sh          # Environment variables script
├── setup-prjxray.sh        # Installation script
└── fpga-project/           # Project directory
    ├── build.sh            # Main build script
    └── app/                # Application designs
        └── project1/       # Example project
            ├── main.sv     # Verilog source
            └── main.xdc    # Constraints file
```

## 3. Requirements & Installation

You need a Linux environment (Ubuntu/Debian recommended or WSL2).

### Step 1: Install Dependencies
Run the setup script to install system dependencies, Python packages, and download the device database.

```bash
# From f4pga/ directory
./setup-prjxray.sh
```

This script will:
- Install packages like `yosys`, `git`, `python3`, etc.
- Clone `prjxray`.
- Create a Python virtual environment.
- Download the Artix-7 database.

### Step 2: Install Nextpnr-Xilinx & OpenFPGALoader
The place-and-route tool and programmer must be installed.

```bash
# Example for Ubuntu
sudo apt-get install nextpnr-xilinx openFPGALoader
```

**Crucial Step:** You must have the chip database (`chipdb`) for the XC7A100T.
If `nextpnr-xilinx` cannot find it (or if you get an error), download it manually:

```bash
mkdir -p ~/.local/share/nextpnr/xilinx
wget https://github.com/openXC7/nextpnr-xilinx/releases/download/release-0.5.0/chipdb-xc7a100t.bin -O ~/.local/share/nextpnr/xilinx/chipdb-xc7a100t.bin
```

## 4. Building a Project

### Step 1: Load Environment
**Always** source the environment script before building. This sets up paths for `fasm2frames` and other tools.

```bash
source prjxray-env.sh
```

### Step 2: Run Build Script
Navigate to the project folder and run the build script.

```bash
cd fpga-project
./build.sh --source-dir app/project1 --top main --project run --constraints main.xdc
```

**VSCode Shortcuts (Ctrl+Shift+P):**
- `FPGA: Build`
- `FPGA: Program`
- `FPGA: Build & Program`

### Troubleshooting Common Errors

1.  **"Unable to read chipdb"**:
    - The chip database file is missing or corrupted.
    - Run the `wget` command in "Step 2" above to re-download it.

2.  **"python3: can't open file ... fasm2frames"**:
    - `prjxray-env.sh` was not sourced, or `prjxray` directory is missing.
    - Ensure `./setup-prjxray.sh` ran successfully.
    - **Run `source ../prjxray-env.sh`** before building.

3.  **"Unable to import fast Antlr4 parser"**:
    - This is a warning, not an error. The build will proceed using the slower Python parser.

## 5. Programming the FPGA

### 1. Verify Device Connection
First, check if your FPGA is detected:
```bash
openFPGALoader --detect
```
*(You should see "Jtag frequency..." and device details)*

### 2. USB Pass-Through (WSL Users Only)
If you are on Windows using WSL, you must attach the USB device first.
Run **PowerShell as Administrator**:
```powershell
usbipd list
usbipd attach --wsl --busid <BUSID>
```

### 3. Program the Bitstream
Load the generated `.bit` file to the FPGA:

```bash
openFPGALoader -b nexys_a7_100 run.bit
```

### Troubleshooting Programming
- **"unable to open ftdi device"**: Device not connected or permission denied.
  - Linux: Check `lsusb`. You might need udev rules.
  - WSL: Forgot to run `usbipd attach`.
- **"Device not found"**: Board is not powered on or cable is bad.

## 6. Toolchain Architecture Details

-   **Yosys**: Maps your design to FPGA primitives (LUTs, FFs, etc.).
-   **Nextpnr**: Places design elements and routes connections using the `chipdb`.
-   **Prjxray**: Converts the design into a programming bitstream (`.bit`) using `fasm2frames` and `xc7frames2bit`.
-   **OpenFPGALoader**: Open-source JTAG programmer.
