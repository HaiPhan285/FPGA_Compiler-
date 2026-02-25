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
├── .tools/                 # Hidden toolchain (prjxray, db, env) - DO NOT TOUCH
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
Run the setup script once. This handles everything and hides the heavy tools in `.tools/` to keep your workspace clean.

```bash
# From f4pga/ directory
./setup-prjxray.sh
```

This script will:
- Install system packages.
- Clone `prjxray` into the hidden `.tools/` directory.
- Create a Python virtual environment in `.tools/env`.
- Download the database to `.tools/prjxray-db`.

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

### How to Create a New Project
1.  Go to the `app` folder: `cd fpga-project/app`
2.  Create a folder: `mkdir my_project`
3.  Add your Verilog source file (e.g., `my_design.v`) with a valid `module` declaration.
4.  Add a constraints file (e.g., `my_design.xdc`) with pin assignments.

**Important rules for new projects:**
-   **Do not leave files empty.** The build script will reject empty `.v` and `.xdc` files.
-   **Avoid Verilog reserved words as module names** (e.g., `xor`, `and`, `or`, `nor`, `nand`). Use names like `xor_gate`, `and_gate` instead.
-   **No spaces inside braces in XDC files.** `nextpnr-xilinx` will crash on `{ a }` — use `{a}` instead.
    ```
    # ✗ Wrong — causes assertion failure in nextpnr:
    set_property -dict { PACKAGE_PIN J15  IOSTANDARD LVCMOS33 } [get_ports { a }]

    # ✓ Correct:
    set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports {a}]
    # or:
    set_property PACKAGE_PIN J15 [get_ports {a}]
    set_property IOSTANDARD LVCMOS33 [get_ports {a}]
    ```
-   **The build script auto-detects the module name** from your Verilog source, so the filename does not need to match the module name.
-   **Helper files** (like `gates.v`) are automatically excluded from the top-module selection menu.

### How to Run (Build & Program)
We use a **clean build** process. No `build/` folders will clutter your project.

1.  **Navigate to the project root:**
    ```bash
    cd fpga-project
    ```

2.  **Run the build script:**
    ```bash
    ./build.sh
    ```
    *   Select your project from the list.
    *   It will build in a **temporary folder** (automatically deleted on success).
    *   If successful, it generates `my_project.bit` in your folder.

3.  **Flash to Board (Fast):**
    If you already built and just want to upload again:
    ```bash
    ./build.sh --flash
    ```

### Troubleshooting Common Errors

1.  **"Module `xor' not found!"** (or similar reserved word):
    - Your module name is a Verilog reserved keyword. Rename it (e.g., `xor` → `xor_gate`).

2.  **"Assertion failure: str.back() == '}'"** in nextpnr:
    - Your XDC file has spaces inside braces. Change `{ a }` to `{a}` and `{ PACKAGE_PIN ... }` to `{PACKAGE_PIN ...}`.

3.  **"All .sv/.v files are empty"** or **"No module declaration found"**:
    - Your Verilog source file is empty or missing a `module` declaration. Add your design code.

4.  **"port ... has no IOSTANDARD property"**:
    - Your XDC constraints are missing `IOSTANDARD` for one or more ports. Every port needs both `PACKAGE_PIN` and `IOSTANDARD`.

5.  **"Module `\xxx' referenced ... is not part of the design"**:
    - A submodule is missing. Make sure all instantiated modules have their source files in the project folder.

6.  **"Unable to read chipdb"**:
    - The chip database file is missing or corrupted.
    - Run the `wget` command in "Step 2" above to re-download it.

7.  **"python3: can't open file ... fasm2frames"**:
    - `prjxray-env.sh` was not sourced (the build script usually handles this).
    - Ensure `./setup-prjxray.sh` ran successfully.

8.  **Build Fails?**
    - The script will preserve the temporary build folder and tell you its path.
    - Go there to check `yosys.log` or `nextpnr.log` for error details.

## 5. Programming the FPGA

This project uses **OpenFPGALoader** because it natively supports the Nexys A7's built-in USB-JTAG interface (FTDI chip). You do **NOT** need an external programmer (like STLink) or complex tools (like OpenOCD) for standard bitstream loading.

### Why not OpenOCD or STLink?
- **STLink**: Typically for STM32 microcontrollers. Not used for Nexys A7.
- **OpenOCD**: Powerful but harder to configure. OpenFPGALoader is faster and easier for this board.
- **Vivado Hardware Manager**: Proprietary and huge. We are using a fully open-source flow.

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
