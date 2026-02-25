# FPGA Compiler

An open-source FPGA build system for the **Nexys A7-100T (XC7A100T-CSG324)**. No Vivado required.

## What This Does

Takes your Verilog/SystemVerilog design and produces a `.bit` file you can flash to the board — using only free, open-source tools:

| Step | Tool | What it does |
|------|------|-------------|
| Synthesis | **Yosys** | Verilog → Netlist (maps to LUTs, FFs, etc.) |
| Place & Route | **Nextpnr-Xilinx** | Netlist → FASM (places and connects everything) |
| Bitstream | **Project X-Ray** | FASM → `.bit` file (via `fasm2frames` + `xc7frames2bit`) |
| Program | **OpenFPGALoader** | Flashes `.bit` to the FPGA over USB-JTAG |

## Directory Structure

```
FPGA_Compiler-/
├── setup-prjxray.sh        # One-time setup script (run this first)
├── prjxray-env.sh          # Environment config (sourced automatically by build.sh)
├── .tools/                 # Toolchain internals (auto-populated by setup) — DO NOT EDIT
│   ├── prjxray/            # Project X-Ray (cloned from f4pga/prjxray)
│   ├── prjxray-db/         # FPGA tile database (cloned from f4pga/prjxray-db)
│   └── env/                # Python virtual environment
└── fpga-project/
    ├── build.sh            # Main build script
    └── app/                # Your designs go here
        ├── project1/       #   Each folder = one project
        │   ├── main.sv     #     Verilog/SystemVerilog source(s)
        │   └── main.xdc    #     Pin constraints
        ├── project2/
        └── project3/
```

## Quick Start

### 1. Prerequisites

You need **Linux** (Ubuntu/Debian) or **WSL2** on Windows.

Install these system tools first:

```bash
sudo apt-get update
sudo apt-get install -y \
    build-essential cmake python3 python3-pip python3-venv git \
    libboost-all-dev libyaml-cpp-dev libffi-dev libssl-dev \
    yosys nextpnr-xilinx openFPGALoader
```

### 2. Run Setup

From the repository root:

```bash
./setup-prjxray.sh
```

This will:
- Clone **prjxray** and build its C++ tools (`xc7frames2bit`, etc.)
- Clone the **prjxray-db** database for the Artix-7
- Create a Python virtual environment and install dependencies
- Download the **chipdb** for nextpnr-xilinx

> **Note:** If the setup fails partway through (e.g., network issue), the `.tools/prjxray/` directory may exist but be empty or incomplete. Delete it and re-run:
> ```bash
> rm -rf .tools/prjxray
> ./setup-prjxray.sh
> ```

### 3. Download Chipdb (if not done by setup)

Nextpnr-Xilinx needs a chip database file. If the setup script didn't download it, do it manually:

```bash
mkdir -p ~/.local/share/nextpnr/xilinx
wget -O ~/.local/share/nextpnr/xilinx/chipdb-xc7a100t.bin \
    https://github.com/openXC7/nextpnr-xilinx/releases/download/release-0.5.0/chipdb-xc7a100t.bin
```

### 4. Build a Project

```bash
cd fpga-project
./build.sh
```

You'll see an interactive menu:
```
=== Select a project ===
  [1] project1
  [2] project2
  [3] project3
  [a] Build all
Enter number:
```

Pick a project. If it has multiple source files, you'll be asked which one is the top module. The build runs in a temporary directory and produces a `.bit` file in your project folder.

#### CLI Options

You can also skip the interactive menu:

```bash
./build.sh --project myproj --top top --constraints top.xdc --source-dir app/project3
./build.sh --all          # Build every project in app/
./build.sh --flash        # Pick a built project and flash it to the board
```

## Creating a New Project

1. Create a folder under `fpga-project/app/`:
   ```bash
   mkdir fpga-project/app/my_project
   ```

2. Add your **Verilog source** (`.v` or `.sv`) with a `module` declaration.

3. Add a **constraints file** (`.xdc`) with pin and I/O standard assignments.

4. Run `./build.sh` and select your project.

### Rules to Follow

- **Don't leave files empty** — the build script rejects empty `.v`/`.sv` and `.xdc` files.
- **Don't use Verilog reserved words as module names** (`xor`, `and`, `or`, etc.). Use `xor_gate`, `and_gate` instead.
- **No spaces inside braces in XDC files** — `nextpnr-xilinx` crashes on `{ a }`. Use `{a}`:
  ```tcl
  # ✗ WRONG — causes assertion failure:
  set_property -dict { PACKAGE_PIN J15  IOSTANDARD LVCMOS33 } [get_ports { a }]

  # ✓ CORRECT:
  set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports {a}]
  ```
- **Every port needs both `PACKAGE_PIN` and `IOSTANDARD`** in the XDC.
- **Multi-file projects**: put all source files in the same folder. The build script auto-detects them and asks you to pick the top module.

## Programming the FPGA

This project uses **OpenFPGALoader** — it supports the Nexys A7's built-in USB-JTAG (FTDI) directly. No external programmer needed.

### Verify Connection

```bash
openFPGALoader --detect
```

### Flash the Bitstream

```bash
openFPGALoader -b nexys_a7_100 fpga-project/app/project1/run.bit
```

Or use the built-in flash command:

```bash
cd fpga-project && ./build.sh --flash
```

### WSL Users

You must pass the USB device through to WSL first. In **PowerShell (Admin)**:

```powershell
usbipd list
usbipd attach --wsl --busid <BUSID>
```

Then run `openFPGALoader --detect` in WSL to confirm.

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `fasm2frames not found` | prjxray not set up or `.tools/prjxray` is empty | Delete `.tools/prjxray` and re-run `./setup-prjxray.sh` |
| `xc7frames2bit not found` | prjxray C++ tools not built | Run `cd .tools/prjxray && make build` |
| `Module 'xor' not found` | Module name is a Verilog reserved word | Rename to `xor_gate`, etc. |
| `Assertion failure: str.back() == '}'` | Spaces inside braces in `.xdc` | Change `{ a }` to `{a}` |
| `All .sv/.v files are empty` | Source file has no `module` declaration | Add your design code |
| `port has no IOSTANDARD` | Missing I/O standard in constraints | Add `IOSTANDARD LVCMOS33` for each port |
| `Unable to read chipdb` | chipdb file missing | Download it (see Step 3 above) |
| `unable to open ftdi device` | USB not connected or no permissions | Check `lsusb`, add udev rules, or `usbipd attach` (WSL) |
| Build fails with no clear error | — | Check `yosys.log` / `nextpnr.log` in the temp build dir (path is printed on failure) |
