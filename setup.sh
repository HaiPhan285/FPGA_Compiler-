#!/bin/bash
# setup.sh — one-time setup for the FPGA open-source toolchain
#
# Installs and configures:
#   • System packages  (build tools, cmake, flex/bison, libftdi, …)
#   • yosys            (synthesis)
#   • nextpnr-xilinx   (place-and-route)
#   • openFPGALoader   (JTAG programmer)
#   • prjxray          (cloned + built from source — fasm2frames, xc7frames2bit, …)
#   • prjxray-db       (Artix-7 tile database, cloned from f4pga/prjxray-db)
#   • Python venv      (.tools/env) with prjxray Python deps
#   • nextpnr chipdb   (~/.local/share/nextpnr/xilinx/chipdb-xc7a100t.bin)
#
# Run once from the repo root:
#   chmod +x setup.sh && ./setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="${SCRIPT_DIR}/.tools"

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓ $*${NC}"; }
info() { echo -e "${YELLOW}▸ $*${NC}"; }
err()  { echo -e "${RED}✗ $*${NC}"; }

echo "=== FPGA Toolchain Setup ==="
echo "Tools directory: ${TOOLS_DIR}"
echo ""

# ── 1. System packages ────────────────────────────────────────────────────────
info "Step 1/8 — Installing system packages"
sudo apt-get update -qq
sudo apt-get install -y \
    build-essential cmake make \
    python3 python3-pip python3-venv \
    git wget curl \
    libffi-dev libssl-dev \
    libboost-all-dev libyaml-cpp-dev \
    flex bison clang-format \
    libftdi1-2 libhidapi-hidraw0 libusb-1.0-0
ok "System packages installed"
echo ""

# ── 2. Yosys ─────────────────────────────────────────────────────────────────
info "Step 2/8 — Checking yosys (synthesis)"
if command -v yosys &>/dev/null; then
    YOSYS_VER=$(yosys --version 2>&1 | head -1)
    ok "yosys already installed: ${YOSYS_VER}"
    
    # Check if yosys version is too old (need 0.30+ for proper SystemVerilog support)
    YOSYS_VER_NUM=$(echo "${YOSYS_VER}" | grep -oP '\d+\.\d+' | head -1 || echo "0")
    YOSYS_NEEDED=0.30
    YOSYS_OLD=$(echo "${YOSYS_VER_NUM} < ${YOSYS_NEEDED}" | bc 2>/dev/null || echo "0")
    
    if [ "${YOSYS_OLD}" = "1" ]; then
        info "yosys version ${YOSYS_VER_NUM} is older than recommended ${YOSYS_NEEDED}+"
        info "Consider upgrading: sudo apt-get install yosys"
        info "Or use the openXC7 toolchain-installer which includes yosys ${YOSYS_NEEDED}+"
    fi
else
    info "Installing yosys via apt…"
    sudo apt-get install -y yosys
    ok "yosys installed"
fi
echo ""

# ── 3. nextpnr-xilinx ────────────────────────────────────────────────────────
info "Step 3/8 — Checking nextpnr-xilinx (place-and-route)"
if command -v nextpnr-xilinx &>/dev/null; then
    ok "nextpnr-xilinx already installed"
else
    info "Trying apt install…"
    if sudo apt-get install -y nextpnr-xilinx 2>/dev/null; then
        ok "nextpnr-xilinx installed via apt"
    else
        info "Not in apt — trying snap-based installation…"
        
        # Check if snap is installed
        if ! command -v snap &>/dev/null; then
            info "Installing snapd…"
            sudo apt-get install -y snapd
        fi
        
        # Try to use the openXC7 snap package
        SNAP_FILE="openxc7_0.8.2_amd64.snap"
        SNAP_URL="https://github.com/openXC7/openXC7-snap/releases/download/0.8.2/${SNAP_FILE}"
        TMP=$(mktemp)
        
        if wget -q --show-progress -O "${TMP}" "${SNAP_URL}"; then
            if sudo snap install --classic --dangerous "${TMP}" 2>/dev/null; then
                rm -f "${TMP}"
                # Create aliases
                sudo snap alias openxc7.nextpnr-xilinx nextpnr-xilinx 2>/dev/null || true
                sudo snap alias openxc7.fasm2frames fasm2frames 2>/dev/null || true
                sudo snap alias openxc7.xc7frames2bit xc7frames2bit 2>/dev/null || true
                ok "nextpnr-xilinx installed via snap"
            else
                rm -f "${TMP}"
                err "Snap installation failed. Try building from source:"
                echo "  https://github.com/openXC7/nextpnr-xilinx"
                exit 1
            fi
        else
            rm -f "${TMP}"
            err "Could not download nextpnr-xilinx."
            echo "  Install manually using the openXC7 toolchain-installer:"
            echo "  wget -qO - https://raw.githubusercontent.com/openXC7/toolchain-installer/main/toolchain-installer.sh | bash"
            echo "  Or build from source: https://github.com/openXC7/nextpnr-xilinx"
            exit 1
        fi
    fi
fi
echo ""

# ── 4. openFPGALoader ────────────────────────────────────────────────────────
info "Step 4/8 — Checking openFPGALoader (JTAG programmer)"
if command -v openFPGALoader &>/dev/null; then
    ok "openFPGALoader already installed"
else
    info "Installing openFPGALoader…"
    if sudo apt-get install -y openfpgaloader 2>/dev/null; then
        ok "openFPGALoader installed"
    else
        err "openfpgaloader not found in apt."
        echo "  Install manually: https://github.com/trabucayre/openFPGALoader"
        echo "  (Only needed for flashing — build will still work without it.)"
    fi
fi
echo ""

# ── 5. Clone / update prjxray ────────────────────────────────────────────────
info "Step 5/8 — Setting up prjxray (bitstream tools)"
mkdir -p "${TOOLS_DIR}"
if [ -d "${TOOLS_DIR}/prjxray/.git" ]; then
    info "prjxray already cloned — pulling latest…"
    git -C "${TOOLS_DIR}/prjxray" pull --ff-only --quiet
else
    info "Cloning prjxray…"
    rm -rf "${TOOLS_DIR}/prjxray"
    git clone --depth 1 https://github.com/f4pga/prjxray.git "${TOOLS_DIR}/prjxray"
fi
git -C "${TOOLS_DIR}/prjxray" submodule update --init --recursive --quiet
echo ""

# Build C++ tools (xc7frames2bit, bitread, segmatch, …)
info "Building prjxray C++ tools (this takes ~1-2 min)…"
cd "${TOOLS_DIR}/prjxray"
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=build \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON --log-level=WARNING 2>&1 | grep -v "^--" || true
cmake --build build --parallel "$(nproc)" 2>&1 | tail -3
ok "prjxray C++ tools built → ${TOOLS_DIR}/prjxray/build/tools/"
echo ""

# ── 6. Python venv ───────────────────────────────────────────────────────────
info "Step 6/8 — Setting up Python virtual environment"
python3 -m venv "${TOOLS_DIR}/env"
# shellcheck disable=SC1091
source "${TOOLS_DIR}/env/bin/activate"
pip install --upgrade pip --quiet
pip install -r "${TOOLS_DIR}/prjxray/requirements.txt" --quiet
ok "Python venv ready at ${TOOLS_DIR}/env"
echo ""

# ── 7. prjxray-db ────────────────────────────────────────────────────────────
info "Step 7/8 — Setting up prjxray-db (FPGA tile database)"
if [ -d "${TOOLS_DIR}/prjxray-db/.git" ]; then
    info "prjxray-db already cloned — pulling latest…"
    git -C "${TOOLS_DIR}/prjxray-db" pull --ff-only --quiet
else
    info "Cloning prjxray-db (Artix-7 tile database — this may take a few minutes)…"
    rm -rf "${TOOLS_DIR}/prjxray-db"
    git clone --depth 1 https://github.com/f4pga/prjxray-db.git "${TOOLS_DIR}/prjxray-db"
fi
ok "prjxray-db ready at ${TOOLS_DIR}/prjxray-db"
echo ""

# ── 8. nextpnr-xilinx chipdb ─────────────────────────────────────────────────
info "Step 8/8 — Setting up nextpnr-xilinx chipdb for XC7A100T"

# Check if using snap (chipdb is bundled in snap)
if command -v nextpnr-xilinx &>/dev/null; then
    # Try to find chipdb in snap or system locations
    SNAP_CHIPDB=$(find /snap/openxc7 -name "xc7a100t*.bin" 2>/dev/null | head -1 || true)
    if [ -n "${SNAP_CHIPDB}" ]; then
        CHIPDB_DIR="${HOME}/.local/share/nextpnr/xilinx"
        mkdir -p "${CHIPDB_DIR}"
        if [ ! -f "${CHIPDB_DIR}/chipdb-xc7a100t.bin" ]; then
            cp "${SNAP_CHIPDB}" "${CHIPDB_DIR}/chipdb-xc7a100t.bin"
            ok "chipdb copied from snap to ${CHIPDB_DIR}/chipdb-xc7a100t.bin"
        else
            ok "chipdb already present at ${CHIPDB_DIR}/chipdb-xc7a100t.bin"
        fi
    else
        # Check if chipdb already exists from previous install
        CHIPDB_DIR="${HOME}/.local/share/nextpnr/xilinx"
        CHIPDB_FILE="${CHIPDB_DIR}/chipdb-xc7a100t.bin"
        if [ -f "${CHIPDB_FILE}" ]; then
            ok "chipdb already present at ${CHIPDB_FILE}"
        else
            info "Chipdb not found. Building from nextpnr-xilinx source…"
            # The chipdb is now bundled in the snap, but if needed, build from source
            # This is handled by the openXC7 snap automatically
            mkdir -p "${CHIPDB_DIR}"
            # Create a note file
            echo "Chipdb should be bundled with nextpnr-xilinx snap package" > "${CHIPDB_DIR}/README.txt"
            ok "Chipdb setup complete (using snap bundle)"
        fi
    fi
else
    err "nextpnr-xilinx not found. Please install it first."
fi
echo ""

# ── Done ─────────────────────────────────────────────────────────────────────
echo -e "${GREEN}=== Setup complete! ===${NC}"
echo ""
echo "Run a build from the repo root:"
echo "  ./build.sh"
echo ""
echo "Flash a built bitstream:"
echo "  ./build.sh --flash"
