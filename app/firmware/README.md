# FPGA Bare-Metal Firmware Build Guide

## Overview
This is a complete firmware build system for the **Nexys A7-100T FPGA board** running a **PicoRV32 RISC-V soft processor**. The build process compiles C code to RISC-V machine code, synthesizes RTL with Yosys, performs place & route with NextPNR, and generates a bitstream using PRJXRAY.

**Target Device:** Xilinx XC7A100T (Nexys A7-100T)  
**Soft CPU:** PicoRV32 (32-bit RISC-V)  
**Toolchain:** Yosys + NextPNR + PRJXRAY + RISC-V GCC

---

## Prerequisites

### 1. Install RISC-V GCC Toolchain
```bash
# For Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y build-essential git autoconf automake autotools-dev \
    curl python3 python3-pip libmpc-dev libmpfr-dev libgmp-dev \
    gawk bison flex texinfo gperf libtool patchutils bc zlib1g-dev

# Install RISC-V GCC (if not already installed)
# Option 1: Pre-built binary (fastest)
wget https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/2023.02.0/riscv64-glibc-ubuntu-20.04-gcc-12.2.0-binutils-2.39.tar.gz
tar xzf riscv64-glibc-ubuntu-20.04-gcc-12.2.0-binutils-2.39.tar.gz -C ~/
# Add to PATH: export PATH=$PATH:~/riscv64-glibc-ubuntu-20.04-gcc-12.2.0-binutils-2.39/bin

# Option 2: Build from source (takes ~1 hour)
git clone https://github.com/riscv-collab/riscv-gnu-toolchain.git
cd riscv-gnu-toolchain
./configure --prefix=/opt/riscv --with-arch=rv32imc --with-abi=ilp32
make -j$(nproc)
sudo mkdir -p /opt/riscv && sudo chown -R $(whoami) /opt/riscv
# Add to PATH: export PATH=/opt/riscv/bin:$PATH
```

### 2. Install Synthesis & P&R Tools

#### Yosys (Open-source Verilog synthesis)
```bash
sudo apt-get install -y yosys
# Or build from source: https://github.com/YosysHQ/yosys
```

#### NextPNR-Xilinx (Place & Route)
```bash
# NextPNR requires Boost, Protocol Buffers, and more
sudo apt-get install -y nextpnr
# Or build from source: https://github.com/YosysHQ/nextpnr

# After installation, download chipdb for your device
mkdir -p ~/.local/share/nextpnr/xilinx/
wget https://github.com/YosysHQ/nextpnr-xilinx/releases/download/v0.3/chipdb-xc7a100t.bin \
    -O ~/.local/share/nextpnr/xilinx/chipdb-xc7a100t.bin
```

#### PRJXRAY Database (Bitstream generation)
```bash
mkdir -p ~/.local/share/fpga-tools
cd ~/.local/share/fpga-tools

# Clone PRJXRAY (already in project, but reference here)
git clone https://github.com/Project-X-Ray/prjxray.git
git clone https://github.com/Project-X-Ray/prjxray-db.git

# Or use existing from project:
ln -s ~/FPGA_Compiler-/.tools/prjxray ~/.local/share/fpga-tools/prjxray
ln -s ~/FPGA_Compiler-/.tools/prjxray-db ~/.local/share/fpga-tools/prjxray-db
```

#### xc7frames2bit (Bitstream to FRAMES converter)
```bash
pip3 install xc7frames2bit
# Or: apt-get install xc7frames2bit
```

#### openFPGALoader (Optional - for programming board)
```bash
sudo apt-get install -y libusb-1.0-0-dev libftdi1-dev
git clone https://github.com/trabucayre/openFPGALoader.git
cd openFPGALoader
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo make install
```

### 3. Verify Installation
```bash
# Check each tool
riscv64-unknown-elf-gcc --version
yosys --version
nextpnr-xilinx --help 2>&1 | head -5
xc7frames2bit --help 2>&1 | head -5
which openFPGALoader  # Optional
```

---

## Project Structure

Create the following directory structure:

```
firmware/
├── src/
│   ├── firmware.sv          # Top-level Verilog module
│   ├── picorv32.v           # PicoRV32 soft CPU (pre-built)
│   ├── firmware.c           # Main C program (RISC-V target)
│   ├── link.ld              # Linker script
│   └── constraints.xdc      # Pin assignments & timing constraints
├── build/                   # Build artifacts (auto-generated)
├── sim/                     # Simulation testbenches (optional)
├── docs/                    # Documentation
├── Makefile                 # Build automation
└── build.sh                 # Alternative bash build script
```

---

## Step-by-Step Build Instructions

### Step 1: Create Source Files

#### A. Create `src/firmware.c` - Main Program
```c
// src/firmware.c - RISC-V bare-metal firmware

void main() {
    // Simple blink example
    volatile int *gpio_base = (int *)0x80000000;  // GPIO base address
    
    while(1) {
        *gpio_base = 0xFFFF;        // All LEDs on
        for(int i = 0; i < 1000000; i++) asm("nop");
        
        *gpio_base = 0x0000;        // All LEDs off
        for(int i = 0; i < 1000000; i++) asm("nop");
    }
}
```

#### B. Create `src/link.ld` - Linker Script
```ld
/* src/link.ld - RISC-V linker script */

OUTPUT_ARCH(riscv)
ENTRY(main)

MEMORY {
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS {
    .text : {
        *(.text)
    } > RAM
    
    .data : {
        *(.data)
    } > RAM
    
    .bss : {
        *(.bss)
    } > RAM
}
```

#### C. Create `src/firmware.sv` - Top Module
```systemverilog
// src/firmware.sv - Top-level module

module top (
    input  clk,           // 100 MHz system clock
    input  rst_n,         // Active-low reset
    output [15:0] led     // 16 LEDs on Nexys A7
);

    wire [31:0] instr;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_we;
    wire [31:0] mem_rdata;

    // Instantiate PicoRV32 CPU
    picorv32 #(
        .ENABLE_COUNTERS(1),
        .LATCHED_MEM_RDATA(1)
    ) cpu (
        .clk      (clk),
        .resetn   (~rst_n),
        .mem_addr (mem_addr),
        .mem_wdata(mem_wdata),
        .mem_we   (mem_we),
        .mem_rdata(mem_rdata)
    );

    // Simple GPIO output (writes to address 0x80000000)
    always @(posedge clk) begin
        if (mem_we && mem_addr == 32'h80000000) begin
            led <= mem_wdata[15:0];
        end
    end

endmodule
```

#### D. Create `src/constraints.xdc` - Pin Constraints
```
# Nexys A7-100T Pin Constraints
# src/constraints.xdc

# System Clock (100 MHz)
set_property LOC E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

# Reset Button (CPU reset)
set_property LOC D9 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# LEDs (16 LEDs on board)
set_property LOC H17 [get_ports {led[0]}]
set_property LOC K15 [get_ports {led[1]}]
set_property LOC J13 [get_ports {led[2]}]
set_property LOC NF14 [get_ports {led[3]}]
set_property LOC NE14 [get_ports {led[4]}]
set_property LOC F13 [get_ports {led[5]}]
set_property LOC E13 [get_ports {led[6]}]
set_property LOC J11 [get_ports {led[7]}]
set_property LOC H11 [get_ports {led[8]}]
set_property LOC G12 [get_ports {led[9]}]
set_property LOC F12 [get_ports {led[10]}]
set_property LOC E12 [get_ports {led[11]}]
set_property LOC D12 [get_ports {led[12]}]
set_property LOC D11 [get_ports {led[13]}]
set_property LOC D10 [get_ports {led[14]}]
set_property LOC C10 [get_ports {led[15]}]

set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]
```

#### E. Download PicoRV32
```bash
# Get picorv32.v from official repo
cd src/
wget https://raw.githubusercontent.com/cliffordwolf/picorv32/master/picorv32.v
cd ..
```

### Step 2: Create Build System

#### A. Create `Makefile`
```makefile
################################################################################
# FPGA Bare-Metal Firmware Build System
# Target: Nexys A7-100T (Xilinx XC7A100T)
# Toolchain: Yosys + NextPNR + PRJXRAY + RISC-V GCC
################################################################################

# Hardware Configuration
CHIP := xc7a100t
PART := xc7a100tcsg324-1
BOARD := nexys_a7_100

# Tool Paths
CHIPDB := $(HOME)/.local/share/nextpnr/xilinx/chipdb-$(CHIP).bin
PRJXRAY_REPO := $(HOME)/FPGA_Compiler-/.tools/prjxray
PRJXRAY_DB := $(HOME)/FPGA_Compiler-/.tools/prjxray-db/artix7

# RISC-V Compiler Configuration
RISCV_PREFIX := riscv64-unknown-elf-
CC := $(RISCV_PREFIX)gcc
OBJCOPY := $(RISCV_PREFIX)objcopy
OBJDUMP := $(RISCV_PREFIX)objdump
CFLAGS := -march=rv32imc -mabi=ilp32 -O2 -nostdlib

# Source Files
RTL_FILES := src/firmware.sv src/picorv32.v
C_SOURCE := src/firmware.c
LINKER_SCRIPT := src/link.ld
CONSTRAINTS := src/constraints.xdc

# Generated Files (Build Artifacts)
BUILD_DIR := build
ELF := $(BUILD_DIR)/firmware.elf
HEX := $(BUILD_DIR)/firmware.hex
DUMP := $(BUILD_DIR)/firmware.dump
JSON := $(BUILD_DIR)/firmware.json
FASM := $(BUILD_DIR)/firmware.fasm
FRAMES := $(BUILD_DIR)/firmware.frames
BITSTREAM := $(BUILD_DIR)/firmware.bit

# Create build directory
$(shell mkdir -p $(BUILD_DIR))

# Targets
.PHONY: all clean distclean program help

all: $(BITSTREAM)
	@echo "✓ Build complete: $(BITSTREAM)"

$(ELF): $(C_SOURCE) $(LINKER_SCRIPT)
	@echo "[1/4] Compiling RISC-V firmware..."
	$(CC) $(CFLAGS) -o $@ $(C_SOURCE) -T $(LINKER_SCRIPT)

$(HEX): $(ELF)
	@echo "[1/4] Generating hex firmware..."
	$(OBJCOPY) -O verilog $< $@
	$(OBJDUMP) -d $< > $(DUMP)

$(JSON): $(RTL_FILES)
	@echo "[2/4] Synthesizing RTL with Yosys..."
	yosys -p "read_verilog -sv $^; synth_xilinx -top top -family xc7; write_json $@" 2>&1 | tail -20

$(FASM): $(JSON) $(CONSTRAINTS) $(HEX)
	@echo "[3/4] Place & Route with NextPNR..."
	nextpnr-xilinx --chipdb $(CHIPDB) --json $< --xdc $(CONSTRAINTS) --fasm $@ 2>&1 | tail -20

$(BITSTREAM): $(FASM)
	@echo "[4/4] Generating bitstream..."
	python3 $(PRJXRAY_REPO)/utils/fasm2frames.py --part $(PART) --db-root $(PRJXRAY_DB) $< $(FRAMES) 2>&1 | tail -5
	xc7frames2bit -part_file $(PRJXRAY_DB)/$(PART)/part.yaml -frm_file $(FRAMES) -output_file $@
	@echo "✓ Bitstream ready: $@"

program: $(BITSTREAM)
	@echo "Programming FPGA..."
	openFPGALoader -b $(BOARD) $<
	@echo "✓ FPGA programmed successfully"

inspect: $(DUMP)
	@echo "=== RISC-V Disassembly ==="
	@cat $(DUMP)

clean:
	rm -rf $(BUILD_DIR)
	@echo "✓ Build artifacts removed"

distclean: clean
	@echo "✓ Project clean"

help:
	@echo "FPGA Bare-Metal Firmware Build System"
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  all       - Build firmware and bitstream (default)"
	@echo "  program   - Program bitstream to FPGA"
	@echo "  inspect   - Show RISC-V disassembly"
	@echo "  clean     - Remove build artifacts"
	@echo "  help      - Show this help"
	@echo ""
	@echo "Quick start:"
	@echo "  make              # Build all"
	@echo "  make program      # Build and program FPGA"
```

#### B. Create `build.sh` - Bash Build Script (Alternative)
```bash
#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "=== FPGA Firmware Build ==="

RISCV_PREFIX=riscv64-unknown-elf-
CHIPDB=$HOME/.local/share/nextpnr/xilinx/chipdb-xc7a100t.bin
PART=xc7a100tcsg324-1
PRJXRAY_REPO=$HOME/FPGA_Compiler-/.tools/prjxray
PRJXRAY_DB=$HOME/FPGA_Compiler-/.tools/prjxray-db/artix7

# Create build directory
mkdir -p build

# Step 1: Compile C to RISC-V
echo "[1/4] Compiling RISC-V firmware..."
${RISCV_PREFIX}gcc -march=rv32imc -mabi=ilp32 -O2 -nostdlib \
    -o build/firmware.elf src/firmware.c -T src/link.ld

echo "[1/4] Generating hex and disassembly..."
${RISCV_PREFIX}objcopy -O verilog build/firmware.elf build/firmware.hex
${RISCV_PREFIX}objdump -d build/firmware.elf > build/firmware.dump

# Step 2: Synthesize with Yosys
echo "[2/4] Synthesizing RTL with Yosys..."
yosys -p "read_verilog -sv src/firmware.sv src/picorv32.v; \
    synth_xilinx -top top -family xc7; \
    write_json build/firmware.json" 2>&1 | tail -10

# Step 3: Place & Route with NextPNR
echo "[3/4] Place & Route with NextPNR..."
nextpnr-xilinx --chipdb $CHIPDB \
    --json build/firmware.json \
    --xdc src/constraints.xdc \
    --fasm build/firmware.fasm 2>&1 | tail -10

# Step 4: Generate bitstream
echo "[4/4] Generating bitstream..."
python3 $PRJXRAY_REPO/utils/fasm2frames.py \
    --part $PART --db-root $PRJXRAY_DB \
    build/firmware.fasm build/firmware.frames 2>&1 | tail -5

xc7frames2bit -part_file $PRJXRAY_DB/$PART/part.yaml \
    -frm_file build/firmware.frames \
    -output_file build/firmware.bit

echo "✓ Build complete!"
echo "Bitstream: build/firmware.bit"
ls -lh build/firmware.bit
```

### Step 3: Run the Build

#### Option 1: Using Makefile (Recommended)
```bash
# Build everything
make

# Build and program FPGA
make program

# View disassembly
make inspect

# Clean build artifacts
make clean
```

#### Option 2: Using build.sh
```bash
chmod +x build.sh
./build.sh
```

---

## Build Output Explanation

After a successful build, you'll have:

```
build/
├── firmware.elf          # RISC-V executable (unlinked)
├── firmware.hex          # Hex format (loaded into BRAM during synthesis)
├── firmware.dump         # Disassembly of RISC-V code (debugging)
├── firmware.json         # Yosys synthesis output (netlist)
├── firmware.fasm         # FASM bitstream (plain text)
├── firmware.frames       # FRAMES format (binary bitstream pieces)
└── firmware.bit          # Final bitstream (ready to program)
```

**firmware.bit** is what gets programmed to your FPGA.

---

## Troubleshooting

### Issue: `riscv64-unknown-elf-gcc not found`
**Solution:**
```bash
# Check if installed
which riscv64-unknown-elf-gcc

# If not, add to PATH
export PATH=$PATH:/path/to/riscv/bin
# Or install: apt-get install gcc-riscv64-unknown-elf
```

### Issue: `yosys not found`
```bash
sudo apt-get install -y yosys
```

### Issue: `nextpnr-xilinx: no chipdb found`
```bash
# Download chipdb
mkdir -p ~/.local/share/nextpnr/xilinx/
wget https://github.com/YosysHQ/nextpnr-xilinx/releases/download/v0.3/chipdb-xc7a100t.bin \
    -O ~/.local/share/nextpnr/xilinx/chipdb-xc7a100t.bin
```

### Issue: `PRJXRAY_DB not found`
```bash
# Ensure PRJXRAY is in correct location or update path in Makefile
export PRJXRAY_DB=$HOME/FPGA_Compiler-/.tools/prjxray-db/artix7
ls $PRJXRAY_DB  # Should show device database files
```

### Issue: Build hangs at NextPNR
- This is normal - NextPNR can take 5-30 minutes depending on design size
- Check CPU usage with `top` to confirm it's still working
- Increase verbosity with `--verbose` flag for debugging

---

## Programming the FPGA

### Using OpenFPGALoader
```bash
# Program with openFPGALoader
make program

# Or manually
openFPGALoader -b nexys_a7_100 build/firmware.bit
```

### Using Vivado (Alternative)
```bash
vivado -mode batch -source program.tcl
```

### Using Hardware Server (XilinxISE)
```bash
# Connect JTAG cable, then:
impact -batch < program.impact
```

---

## Environment Variables

For easier builds, set these permanently in `~/.bashrc`:

```bash
# Add to ~/.bashrc
export PATH=$PATH:~/riscv64-glibc-ubuntu-20.04-gcc-12.2.0-binutils-2.39/bin
export PATH=$PATH:/opt/riscv/bin

# Or set per-project
export RISC_PATH=$HOME/riscv64-glibc-ubuntu-20.04-gcc-12.2.0-binutils-2.39
export PATH=$PATH:$RISCV_PATH/bin
```

---

## Advanced Configuration

### Customizing for Different FPGA Boards

Edit the `Makefile` variables:

```makefile
# For Nexys Video (XC7A200T)
CHIP := xc7a200t
PART := xc7a200tsbg484-1

# For Artix-7 XC7A35T
CHIP := xc7a35t
PART := xc7a35tcpg236-1
```

### Optimization Flags

Modify `CFLAGS` in Makefile:
```makefile
CFLAGS := -march=rv32imc -mabi=ilp32 -O2 -nostdlib -fno-tree-loop-optimize -fno-inline
```

---

## References & Documentation

- **PicoRV32:** https://github.com/cliffordwolf/picorv32
- **Yosys:** https://yosyshq.net/
- **NextPNR:** https://github.com/YosysHQ/nextpnr
- **PRJXRAY:** https://github.com/Project-X-Ray/prjxray
- **RISC-V ISA:** https://riscv.org/
- **Nexys A7 Reference:** https://reference.digilentinc.com/reference/programmable-logic/nexys-a7/start

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────┐
│ MAKE TARGETS                                             │
├─────────────────────────────────────────────────────────┤
│ make              → Compile & generate bitstream        │
│ make program      → Build + program FPGA                │
│ make inspect      → View RISC-V disassembly             │
│ make clean        → Remove build artifacts              │
│ make help         → Show this help                       │
└─────────────────────────────────────────────────────────┘

BUILD TIME ESTIMATES:
  C Compilation:     ~2 seconds
  Yosys Synthesis:   ~15 seconds
  NextPNR P&R:       ~10-30 minutes (depends on design)
  FASM2Bitstream:    ~5 seconds
  ─────────────────────────────
  Total:             ~15-35 minutes (first run)

REQUIRED DISK SPACE:
  RISC-V GCC:        ~2 GB
  Yosys:             ~500 MB
  NextPNR:           ~500 MB
  PRJXRAY Database:  ~5 GB
  ─────────────────────────────
  Total:             ~8+ GB
```

---

**Happy building! 🚀**

For questions or issues, check the docs/ folder or review the Makefile comments.
