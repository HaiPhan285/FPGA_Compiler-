#!/bin/bash
# Setup script for prjxray - Project X-Ray for Xilinx 7-series bitstream tools

set -e

echo "=== Setting up prjxray for Nexys A7-100T ==="

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if prjxray already exists
if [ -d "${SCRIPT_DIR}/.tools/prjxray" ]; then
    echo "prjxray directory already exists. Updating..."
    cd "${SCRIPT_DIR}/.tools/prjxray"
    git pull
else
    echo "Cloning prjxray repository..."
    mkdir -p "${SCRIPT_DIR}/.tools"
    cd "${SCRIPT_DIR}/.tools"
    git clone https://github.com/f4pga/prjxray.git
    cd prjxray
fi

echo ""
echo "=== Installing dependencies ==="
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    cmake \
    python3 \
    python3-pip \
    python3-venv \
    git \
    libffi-dev \
    libssl-dev \
    libboost-all-dev \
    libyaml-cpp-dev \
    flex \
    bison \
    clang-format-5.0 \
    openFPGALoader \
    libftdi1-dev \
    libhidapi-dev \
    libusb-1.0-0-dev

echo ""
echo "=== Checking for additional tools ==="
if ! command -v openFPGALoader &> /dev/null; then
    echo "Installing openFPGALoader..."
    sudo apt-get install -y openFPGALoader || echo "Warning: openFPGALoader installation failed. Please install manually."
else
    echo "openFPGALoader found."
fi

if ! command -v nextpnr-xilinx &> /dev/null; then
    echo "Warning: nextpnr-xilinx not found. Please install it."
    echo "Example: sudo apt-get install nextpnr-xilinx (if available) or build from source."
else
    echo "nextpnr-xilinx found."
fi

echo ""
echo "=== Setting up Python environment ==="
python3 -m venv "${SCRIPT_DIR}/.tools/env"
source "${SCRIPT_DIR}/.tools/env/bin/activate"

echo ""
echo "=== Installing Python dependencies ==="
pip install --upgrade pip
pip install -r requirements.txt

echo ""
echo "=== Building prjxray tools ==="
make build

echo ""
echo "=== Downloading pre-built database (faster than building) ==="
# Download the latest database instead of building it
mkdir -p "${SCRIPT_DIR}/.tools/prjxray-db"
cd "${SCRIPT_DIR}/.tools/prjxray-db"
if [ ! -d "artix7" ]; then
    echo "Downloading artix7 database..."
    # Download database from GitHub releases
    wget -q --show-progress -O database.tar.gz \
        "https://github.com/f4pga/prjxray-db/releases/download/latest/database.tar.gz" || \
    wget -q --show-progress -O database.tar.gz \
        "https://storage.googleapis.com/prjxray-db/database.tar.gz"
    
    tar -xzf database.tar.gz
    rm database.tar.gz
fi

echo ""
echo "=== Setting up nextpnr-xilinx chipdb ==="
CHIPDB_DIR="${HOME}/.local/share/nextpnr/xilinx"
CHIPDB_FILE="${CHIPDB_DIR}/chipdb-xc7a100t.bin"

if [ ! -f "$CHIPDB_FILE" ]; then
    echo "Downloading chipdb for XC7A100T..."
    mkdir -p "$CHIPDB_DIR"
    wget -q --show-progress -O "$CHIPDB_FILE" \
        "https://github.com/openXC7/nextpnr-xilinx/releases/download/release-0.5.0/chipdb-xc7a100t.bin" || \
    echo "Warning: Failed to download chipdb. You may need to install it manually."
else
    echo "chipdb already exists at $CHIPDB_FILE"
fi

echo ""
echo "=== Setup complete! ==="
echo ""
echo "To use prjxray tools, run:"
echo "  source ${SCRIPT_DIR}/prjxray-env.sh"
echo ""
echo "Or add this line to your ~/.bashrc:"
echo "  source ${SCRIPT_DIR}/prjxray-env.sh"
