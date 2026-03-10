# FPGA Compiler

An open-source FPGA build system for the **Nexys A7-100T (XC7A100T-CSG324)**. No Vivado required.

Takes your Verilog/SystemVerilog design and produces a `.bit` file you can flash to the board — using only free, open-source tools:

| Step | Tool | What it does |
|------|------|-------------|
| Synthesis | **Yosys** | Verilog → Netlist |
| Place & Route | **nextpnr-xilinx** | Netlist → FASM |
| Bitstream | **Project X-Ray** | FASM → `.bit` file |
| Program | **OpenFPGALoader** | Flashes `.bit` to FPGA over USB-JTAG |

---

## ⚡ TL;DR — get building in 3 steps

```bash
git clone https://github.com/HaiPhan285/FPGA_Compiler-.git
cd FPGA_Compiler-
chmod +x setup.sh && ./setup.sh   # one-time setup (~5 min, needs internet)
./build.sh                         # interactive menu to pick & build a project
```

> **Requirements:** Linux (Ubuntu 22.04/24.04) or WSL2. `sudo` access needed for `setup.sh`.

---

## Repository layout

```
FPGA_Compiler-/
├── setup.sh          ← run this ONCE after cloning (installs all tools)
├── prjxray-env.sh    ← auto-sourced by build.sh (do not edit)
├── build.sh          ← interactive build menu
├── app/              ← your designs live here
│   ├── project1/     ←   each sub-folder is one project
│   ├── project2/
│   ├── project3/
│   ├── project5/
│   └── chapter 6/
└── .tools/           ← auto-populated by setup.sh (gitignored)
```

Each project folder must contain:
- At least one `.sv` or `.v` source file with a `module` declaration
- At least one `.xdc` constraints file mapping ports to physical pins

---

## Quick start

### 1 — System requirements

You need **Linux** (Ubuntu 22.04 / 24.04 recommended) or **WSL2** on Windows.

`setup.sh` installs everything automatically. If you prefer to install tools manually first, here are the individual steps:

#### 1a. Base build tools

```bash
sudo apt-get update
sudo apt-get install -y \
    build-essential cmake make git wget curl \
    python3 python3-pip python3-venv \
    libffi-dev libssl-dev \
    libboost-all-dev libyaml-cpp-dev \
    flex bison clang-format \
    libftdi1-2 libhidapi-hidraw0 libusb-1.0-0
```

#### 1b. Yosys (synthesis)

```bash
sudo apt-get install -y yosys
```

Verify: `yosys --version`

#### 1c. nextpnr-xilinx (place-and-route)

nextpnr-xilinx is **not** available as pre-built binaries anymore. The recommended way to install is via snap:

```bash
# Option A — snap (recommended for Ubuntu 22.04/24.04)
# First, install snap if you don't have it:
sudo apt-get install -y snapd

# Install the openXC7 toolchain (includes nextpnr-xilinx, yosys, fasm2frames, xc7frames2bit)
sudo snap install --classic --dangerous openxc7_0.8.2_amd64.snap

# Or use the installer script:
wget -qO - https://raw.githubusercontent.com/openXC7/toolchain-installer/main/toolchain-installer.sh | bash

# Create aliases for the tools
sudo snap alias openxc7.nextpnr-xilinx nextpnr-xilinx
sudo snap alias openxc7.fasm2frames fasm2frames
sudo snap alias openxc7.xc7frames2bit xc7frames2bit

# Option B — build from source (takes ~30 min)
# See: https://github.com/openXC7/nextpnr-xilinx
```

Verify: `nextpnr-xilinx --version`

#### 1d. OpenFPGALoader (flashing — skip if you only want to build)

```bash
sudo apt-get install -y openfpgaloader
```

If not available in apt, build from source: <https://github.com/trabucayre/openFPGALoader>

---

### 2 — Clone & setup

```bash
git clone https://github.com/HaiPhan285/FPGA_Compiler-.git
cd FPGA_Compiler-
chmod +x setup.sh
./setup.sh
```

`setup.sh` does the following automatically:

1. Installs any missing system packages
2. Installs **yosys** (synthesis), **nextpnr-xilinx** (place-and-route via snap), **openFPGALoader** (flash)
3. Clones **prjxray** and builds its C++ tools (`xc7frames2bit`, `bitread`, …)
4. Clones the **prjxray-db** Artix-7 tile database
5. Creates a Python virtual environment (`.tools/env`) and installs Python deps
6. Sets up the **chipdb** for nextpnr-xilinx (bundled in snap package)

Setup takes ~5 minutes on a good connection. Run it only once.

> **If setup fails partway through** (network issue, etc.), delete the incomplete directory and re-run:
> ```bash
> rm -rf .tools/prjxray .tools/prjxray-db .tools/env
> ./setup.sh
> ```

---

### 3 — Build a project

```bash
./build.sh
```

You will see an interactive menu:

```
=== Select a project ===
  [1] project1
  [2] project2
  [3] project3
  [4] project5
  [a] Build all
Enter number:
```

Select a project number. If the folder has multiple source files, you will be asked to pick the **top module** file. The script auto-detects the module name, runs synthesis → place-and-route → bitstream generation, and writes `<project_name>.bit` into the project folder.

#### CLI options (skip the menu)

```bash
# Build a specific project
./build.sh --project project5 --top and_gate --constraints and_gate.xdc --source-dir app/project5

# Build all projects
./build.sh --all

# Flash a previously built bitstream
./build.sh --flash
```

---

### 4 — Flash to the FPGA

Connect the Nexys A7 via USB, then:

```bash
./build.sh --flash
```

Or flash a specific `.bit` directly:

```bash
openFPGALoader -b nexys_a7_100 app/project5/project5.bit
```

Verify the board is detected first:

```bash
openFPGALoader --detect
```

#### WSL2 users — pass USB through to WSL

In **PowerShell (as Administrator)**:

```powershell
usbipd list
usbipd attach --wsl --busid <BUSID>
```

Then confirm inside WSL:

```bash
openFPGALoader --detect
```

---

## Creating your own project

1. Create a folder under `app/`:

   ```bash
   mkdir app/my_project
   ```

2. Add a **Verilog source** (`.v` or `.sv`) file with a `module` declaration.

3. Add a **constraints file** (`.xdc`) that maps every port to a physical pin:

   ```tcl
   set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports {sw[0]}]
   ```

4. Run `./build.sh` and select your project.

### Constraints file rules

- **No spaces inside braces** — `nextpnr-xilinx` crashes on `{ a }`. Always write `{a}`:

  ```tcl
  # ✗ WRONG
  set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports { a }]

  # ✓ CORRECT
  set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports {a}]
  ```

- Every port needs both `PACKAGE_PIN` and `IOSTANDARD`.
- Don't use Verilog reserved words as module names (`xor`, `and`, `or`, …). Use `xor_gate`, `and_gate`, etc.

### Nexys A7-100T pin reference

| Signal | Package Pin | Notes |
|--------|-------------|-------|
| SW0–SW15 | J15, L16, M13, R15, R17, T18, U18, R13, T8, U8, R16, T13, H6, U12, U11, V10 | Slide switches |
| BTN0–BTN4 | N17, M18, P17, M17 | Push buttons (active-high) |
| LED0–LED15 | H17, K15, J13, N14, R18, V17, U17, U16, V16, T15, U14, T16, V15, V14, V12, V11 | LEDs |
| CLK (100 MHz) | E3 | Main system clock |

---

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `fasm2frames not found` | prjxray not set up | Re-run `./setup.sh` |
| `xc7frames2bit not found` | prjxray C++ tools not built | `cd .tools/prjxray && cmake --build build` |
| `nextpnr-xilinx: command not found` | Tool not installed correctly | Run: `wget -qO - https://raw.githubusercontent.com/openXC7/toolchain-installer/main/toolchain-installer.sh \| bash` |
| `Unable to read chipdb` | chipdb missing | Should be bundled in snap; try reinstalling: `sudo snap install --classic --dangerous $(ls openxc7_*.snap)` |
| `Assertion failure: str.back() == '}'` | Spaces inside XDC braces | Change `{ a }` → `{a}` |
| `Module 'xor' not found` | Reserved word used as module name | Rename module to `xor_gate` |
| `All .sv/.v files are empty` | Source file has no `module` declaration | Add your design code |
| `port has no IOSTANDARD` | Missing I/O standard in constraints | Add `IOSTANDARD LVCMOS33` for each port |
| `unable to open ftdi device` | USB not connected or permissions issue | Check `lsusb`; run `sudo openFPGALoader --detect`; or use `usbipd attach` on WSL |
| Build fails silently | General error | Check `build/yosys.log` and `build/nextpnr.log` in your project's `build/` folder (created on failure) |

### Check all tools are installed

```bash
yosys --version
nextpnr-xilinx --version
openFPGALoader --version
ls ~/.local/share/nextpnr/xilinx/chipdb-xc7a100t.bin 2>/dev/null || echo "chipdb handled by snap"
ls .tools/prjxray/build/tools/xc7frames2bit
```

---

## How it works (under the hood)

```
your_design.sv
      │
      ▼  yosys -p "synth_xilinx …"
  design.json        (gate-level netlist)
      │
      ▼  nextpnr-xilinx --chipdb chipdb-xc7a100t.bin
  design.fasm        (placed-and-routed FASM)
      │
      ▼  fasm2frames (Python, prjxray)
  design.frames      (binary frame data)
      │
      ▼  xc7frames2bit (C++, prjxray)
  design.bit         ← flash this to the board
```
