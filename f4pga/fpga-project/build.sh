#!/bin/bash
# Build script for FPGA designs - supports multiple .sv files

set -e

# Source prjxray environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRJXRAY_ENV="${SCRIPT_DIR}/../prjxray-env.sh"

if [ -f "$PRJXRAY_ENV" ]; then
    source "$PRJXRAY_ENV"
else
    echo "Error: prjxray environment not found at $PRJXRAY_ENV"
    echo "Please run setup first: ./setup-prjxray.sh"
    exit 1
fi

# Default values
PROJECT="test"
TOP=""
CONSTRAINTS=""
BUILD_DIR="build"
SOURCE_DIR="."
SV_FILE=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --top)
            TOP="$2"
            shift 2
            ;;
        --constraints|--contraints)
            CONSTRAINTS="$2"
            shift 2
            ;;
        --project)
            PROJECT="$2"
            shift 2
            ;;
        --source-dir)
            SOURCE_DIR="$2"
            shift 2
            ;;
        --sv-file)
            SV_FILE="$2"
            shift 2
            ;;
        --help)
            echo "Usage: ./build.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --top <name>        Top module name (default: auto-detect from project name)"
            echo "  --constraints <file> Constraints file (default: <project>.xdc or constraints.xdc)"
            echo "  --project <name>    Project name for output bitstream (default: test)"
            echo "  --source-dir <dir>  Directory containing .sv files (default: current directory)"
            echo "  --sv-file <file>    Specific .sv file to build (default: all .sv files)"
            echo "  --help              Show this help"
            echo ""
            echo "Examples:"
            echo "  ./build.sh                                    # Build test.sv with test.xdc"
            echo "  ./build.sh --top main                         # Build all .sv files, top=main"
            echo "  ./build.sh --project myapp --top top_module   # Build myapp.bit with top_module"
            echo "  ./build.sh --source-dir app --top main        # Build from app/ directory"
            echo "  ./build.sh --sv-file test.sv --top test       # Build only test.sv"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Auto-detect top module if not specified
if [ -z "$TOP" ]; then
    TOP="$PROJECT"
fi

# Change to source directory
cd "${SOURCE_DIR}"
echo "Building from directory: $(pwd)"
echo ""

# Auto-detect constraints file if not specified
if [ -z "$CONSTRAINTS" ]; then
    if [ -f "${PROJECT}.xdc" ]; then
        CONSTRAINTS="${PROJECT}.xdc"
    elif [ -f "constraints.xdc" ]; then
        CONSTRAINTS="constraints.xdc"
    else
        echo -e "${RED}Error: No constraints file found. Use --constraints to specify.${NC}"
        exit 1
    fi
fi

PART="xc7a100tcsg324-1"

echo -e "${GREEN}=== FPGA Build Script ===${NC}"
echo "Project: $PROJECT"
echo "Top module: $TOP"
echo "Constraints: $CONSTRAINTS"
echo "Target: Nexys A7-100T ($PART)"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check for yosys
if ! command -v yosys &> /dev/null; then
    echo -e "${RED}Error: yosys not found. Please install yosys.${NC}"
    exit 1
fi
echo "✓ yosys found"

# Check for nextpnr-xilinx
if ! command -v nextpnr-xilinx &> /dev/null; then
    echo -e "${RED}Error: nextpnr-xilinx not found. Please install nextpnr-xilinx.${NC}"
    exit 1
fi
echo "✓ nextpnr-xilinx found"

# Check for prjxray tools
if [ ! -f "${XRAY_FASM2FRAMES}" ]; then
    echo -e "${RED}Error: fasm2frames not found. Please check prjxray setup.${NC}"
    exit 1
fi
if [ ! -f "${XRAY_TOOLS_DIR}/xc7frames2bit" ]; then
    echo -e "${RED}Error: xc7frames2bit not found. Please build prjxray tools.${NC}"
    exit 1
fi
echo "✓ prjxray tools found"

# Clean and create build directory
echo -e "${YELLOW}Cleaning previous build...${NC}"
rm -rf ${BUILD_DIR}
rm -f ${PROJECT}.bit
mkdir -p ${BUILD_DIR}

# Find all .sv and .v files
SV_FILES=$(ls -1 *.sv 2>/dev/null | tr '\n' ' ')
V_FILES=$(ls -1 *.v 2>/dev/null | tr '\n' ' ')
ALL_FILES="${SV_FILES}${V_FILES}"
if [ -z "$ALL_FILES" ]; then
    echo -e "${RED}Error: No .sv or .v files found in current directory.${NC}"
    exit 1
fi

echo "Found Verilog files: ${SV_FILES}${V_FILES}"
echo ""

echo -e "${YELLOW}Step 1: Synthesis with Yosys${NC}"

# Build yosys command to read all .sv and .v files
YOSYS_CMD=""
if [ -n "$SV_FILES" ]; then
    YOSYS_CMD="${YOSYS_CMD}read_verilog -sv ${SV_FILES}; "
fi
if [ -n "$V_FILES" ]; then
    YOSYS_CMD="${YOSYS_CMD}read_verilog ${V_FILES}; "
fi
YOSYS_CMD="${YOSYS_CMD}hierarchy -check -top ${TOP}; synth_xilinx -family xc7 -top ${TOP}; write_json ${BUILD_DIR}/${PROJECT}.json"

yosys -p "${YOSYS_CMD}" 2>&1 | tee ${BUILD_DIR}/yosys.log

echo ""
echo -e "${YELLOW}Step 2: Place and Route with nextpnr-xilinx${NC}"

# Try to find chipdb
CHIPDB_PATHS=(
    "${HOME}/.local/share/nextpnr/xilinx/chipdb-xc7a100t.bin"
    "/usr/share/nextpnr/xilinx/chipdb-xc7a100t.bin"
    "/usr/local/share/nextpnr/xilinx/chipdb-xc7a100t.bin"
)

CHIPDB_FOUND=""
for path in "${CHIPDB_PATHS[@]}"; do
    if [ -f "$path" ]; then
        CHIPDB_FOUND="$path"
        break
    fi
done

if [ -z "$CHIPDB_FOUND" ]; then
    echo -e "${RED}Chipdb file not found. Attempting to download...${NC}"
    
    mkdir -p "${HOME}/.local/share/nextpnr/xilinx"
    
    if wget -q --show-progress -O "${HOME}/.local/share/nextpnr/xilinx/chipdb-xc7a100t.bin" \
        "https://github.com/openXC7/nextpnr-xilinx/releases/download/release-0.5.0/chipdb-xc7a100t.bin" 2>/dev/null; then
        CHIPDB_FOUND="${HOME}/.local/share/nextpnr/xilinx/chipdb-xc7a100t.bin"
        echo -e "${GREEN}Successfully downloaded chipdb!${NC}"
    else
        echo -e "${RED}Failed to download chipdb.${NC}"
        exit 1
    fi
fi

echo "Using chipdb: ${CHIPDB_FOUND}"
echo ""

nextpnr-xilinx \
    --chipdb "${CHIPDB_FOUND}" \
    --json "${BUILD_DIR}/${PROJECT}.json" \
    --xdc "${CONSTRAINTS}" \
    --fasm "${BUILD_DIR}/${PROJECT}.fasm" \
    --verbose 2>&1 | tee ${BUILD_DIR}/nextpnr.log

echo ""
echo -e "${YELLOW}Step 3: Generate FASM to Frames${NC}"
python3 ${XRAY_FASM2FRAMES} --db-root ${XRAY_DATABASE_DIR}/${XRAY_DATABASE} --part ${PART} ${BUILD_DIR}/${PROJECT}.fasm ${BUILD_DIR}/${PROJECT}.frames

echo ""
echo -e "${YELLOW}Step 4: Generate Bitstream${NC}"
${XRAY_TOOLS_DIR}/xc7frames2bit \
    --part_file "${XRAY_PART_YAML}" \
    --part_name "${PART}" \
    --frm_file "${BUILD_DIR}/${PROJECT}.frames" \
    --output_file "${PROJECT}.bit"

echo ""
echo -e "${GREEN}=== Build Complete ===${NC}"
echo "Bitstream generated: ${PROJECT}.bit"
echo ""
echo "To program the FPGA:"
echo "  openFPGALoader -b nexys_a7_100 ${PROJECT}.bit"
