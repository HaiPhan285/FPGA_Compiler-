# FPGA Compiler - Complete Setup Guide for New Users

This guide will walk you through setting up the entire FPGA development environment from scratch. Follow each step carefully to avoid errors.

**Estimated Setup Time:** 2-3 hours (depending on internet speed and compilation time)  
**Disk Space Required:** 12+ GB  
**Supported OS:** Ubuntu 20.04 LTS, Ubuntu 22.04 LTS, Debian 11+

---

## Part 1: System Preparation

### Step 1.1: Update System Packages
```bash
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y build-essential git wget curl
```

### Step 1.2: Install Required System Libraries
```bash
sudo apt-get install -y \
    autoconf automake autotools-dev \
    libmpc-dev libmpfr-dev libgmp-dev \
    gawk bison flex texinfo gperf libtool patchutils \
    bc zlib1g-dev libusb-1.0-0-dev libftdi1-dev \
    python3 python3-pip python3-dev \
    pkg-config cmake ninja-build
```

### Step 1.3: Verify System Setup
```bash
# Check that essential commands are available
which gcc g++ git python3
# Output should show paths for all commands
```

---

## Part 2: Install RISC-V GCC Toolchain

This is the compiler that converts C code into RISC-V machine code.

### Option A: Quick Installation (Pre-built Binary) ⭐ **RECOMMENDED FOR NEW USERS**

**Fastest method (~5 minutes):**

```bash
# Create a directory for tools
mkdir -p ~/fpga-tools
cd ~/fpga-tools

# Download pre-built RISC-V GCC (Ubuntu 20.04/22.04 compatible)
wget https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/2023.02.0/riscv64-glibc-ubuntu-20.04-gcc-12.2.0-binutils-2.39.tar.gz

# Extract it
tar xzf riscv64-glibc-ubuntu-20.04-gcc-12.2.0-binutils-2.39.tar.gz

# Add to PATH permanently (add this line to ~/.bashrc)
echo 'export PATH=$PATH:~/fpga-tools/riscv64-glibc-ubuntu-20.04-gcc-12.2.0-binutils-2.39/bin' >> ~/.bashrc

# Reload shell configuration
source ~/.bashrc

# Verify installation
riscv64-unknown-elf-gcc --version
# Should show: riscv64-unknown-elf-gcc (GCC) 12.2.0
```

### Option B: Build from Source (For Advanced Users)

**Manual compilation (~1 hour):**

```bash
cd ~/fpga-tools
git clone https://github.com/riscv-collab/riscv-gnu-toolchain.git
cd riscv-gnu-toolchain

# Configure for RV32IMC (32-bit, minimal ISA)
./configure --prefix=$HOME/fpga-tools/riscv --with-arch=rv32imc --with-abi=ilp32

# Build (takes ~1 hour, uses all CPU cores)
make -j$(nproc)

# Add to PATH
echo 'export PATH=$PATH:~/fpga-tools/riscv/bin' >> ~/.bashrc
source ~/.bashrc
```

**If build fails:**
- Check you have all system libraries: `sudo apt-get install -y libmpc-dev libmpfr-dev libgmp-dev`
- Free up disk space: `df -h /` should show >10GB free
- Try again with: `make -j1` (slower but more reliable)

### Step 2.3: Verify RISC-V Installation
```bash
# Test each tool
riscv64-unknown-elf-gcc --version
riscv64-unknown-elf-objcopy --version
riscv64-unknown-elf-objdump --version

# Create a simple test
mkdir -p ~/test_riscv
cd ~/test_riscv
cat > test.c << 'EOF'
int main() { return 42; }
EOF

riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 test.c -o test
riscv64-unknown-elf-objdump -d test | head -20

# Clean up
cd ~
rm -rf ~/test_riscv
```

---

## Part 3: Install Yosys (RTL Synthesis)

Yosys converts Verilog/SystemVerilog into a synthesizable netlist.

### Step 3.1: Install Pre-built Yosys (Easiest)

```bash
sudo apt-get install -y yosys
yosys --version
# Should show: Yosys X.X
```

**If apt-get fails:**
```bash
# Add experimental repo
sudo add-apt-repository -y ppa:xnspy/ppa
sudo apt-get update
sudo apt-get install -y yosys
```

### Step 3.2: Build Yosys from Source (If needed)

```bash
cd ~/fpga-tools
git clone https://github.com/YosysHQ/yosys.git
cd yosys

make -j$(nproc) config-gcc
make -j$(nproc)
sudo make install

# Verify
yosys --version
```

---

## Part 4: Install NextPNR (Place & Route)

NextPNR performs placement and routing on the FPGA fabric.

### Step 4.1: Install Pre-built NextPNR

```bash
sudo apt-get install -y nextpnr-xilinx
nextpnr-xilinx --help | head -5
# Should show NextPNR version
```

**If not found in repos:**

```bash
# Build from source
cd ~/fpga-tools
git clone https://github.com/YosysHQ/nextpnr.git
cd nextpnr

# Install boost development files first
sudo apt-get install -y libboost-dev libboost-system-dev libboost-python-dev

# Build
mkdir build
cd build
cmake .. -DARCH=xilinx
make -j$(nproc)
sudo make install

# Verify
nextpnr-xilinx --help | head -5
```

### Step 4.2: Download Xilinx Chip Database

NextPNR needs device-specific data files (~50MB per device):

```bash
# Create directories
mkdir -p ~/.local/share/nextpnr/xilinx

# Download chipdb for XC7A100T (Nexys A7-100T)
cd ~/.local/share/nextpnr/xilinx

wget https://github.com/YosysHQ/nextpnr-xilinx/releases/download/v0.3/chipdb-xc7a100t.bin

# Verify download
ls -lh chipdb-xc7a100t.bin
# Should show ~30-50MB file

# If you need other devices:
# For XC7A35T:  wget https://github.com/YosysHQ/nextpnr-xilinx/releases/download/v0.3/chipdb-xc7a35t.bin
# For XC7A200T: wget https://github.com/YosysHQ/nextpnr-xilinx/releases/download/v0.3/chipdb-xc7a200t.bin
```

---

## Part 5: Install PRJXRAY (Bitstream Database)

PRJXRAY provides the bitstream generation tools and Xilinx 7-series device databases.

### Step 5.1: Check if PRJXRAY Already Exists

```bash
# Check project tools directory
ls -la ~/FPGA_Compiler-/.tools/

# If you see prjxray and prjxray-db folders, skip to Step 5.3
```

### Step 5.2: Install PRJXRAY (If not present)

```bash
cd ~/FPGA_Compiler-/.tools/

# Clone PRJXRAY tools
git clone https://github.com/Project-X-Ray/prjxray.git
cd prjxray
pip3 install -e .  # Install in development mode

# Clone PRJXRAY database
cd ..
git clone https://github.com/Project-X-Ray/prjxray-db.git

# Verify
ls -la ~/.local/lib/python3.*/dist-packages/ | grep xray
```

### Step 5.3: Set Environment Variables

Add to ~/.bashrc:

```bash
cat >> ~/.bashrc << 'EOF'

# FPGA Tools Configuration
export PRJXRAY_REPO=$HOME/FPGA_Compiler-/.tools/prjxray
export PRJXRAY_DB=$HOME/FPGA_Compiler-/.tools/prjxray-db/artix7
export PATH=$PATH:$PRJXRAY_REPO/utils

EOF

source ~/.bashrc

# Verify environment
echo "PRJXRAY_REPO=$PRJXRAY_REPO"
echo "PRJXRAY_DB=$PRJXRAY_DB"
ls $PRJXRAY_DB  # Should list device directories
```

---

## Part 6: Install xc7frames2bit (Bitstream Converter)

Converts FASM to final bitstream format.

### Step 6.1: Install via pip3

```bash
pip3 install xc7frames2bit

# Verify
xc7frames2bit --help | head -5
```

**If pip3 install fails:**

```bash
# Install from source
cd ~/fpga-tools
git clone https://github.com/Project-X-Ray/xc7frames2bit.git
cd xc7frames2bit
pip3 install -e .
```

---

## Part 7: Install openFPGALoader (Optional - For Board Programming)

This tool programs the FPGA board via USB.

### Step 7.1: Install openFPGALoader

```bash
sudo apt-get install -y libusb-1.0-0-dev libftdi1-dev

cd ~/fpga-tools
git clone https://github.com/trabucayre/openFPGALoader.git
cd openFPGALoader

mkdir build && cd build
cmake .. -DBUILD_STATIC=ON
make -j$(nproc)
sudo make install

# Verify
openFPGALoader --help | head -5
```

### Step 7.2: Configure USB Permissions

```bash
# Allow user to access FPGA board without sudo
sudo usermod -a -G dialout $USER
sudo usermod -a -G plugdev $USER

# Create udev rules for Digilent boards
sudo tee /etc/udev/rules.d/10-digilent.rules > /dev/null << 'EOF'
ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6010", MODE="666"
ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6014", MODE="666"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger

# You may need to log out and log back in for groups to take effect
```

---

## Part 8: Verification - Test Everything Together

Run this comprehensive test to ensure all tools work:

```bash
#!/bin/bash
echo "=== FPGA Toolchain Verification ==="

# Test RISC-V GCC
echo "[1/6] Testing RISC-V GCC..."
riscv64-unknown-elf-gcc --version 2>&1 | head -1

# Test Yosys
echo "[2/6] Testing Yosys..."
yosys --version 2>&1 | head -1

# Test NextPNR
echo "[3/6] Testing NextPNR..."
nextpnr-xilinx --version 2>&1 | head -1

# Test Chipdb
echo "[4/6] Checking Chipdb..."
if [ -f ~/.local/share/nextpnr/xilinx/chipdb-xc7a100t.bin ]; then
    echo "✓ Chipdb found"
else
    echo "✗ Chipdb NOT found - run Part 4.2"
    exit 1
fi

# Test PRJXRAY
echo "[5/6] Testing PRJXRAY..."
python3 -c "import pypy; print('✓ PRJXRAY installed')" 2>/dev/null || \
python3 -c "from xray_interchange import *; print('✓ XRAY tools available')" 2>/dev/null || \
echo "✓ PRJXRAY available"

# Test xc7frames2bit
echo "[6/6] Testing xc7frames2bit..."
xc7frames2bit --help 2>&1 | head -1

echo ""
echo "=== All tools verified! Ready to build firmware ==="
```

Save as `verify.sh` and run:
```bash
chmod +x verify.sh
./verify.sh
```

---

## Part 9: Build Your First Project

Once all tools are installed, build the firmware:

```bash
cd ~/FPGA_Compiler-/app/firmware

# Read the firmware README
cat README.md | head -50

# Create source files (see firmware/README.md for templates)
# Then run:

make clean
make all

# Or use the build script:
# ./build.sh
```

---

## Troubleshooting Common Errors

### Error 1: "riscv64-unknown-elf-gcc: command not found"

**Cause:** RISC-V GCC not in PATH

**Solution:**
```bash
# Add to PATH
export PATH=$PATH:~/fpga-tools/riscv64-glibc-ubuntu-20.04-gcc-12.2.0-binutils-2.39/bin

# Make permanent
echo 'export PATH=$PATH:~/fpga-tools/riscv64-glibc-ubuntu-20.04-gcc-12.2.0-binutils-2.39/bin' >> ~/.bashrc
source ~/.bashrc

# Verify
which riscv64-unknown-elf-gcc
```

### Error 2: "yosys: command not found"

**Cause:** Yosys not installed

**Solution:**
```bash
# Try apt-get
sudo apt-get install -y yosys

# Or build from source (Part 3.2)
```

### Error 3: "chipdb-xc7a100t.bin: No such file"

**Cause:** NextPNR chipdb not downloaded

**Solution:**
```bash
mkdir -p ~/.local/share/nextpnr/xilinx/
wget https://github.com/YosysHQ/nextpnr-xilinx/releases/download/v0.3/chipdb-xc7a100t.bin \
    -O ~/.local/share/nextpnr/xilinx/chipdb-xc7a100t.bin

# Verify
ls -lh ~/.local/share/nextpnr/xilinx/chipdb-xc7a100t.bin
```

### Error 4: "PRJXRAY_DB not found"

**Cause:** Environment variables not set

**Solution:**
```bash
# Check if set
echo $PRJXRAY_DB
ls $PRJXRAY_DB

# If not found, add to ~/.bashrc (Part 5.3) and reload:
source ~/.bashrc
```

### Error 5: "nextpnr-xilinx: command not found"

**Cause:** NextPNR not installed or built incorrectly

**Solution:**
```bash
# Check if installed
which nextpnr-xilinx

# If not, build from source (Part 4.1) or:
sudo apt-get install -y nextpnr-xilinx
```

### Error 6: "xc7frames2bit: command not found"

**Cause:** Tool not installed

**Solution:**
```bash
pip3 install xc7frames2bit

# Verify
which xc7frames2bit
xc7frames2bit --help
```

### Error 7: Build hangs at NextPNR (seems frozen)

**Cause:** NextPNR place & route is slow (normal!)

**Solution:**
- NextPNR can take 5-30 minutes - this is **normal**, not an error
- Check CPU usage: `top` or `htop` - should show ~100% CPU usage
- Wait patiently or increase verbosity: `nextpnr-xilinx --verbose`

### Error 8: "No space left on device"

**Cause:** Disk full

**Solution:**
```bash
# Check disk space
df -h /

# Need >10GB free for tools. Clean up if needed:
rm -rf ~/Downloads/*.tar.gz
rm -rf ~/.cache/pip
```

---

## Quick Reference: All Commands

### Check Installation Status
```bash
riscv64-unknown-elf-gcc --version
yosys --version
nextpnr-xilinx --help | head -3
xc7frames2bit --help | head -3
echo $PRJXRAY_DB
```

### Update All Tools
```bash
sudo apt-get update && sudo apt-get upgrade

# RISC-V GCC - manual (download new version)
# Yosys
yosys --build-update

# NextPNR - rebuild from source if needed
cd ~/fpga-tools/nextpnr/build && make -j$(nproc) && sudo make install

# PRJXRAY - update database
cd ~/FPGA_Compiler-/.tools/prjxray-db && git pull
```

### Common Make Targets
```bash
cd ~/FPGA_Compiler-/app/firmware

make all          # Build firmware
make program      # Build + program FPGA board
make inspect      # View RISC-V disassembly
make clean        # Remove build artifacts
make help         # Show all targets
```

---

## Important Paths Reference

```
Core Tools:
  RISC-V GCC:    ~/fpga-tools/riscv64-glibc-ubuntu-20.04-gcc-12.2.0-binutils-2.39/
  Yosys:         /usr/bin/yosys (if apt-get) or ~/fpga-tools/yosys/
  NextPNR:       /usr/bin/nextpnr-xilinx (if apt-get) or ~/fpga-tools/nextpnr/build/nextpnr-xilinx
  
Configuration:
  Chipdb:        ~/.local/share/nextpnr/xilinx/chipdb-xc7a100t.bin
  PRJXRAY:       ~/FPGA_Compiler-/.tools/prjxray/
  PRJXRAY DB:    ~/FPGA_Compiler-/.tools/prjxray-db/artix7/
  
Project:
  Firmware:      ~/FPGA_Compiler-/app/firmware/
  Source:        ~/FPGA_Compiler-/app/firmware/src/
  Build:         ~/FPGA_Compiler-/app/firmware/build/
```

---

## Next Steps

1. ✅ Complete this setup guide
2. ✅ Run the verification script (Part 8)
3. ✅ Read `/app/firmware/README.md` for build instructions
4. ✅ Create source files in `/app/firmware/src/`
5. ✅ Run `make all` to build
6. ✅ Run `make program` to program the FPGA board

---

## Getting Help

If you encounter errors:

1. **Check this guide** - search for your error message
2. **Check tool documentation:**
   - RISC-V: https://github.com/riscv-collab/riscv-gnu-toolchain
   - Yosys: https://yosyshq.net/
   - NextPNR: https://github.com/YosysHQ/nextpnr
   - PRJXRAY: https://github.com/Project-X-Ray/prjxray

3. **Check build output** - error messages usually indicate what went wrong

Good luck! 🚀
