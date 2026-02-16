#!/bin/bash
# Setup script for prjxray - Project X-Ray for Xilinx 7-series bitstream tools

set -e

echo "=== Setting up prjxray for Nexys A7-100T ==="

# Check if prjxray already exists
if [ -d "/home/hai/f4pga/prjxray" ]; then
    echo "prjxray directory already exists. Updating..."
    cd /home/hai/f4pga/prjxray
    git pull
else
    echo "Cloning prjxray repository..."
    cd /home/hai/f4pga
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
    clang-format-5.0

echo ""
echo "=== Setting up Python environment ==="
python3 -m venv env
source env/bin/activate

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
mkdir -p database
if [ ! -d "database/artix7" ]; then
    echo "Downloading artix7 database..."
    # Download database from GitHub releases
    wget -q --show-progress -O database.tar.gz \
        "https://github.com/f4pga/prjxray-db/releases/download/latest/database.tar.gz" || \
    wget -q --show-progress -O database.tar.gz \
        "https://storage.googleapis.com/prjxray-db/database.tar.gz"
    
    tar -xzf database.tar.gz -C database/
    rm database.tar.gz
fi

echo ""
echo "=== Setup complete! ==="
echo ""
echo "To use prjxray tools, run:"
echo "  source /home/hai/f4pga/prjxray/utils/environment.sh"
echo ""
echo "Or add this line to your ~/.bashrc:"
echo "  source /home/hai/f4pga/prjxray/utils/environment.sh"
