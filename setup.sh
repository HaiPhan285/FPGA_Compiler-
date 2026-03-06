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
    ok "yosys already installed: $(yosys --version 2>&1 | head -1)"
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
        info "Not in apt — downloading pre-built binary from openXC7 releases…"
        NEXTPNR_URL="https://github.com/openXC7/nextpnr-xilinx/releases/download/release-0.5.0/nextpnr-xilinx"
        TMP=$(mktemp)
        if wget -q --show-progress -O "${TMP}" "${NEXTPNR_URL}"; then
            sudo install -m 755 "${TMP}" /usr/local/bin/nextpnr-xilinx
            rm -f "${TMP}"
            ok "nextpnr-xilinx installed to /usr/local/bin/"
        else
            rm -f "${TMP}"
            err "Could not download nextpnr-xilinx automatically."
            echo "  Install manually from: https://github.com/openXC7/nextpnr-xilinx/releases"
            echo "  Then re-run this script."
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
info "Step 8/8 — Downloading nextpnr-xilinx chipdb for XC7A100T"
CHIPDB_DIR="${HOME}/.local/share/nextpnr/xilinx"
CHIPDB_FILE="${CHIPDB_DIR}/chipdb-xc7a100t.bin"
if [ -f "${CHIPDB_FILE}" ]; then
    ok "chipdb already present at ${CHIPDB_FILE}"
else
    mkdir -p "${CHIPDB_DIR}"
    info "Downloading chipdb-xc7a100t.bin (~50 MB)…"
    if wget -q --show-progress \
        -O "${CHIPDB_FILE}" \
        "https://github.com/openXC7/nextpnr-xilinx/releases/download/release-0.5.0/chipdb-xc7a100t.bin"; then
        ok "chipdb downloaded to ${CHIPDB_FILE}"
    else
        rm -f "${CHIPDB_FILE}"
        err "chipdb download failed. Download manually:"
        echo "  mkdir -p ${CHIPDB_DIR}"
        echo "  wget -O ${CHIPDB_FILE} \\"
        echo "    https://github.com/openXC7/nextpnr-xilinx/releases/download/release-0.5.0/chipdb-xc7a100t.bin"
    fi
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
