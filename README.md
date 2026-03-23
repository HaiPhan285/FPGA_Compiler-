# FPGA Compiler

Open-source build flow for the **Digilent Nexys A7-100T (XC7A100T-CSG324-1)** using:

- `yosys` for synthesis
- `nextpnr-xilinx` for place and route
- `fasm2frames` and `xc7frames2bit` for bitstream generation
- `openFPGALoader` for flashing

This project supports both **Verilog (`.v`)** and **SystemVerilog (`.sv`)**.

## Fast start

You can use either method below:

```bash
# Option A: clone
git clone https://github.com/HaiPhan285/FPGA_Compiler-.git
cd FPGA_Compiler-

# Option B: download the GitHub ZIP, extract it, then:
cd FPGA_Compiler-
```

Then run:

```bash
chmod +x setup.sh build.sh doctor.sh
./setup.sh
./doctor.sh --smoke
./build.sh
```

What those commands do:

1. `setup.sh` installs or reuses the required Linux FPGA tools.
2. `doctor.sh --smoke` checks the environment and runs one small Verilog build plus one small SystemVerilog build.
3. `build.sh` shows a project menu and builds the selected project.

If setup succeeds, you should not need to manually clone `prjxray` or `prjxray-db`.

For the full manual setup flow, see [SETUP.md](/home/HaiPhan27/FPGA_Compiler-/SETUP.md).

## Requirements

- Ubuntu 22.04 or 24.04 is the main supported local environment
- `sudo` access for `setup.sh`
- Nexys A7-100T board if you want to flash hardware

## Daily use

### Build from the menu

```bash
./build.sh
```

The script now tries to auto-pick the normal board top file and the matching `.xdc` file for each sample project, so most users only need to choose the project number.

### Build one project directly

```bash
./build.sh --source-dir app/project5
./build.sh --source-dir "app/chapter 6"
```

Those commands auto-detect:

- the project name
- the top module file
- the recommended constraints file

Use explicit arguments only when you want a non-default source or XDC:

```bash
./build.sh \
  --source-dir "app/chapter 6" \
  --top fsm_traffic \
  --constraints "app/chapter 6/fsm_traffic.xdc" \
  --project chapter6_fsm
```

### Flash a built bitstream

```bash
./build.sh --flash
```

Or directly:

```bash
openFPGALoader -b nexys_a7_100 app/project5/project5.bit
```

## Project format

Each buildable project folder under `app/` should contain:

- at least one `.v` or `.sv` file with a valid `module`
- at least one `.xdc` constraints file

Recommended pattern:

```text
app/my_project/
├── top.sv
└── constraints.xdc
```

That naming lets `build.sh` auto-pick the right files with no extra flags.

## Constraints rules

Use one line per port or bus bit. Example:

```tcl
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports {a}]
```

Important rules:

- Every external port needs a `PACKAGE_PIN`
- Every external port needs an `IOSTANDARD`
- For Nexys A7 examples here, use `LVCMOS33`
- Do not put spaces directly inside braces for `nextpnr-xilinx`

Wrong:

```tcl
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports { a }]
```

Correct:

```tcl
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports {a}]
```

`build.sh` auto-sanitizes the common brace-spacing mistake in the temporary copied XDC, but the source `.xdc` should still be written correctly.

## Easier debugging

The build now does a **constraint pre-check before nextpnr**. If the selected `.xdc` is missing required entries, the script stops early and prints a direct message such as:

```text
Constraint pre-check failed for top module 'top'.
- Missing IOSTANDARD: clk_1hz
```

On tool failures, the script also:

- prints the important `ERROR:` lines again near the end
- preserves the temporary build directory on failure
- tells you where `yosys.log`, `constraints.log`, and `nextpnr.log` were saved

## Troubleshooting

| Error | Meaning | Fix |
|---|---|---|
| `nextpnr-xilinx not found` | openXC7 or nextpnr is not installed or not detected | Run `./setup.sh` |
| `Chipdb file not found` | `chipdb-xc7a100t.bin` is missing | Run `./setup.sh`; it now generates the chipdb automatically when needed |
| `openxc7 is already installed. Please remove it first` | You reran the external installer even though `openxc7` already exists | Do not rerun that installer. Use `./setup.sh` or `./build.sh` |
| `Assertion failure: str.back() == '}'` | The XDC uses unsupported brace spacing like `{ clk }` | Remove spaces inside braces |
| `port <name> of type PAD has no IOSTANDARD property` | The selected XDC does not give that port an `IOSTANDARD` | Add `IOSTANDARD LVCMOS33` for that port |
| `port <name> of type PAD has no PACKAGE_PIN property` | The selected XDC does not assign a pin for that port | Add `PACKAGE_PIN <PIN>` for that port |
| `Constraint pre-check failed` | The source and XDC do not match | Use the right `.xdc` file or add the missing port constraints |
| `Module '<name>' not found` | The selected top file is not the real top module, or a dependency is missing | Use the board top file, usually `top.sv` or `top.v` |
| `ImportError: libffi.so.7` during `fasm2frames` | The bundled tool falls back to a slower parser | Usually safe if the build still completes and produces `.bit` |
| `Build failed. Artifacts preserved in /tmp/...` | The tool stopped and the logs were kept | Open the printed temp directory and inspect `yosys.log`, `constraints.log`, and `nextpnr.log` |

## Check your install

```bash
./doctor.sh
./doctor.sh --smoke
```

`doctor.sh --smoke` is the fastest way to confirm that both `.v` and `.sv` projects build correctly on the current machine.

JTAG init failed with: unable to open ftdi device:
 usbipd list: 
 Find the USB Serial Converter A, USB Serial Converter B
usbipd attach --wsl --busid

## Windows users without WSL

This repo’s local build flow is **Linux-first** because the openXC7 toolchain used here is installed through Linux-oriented paths such as the Ubuntu snap bundle and Linux binaries.

Practical options for Windows users who do **not** want WSL:

1. Use an Ubuntu virtual machine and run `setup.sh` there.
2. Use a remote Linux machine and copy back the generated `.bit` file.
3. Use Windows only for flashing an already-built `.bit` file with `openFPGALoader`.

For flashing only on Windows, the official `openFPGALoader` docs list an MSYS2 package:

```bash
pacman -S mingw-w64-ucrt-x86_64-openFPGALoader
```

What is supported well today:

- Local build: Linux
- Flashing only: Linux, Windows, or macOS with `openFPGALoader`

What is **not** a supported local path for this repo today:

- Native Windows build of the full openXC7 flow without a Linux environment

## Repository layout

```text
FPGA_Compiler-/
├── setup.sh
├── doctor.sh
├── build.sh
├── prjxray-env.sh
├── README.md
├── SETUP.md
└── app/
```

## Typical output flow

```text
your_design.v / your_design.sv
        |
        v
      yosys
        |
        v
  design.json
        |
        v
  nextpnr-xilinx
        |
        v
  design.fasm
        |
        v
  fasm2frames
        |
        v
  design.frames
        |
        v
  xc7frames2bit
        |
        v
   design.bit
```
