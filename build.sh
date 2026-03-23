#!/bin/bash
# Build script for FPGA designs - supports multiple .sv files

set -e

# Source prjxray environment
BUILD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRJXRAY_ENV="${BUILD_SCRIPT_DIR}/prjxray-env.sh"

if [ -f "$PRJXRAY_ENV" ]; then
    source "$PRJXRAY_ENV"
else
    echo "Error: prjxray environment not found at $PRJXRAY_ENV"
    echo "Please run setup first: ./setup.sh"
    exit 1
fi

# Default values
PROJECT="test"
TOP=""
CONSTRAINTS=""
BUILD_DIR=""
SOURCE_DIR="."
SV_FILE=""
BUILD_ALL=false
FLASH_MODE=false

project_has_build_inputs() {
    local project_dir="$1"
    find "${project_dir}" -maxdepth 2 -type f \( -name "*.sv" -o -name "*.v" \) -size +0c | grep -q . &&
    find "${project_dir}" -maxdepth 2 -type f -name "*.xdc" -size +0c | grep -q .
}

# If no arguments given, show interactive project selection menu
if [[ $# -eq 0 ]]; then
    APP_DIR="${BUILD_SCRIPT_DIR}/app"
    PROJECTS=()
    while IFS= read -r project_dir; do
        if project_has_build_inputs "${project_dir}"; then
            PROJECTS+=("${project_dir}")
        fi
    done < <(find "$APP_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
    if [ ${#PROJECTS[@]} -eq 0 ]; then
        echo "No buildable projects found in app/"
        exit 1
    fi

    # Pick project
    echo "=== Select a project ==="
    for i in "${!PROJECTS[@]}"; do
        echo "  [$((i+1))] $(basename "${PROJECTS[$i]}")"
    done
    echo "  [a] Build all"
    echo ""
    read -rp "Enter number: " CHOICE
    if [[ "$CHOICE" == "a" ]]; then
        BUILD_ALL=true
    elif [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le ${#PROJECTS[@]} ]; then
        SELECTED_DIR="${PROJECTS[$((CHOICE-1))]}"
        SOURCE_DIR="$SELECTED_DIR"
        PROJECT=$(basename "$SELECTED_DIR")

        # Find all potential top modules (Verilog files)
        # Look in project root and common subdirectories like rtl/
        mapfile -t SRC_FILES < <(find "$SELECTED_DIR" -maxdepth 2 \( -name "*.sv" -o -name "*.v" \) ! -name "gates.v" ! -name "defines.v" ! -name "params.v" | sort)
        
        if [ ${#SRC_FILES[@]} -eq 0 ]; then
             # If filtered list is empty, fall back to all files
             mapfile -t SRC_FILES < <(find "$SELECTED_DIR" -maxdepth 2 \( -name "*.sv" -o -name "*.v" \) | sort)
        fi

        # Filter out empty source files
        NON_EMPTY_SRC=()
        for src in "${SRC_FILES[@]}"; do
            if [ -s "$src" ]; then
                NON_EMPTY_SRC+=("$src")
            fi
        done
        if [ ${#NON_EMPTY_SRC[@]} -eq 0 ] && [ ${#SRC_FILES[@]} -gt 0 ]; then
            echo -e "\033[0;31mError: All .sv/.v files in $PROJECT are empty. Please add your Verilog design before building.\033[0m"
            exit 1
        fi
        SRC_FILES=("${NON_EMPTY_SRC[@]}")

        if [ ${#SRC_FILES[@]} -eq 0 ]; then
             echo "No .sv/.v files found in $PROJECT"
             exit 1
        fi

        # If multiple files exist, ask the user to pick the top module file
        if [ ${#SRC_FILES[@]} -gt 1 ]; then
            echo "Multiple source files found. Select the top module file:"
            for i in "${!SRC_FILES[@]}"; do
                echo "  [$((i+1))] $(basename "${SRC_FILES[$i]}")"
            done
            read -rp "Enter number (default 1): " SRC_CHOICE
            
            if [[ -z "$SRC_CHOICE" ]]; then
                SRC_CHOICE=1
            fi
            
            if [[ "$SRC_CHOICE" =~ ^[0-9]+$ ]] && [ "$SRC_CHOICE" -ge 1 ] && [ "$SRC_CHOICE" -le ${#SRC_FILES[@]} ]; then
                SELECTED_SRC="${SRC_FILES[$((SRC_CHOICE-1))]}"
            else
                echo "Invalid selection."
                exit 1
            fi
        else
            # Only one file, use it
            SELECTED_SRC="${SRC_FILES[0]}"
        fi

        # Auto-detect top module name from the file content
        DETECTED_MODULE=$(grep -oP '^\s*module\s+\K[a-zA-Z_][a-zA-Z0-9_]*' "$SELECTED_SRC" | head -1)
        if [ -n "$DETECTED_MODULE" ]; then
            TOP="$DETECTED_MODULE"
        else
            if [ ! -s "$SELECTED_SRC" ]; then
                echo -e "\033[0;31mError: $(basename "$SELECTED_SRC") is empty. Please add your Verilog design before building.\033[0m"
            else
                echo -e "\033[0;31mError: No 'module' declaration found in $(basename "$SELECTED_SRC"). Please check your Verilog syntax.\033[0m"
            fi
            exit 1
        fi

        # Check that the constraints file has content
        mapfile -t XDC_FILES < <(find "$SELECTED_DIR" -maxdepth 2 -name "*.xdc" | sort)
        # Filter out empty XDC files
        NON_EMPTY_XDC=()
        for xdc in "${XDC_FILES[@]}"; do
            if [ -s "$xdc" ]; then
                NON_EMPTY_XDC+=("$xdc")
            fi
        done
        if [ ${#NON_EMPTY_XDC[@]} -eq 0 ] && [ ${#XDC_FILES[@]} -gt 0 ]; then
            echo -e "\033[0;31mError: All .xdc files in $PROJECT are empty. Please add pin constraints before building.\033[0m"
            exit 1
        fi
        XDC_FILES=("${NON_EMPTY_XDC[@]}")
        
        if [ ${#XDC_FILES[@]} -eq 0 ]; then
             echo "No .xdc file found in $PROJECT"
             exit 1
        fi

        # If multiple XDC files exist, ask the user to pick one
        if [ ${#XDC_FILES[@]} -gt 1 ]; then
            echo "Multiple constraints files found. Select the XDC file:"
            for i in "${!XDC_FILES[@]}"; do
                echo "  [$((i+1))] $(basename "${XDC_FILES[$i]}")"
            done
            read -rp "Enter number (default 1): " XDC_CHOICE
            
            if [[ -z "$XDC_CHOICE" ]]; then
                XDC_CHOICE=1
            fi
            
            if [[ "$XDC_CHOICE" =~ ^[0-9]+$ ]] && [ "$XDC_CHOICE" -ge 1 ] && [ "$XDC_CHOICE" -le ${#XDC_FILES[@]} ]; then
                CONSTRAINTS="${XDC_FILES[$((XDC_CHOICE-1))]}"
            else
                echo "Invalid selection."
                exit 1
            fi
        else
            CONSTRAINTS="${XDC_FILES[0]}"
        fi

        echo ""
        echo "  Design file : ${TOP}.sv / ${TOP}.v"
        echo "  Constraints : $(basename "$CONSTRAINTS")"
    else
        echo "Invalid selection."
        exit 1
    fi
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

run_tool_binary() {
    local tool_bin="$1"
    shift

    if [ -n "${OPENXC7_LD_LIBRARY_PATH:-}" ] && [[ "${tool_bin}" == /snap/openxc7/* ]]; then
        env LD_LIBRARY_PATH="${OPENXC7_LD_LIBRARY_PATH}" "${tool_bin}" "$@"
    else
        "${tool_bin}" "$@"
    fi
}

sanitize_xdc_file() {
    local xdc_file="$1"
    local sanitized_file="${xdc_file}.sanitized"

    perl -0pe 's/\{\s+([^{}]*?)\s+\}/{\1}/g' "${xdc_file}" > "${sanitized_file}"

    if ! cmp -s "${xdc_file}" "${sanitized_file}"; then
        mv "${sanitized_file}" "${xdc_file}"
        echo "  Sanitized XDC brace spacing for nextpnr compatibility"
    else
        rm -f "${sanitized_file}"
    fi
}

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
        --all)
            BUILD_ALL=true
            shift
            ;;
        --flash)
            FLASH_MODE=true
            shift
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
            echo "  --all               Build all projects found in app/ directory"
            echo "  --flash             Select and flash a built project to the FPGA"
            echo "  --help              Show this help"
            echo ""
            echo "Examples:"
            echo "  ./build.sh --all                              # Build all projects in app/"
            echo "  ./build.sh --flash                            # Pick a project to flash"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# When using command-line arguments, populate SRC_FILES from source-dir
if [ -n "$SOURCE_DIR" ] && [ -d "$SOURCE_DIR" ]; then
    # Convert to absolute path if relative
    if [[ "$SOURCE_DIR" != /* ]]; then
        SOURCE_DIR="$(pwd)/$SOURCE_DIR"
    fi
    mapfile -t SRC_FILES < <(find "$SOURCE_DIR" -maxdepth 2 \( -name "*.sv" -o -name "*.v" \) ! -name "gates.v" ! -name "defines.v" ! -name "params.v" | sort)
    # Set SELECTED_DIR for command-line mode
    SELECTED_DIR="$SOURCE_DIR"
    
    # If in command-line mode (TOP specified but SELECTED_SRC not set), find the source file
    if [ -n "$TOP" ] && [ -z "$SELECTED_SRC" ]; then
        for src in "${SRC_FILES[@]}"; do
            basename_src=$(basename "$src" .sv)
            basename_src=$(basename "$basename_src" .v)
            if [ "$basename_src" = "$TOP" ]; then
                SELECTED_SRC="$src"
                break
            fi
        done
    fi
fi

# Convert CONSTRAINTS to absolute path if relative
if [ -n "$CONSTRAINTS" ] && [[ "$CONSTRAINTS" != /* ]]; then
    CONSTRAINTS="$(pwd)/$CONSTRAINTS"
fi

# Build all projects in app/ directory
if [ "$BUILD_ALL" = true ]; then
    APP_DIR="${BUILD_SCRIPT_DIR}/app"
    if [ ! -d "$APP_DIR" ]; then
        echo -e "${RED}Error: No app/ directory found at ${APP_DIR}${NC}"
        exit 1
    fi
    FAILED=()
    for proj_dir in "$APP_DIR"/*/; do
        proj_name=$(basename "$proj_dir")
        if ! project_has_build_inputs "$proj_dir"; then
            echo -e "${YELLOW}=== Skipping ${proj_name}: not a buildable project directory ===${NC}"
            echo ""
            continue
        fi
        echo -e "${GREEN}=== Project: ${proj_name} ===${NC}"

        # Pick source file
        mapfile -t SRC_FILES < <(find "$proj_dir" -maxdepth 2 \( -name "*.sv" -o -name "*.v" \) | sort)
        if [ ${#SRC_FILES[@]} -eq 0 ]; then
            echo -e "${RED}  Skipping ${proj_name}: no .sv/.v source found${NC}"
            FAILED+=("$proj_name")
            continue
        fi
        echo "  Select design file:"
        for i in "${!SRC_FILES[@]}"; do
            echo "    [$((i+1))] $(basename "${SRC_FILES[$i]}")"
        done
        read -rp "  Enter number: " SRC_CHOICE
        if ! [[ "$SRC_CHOICE" =~ ^[0-9]+$ ]] || [ "$SRC_CHOICE" -lt 1 ] || [ "$SRC_CHOICE" -gt ${#SRC_FILES[@]} ]; then
            echo -e "${RED}  Invalid selection, skipping ${proj_name}${NC}"
            FAILED+=("$proj_name")
            continue
        fi
        SELECTED_SRC="${SRC_FILES[$((SRC_CHOICE-1))]}"
        detected_top=$(basename "$SELECTED_SRC" .sv); detected_top=$(basename "$detected_top" .v)

        # Pick constraints file
        mapfile -t XDC_FILES < <(find "$proj_dir" -maxdepth 2 -name "*.xdc" | sort)
        if [ ${#XDC_FILES[@]} -eq 0 ]; then
            echo -e "${RED}  Skipping ${proj_name}: no .xdc constraints found${NC}"
            FAILED+=("$proj_name")
            continue
        fi
        echo "  Select constraints file:"
        for i in "${!XDC_FILES[@]}"; do
            echo "    [$((i+1))] $(basename "${XDC_FILES[$i]}")"
        done
        read -rp "  Enter number: " XDC_CHOICE
        if ! [[ "$XDC_CHOICE" =~ ^[0-9]+$ ]] || [ "$XDC_CHOICE" -lt 1 ] || [ "$XDC_CHOICE" -gt ${#XDC_FILES[@]} ]; then
            echo -e "${RED}  Invalid selection, skipping ${proj_name}${NC}"
            FAILED+=("$proj_name")
            continue
        fi
        detected_xdc=$(basename "${XDC_FILES[$((XDC_CHOICE-1))]}")

        echo "  Top module : $detected_top"
        echo "  Constraints: $detected_xdc"
        echo "  Project    : $proj_name"

        if "$BUILD_SCRIPT_DIR/build.sh" \
            --source-dir "$proj_dir" \
            --top "$detected_top" \
            --constraints "$detected_xdc" \
            --project "$proj_name"; then
            echo -e "${GREEN}  ✓ ${proj_name} built successfully${NC}"
        else
            echo -e "${RED}  ✗ ${proj_name} build FAILED${NC}"
            FAILED+=("$proj_name")
        fi
        echo ""
    done

    echo -e "${GREEN}=== All-project build complete ===${NC}"
    if [ ${#FAILED[@]} -gt 0 ]; then
        echo -e "${RED}Failed projects: ${FAILED[*]}${NC}"
        exit 1
    fi
    exit 0
fi

# Interactive flash: pick a built project and program it to the FPGA
if [ "$FLASH_MODE" = true ]; then
    APP_DIR="${BUILD_SCRIPT_DIR}/app"
    mapfile -t BITS < <(find "$APP_DIR" -name "*.bit" | sort)
    if [ ${#BITS[@]} -eq 0 ]; then
        echo -e "${RED}No built .bit files found. Run ./build.sh --all first.${NC}"
        exit 1
    fi

    echo -e "${GREEN}=== Select a project to flash ===${NC}"
    for i in "${!BITS[@]}"; do
        proj=$(basename "$(dirname "${BITS[$i]}")")
        bit=$(basename "${BITS[$i]}")
        echo "  [$((i+1))] $proj  ($bit)"
    done
    echo ""
    read -rp "Enter number: " CHOICE
    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt ${#BITS[@]} ]; then
        echo -e "${RED}Invalid selection.${NC}"
        exit 1
    fi

    SELECTED="${BITS[$((CHOICE-1))]}"
    echo -e "${GREEN}Flashing: ${SELECTED}${NC}"
    openFPGALoader -b nexys_a7_100 "$SELECTED"
    exit 0
fi

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
NEXTPNR_XILINX_BIN=""
if [ -n "${OPENXC7_SNAP_ROOT:-}" ] && [ -x "${OPENXC7_SNAP_ROOT}/usr/bin/nextpnr-xilinx" ]; then
    # Use the binary inside the snap directly to avoid snap-confine runtime issues.
    NEXTPNR_XILINX_BIN="${OPENXC7_SNAP_ROOT}/usr/bin/nextpnr-xilinx"
else
    NEXTPNR_XILINX_BIN="$(command -v nextpnr-xilinx 2>/dev/null || true)"
    if [ -z "${NEXTPNR_XILINX_BIN}" ] && [ -x "/snap/bin/nextpnr-xilinx" ]; then
        export PATH="/snap/bin:${PATH}"
        NEXTPNR_XILINX_BIN="/snap/bin/nextpnr-xilinx"
    fi
fi
if [ -z "${NEXTPNR_XILINX_BIN}" ]; then
    echo -e "${RED}Error: nextpnr-xilinx not found. Please install nextpnr-xilinx.${NC}"
    exit 1
fi
echo "✓ nextpnr-xilinx found at ${NEXTPNR_XILINX_BIN}"

# Check for prjxray tools
if [ ! -f "${XRAY_FASM2FRAMES}" ]; then
    echo -e "${RED}Error: fasm2frames not found. Please check prjxray setup.${NC}"
    exit 1
fi
if [ ! -x "${XRAY_XC7FRAMES2BIT}" ]; then
    echo -e "${RED}Error: xc7frames2bit not found. Please build prjxray tools.${NC}"
    exit 1
fi
echo "✓ bitstream tools found (${XRAY_SETUP_SOURCE})"

# Clean and create build directory
echo -e "${YELLOW}Cleaning previous build...${NC}"
# Use a temporary directory for build artifacts to keep project folder clean
BUILD_DIR=$(mktemp -d)
echo "Build artifacts will be stored in temporary directory: $BUILD_DIR"

# Copy selected source file and any .v dependencies to build directory
echo -e "${YELLOW}Copying source files...${NC}"
SELECTED_BASENAME=$(basename "$SELECTED_SRC")
SELECTED_NAME="${SELECTED_BASENAME%.*}"
if [ -f "$SELECTED_SRC" ]; then
    cp "$SELECTED_SRC" "$BUILD_DIR/"
    echo "  Copied: $(basename "$SELECTED_SRC")"
fi
# Copy all non-testbench HDL dependencies
for srcfile in "$SOURCE_DIR"/*.sv "$SOURCE_DIR"/*.v; do
    SRCFILE_BASENAME=$(basename "$srcfile")
    SRCFILE_NAME="${SRCFILE_BASENAME%.*}"

    case "${SRCFILE_BASENAME}" in
        tb_*|*_tb.sv|*_tb.v|sim.sv|sim.v)
            continue
            ;;
    esac

    if [ -f "$srcfile" ] && [ "$SRCFILE_BASENAME" != "$SELECTED_BASENAME" ] && [ "$SRCFILE_NAME" != "$SELECTED_NAME" ]; then
        cp "$srcfile" "$BUILD_DIR/"
        echo "  Copied: $SRCFILE_BASENAME"
    fi
done

# Copy hex files to build directory
if [ -n "$SOURCE_DIR" ]; then
    for hex in "$SOURCE_DIR"/*.hex; do
        if [ -f "$hex" ]; then
            cp "$hex" "$BUILD_DIR/"
            echo "  Copied: $(basename "$hex")"
        fi
    done
fi

# Copy constraint file to build directory
if [ -n "$CONSTRAINTS" ] && [ -f "$CONSTRAINTS" ]; then
    CONSTRAINTS_BASENAME=$(basename "$CONSTRAINTS")
    BUILD_CONSTRAINTS="${BUILD_DIR}/${CONSTRAINTS_BASENAME}"
    cp "$CONSTRAINTS" "${BUILD_CONSTRAINTS}"
    sanitize_xdc_file "${BUILD_CONSTRAINTS}"
    CONSTRAINTS="${BUILD_CONSTRAINTS}"
    echo "  Copied: $(basename "$CONSTRAINTS")"
fi

# Function to cleanup on exit
cleanup() {
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        echo "Removing temporary build directory..."
        rm -rf "$BUILD_DIR"
    else
        echo "Build failed. Artifacts preserved in $BUILD_DIR for debugging."
    fi
    if [ -n "${SELECTED_DIR}" ] && [ -f "${BUILD_DIR}/${PROJECT}.bit" ]; then
        cp "${BUILD_DIR}/${PROJECT}.bit" "${SELECTED_DIR}/"
    fi
    exit $EXIT_CODE
}
trap cleanup EXIT

# Change to build directory
cd "$BUILD_DIR"

rm -f "${PROJECT}.bit"

# Find all .sv and .v files, excluding testbench/simulation files
SV_FILES=$(ls -1 *.sv 2>/dev/null | grep -v -E '^(tb_.*|.*_tb\.sv|sim\.sv)$' | tr '\n' ' ')
V_FILES=$(ls -1 *.v 2>/dev/null | grep -v -E '^(tb_.*|.*_tb\.v|sim\.v)$' | tr '\n' ' ')
ALL_FILES="${SV_FILES}${V_FILES}"
if [ -z "$ALL_FILES" ]; then
    echo -e "${RED}Error: No .sv or .v files found in current directory.${NC}"
    exit 1
fi

echo "Found Verilog files: ${SV_FILES}${V_FILES}"
echo ""

echo -e "${YELLOW}Step 1: Synthesis with Yosys${NC}"

# Build yosys command to read selected source file and any HDL dependencies
SELECTED_BASENAME=$(basename "$SELECTED_SRC")
SELECTED_NAME="${SELECTED_BASENAME%.*}"
SV_FILES=$(ls -1 *.sv 2>/dev/null | grep -v -E '^(tb_.*|.*_tb\.sv|sim\.sv)$' | grep -v "^${SELECTED_BASENAME}$" | grep -v "^${SELECTED_NAME}.sv$" | tr '\n' ' ')
V_FILES=$(ls -1 *.v 2>/dev/null | grep -v -E '^(tb_.*|.*_tb\.v|sim\.v)$' | grep -v "^${SELECTED_BASENAME}$" | grep -v "^${SELECTED_NAME}.v$" | tr '\n' ' ')
YOSYS_CMD="read_verilog -sv ${SELECTED_BASENAME}"
if [ -n "$SV_FILES" ]; then
    YOSYS_CMD="${YOSYS_CMD}; read_verilog -sv ${SV_FILES}"
fi
if [ -n "$V_FILES" ]; then
    YOSYS_CMD="${YOSYS_CMD}; read_verilog ${V_FILES}"
fi
YOSYS_CMD="${YOSYS_CMD}; hierarchy -check -top ${TOP}; synth_xilinx -family xc7 -top ${TOP}; write_json \"${BUILD_DIR}/${PROJECT}.json\""

yosys -p "${YOSYS_CMD}" 2>&1 | tee ${BUILD_DIR}/yosys.log

if [ ! -f "${BUILD_DIR}/${PROJECT}.json" ]; then
    echo -e "${RED}Error: Synthesis failed. Check yosys.log for details.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 2: Place and Route with nextpnr-xilinx${NC}"

# Try to find chipdb
CHIPDB_PATHS=(
    "${HOME}/.local/share/nextpnr/xilinx/chipdb-xc7a100t.bin"
    "/usr/share/nextpnr/xilinx/chipdb-xc7a100t.bin"
    "/usr/local/share/nextpnr/xilinx/chipdb-xc7a100t.bin"
)

# Also check snap directory
if [ -d "/snap/openxc7" ]; then
    SNAP_CHIPDB=$(find /snap/openxc7 -name "xc7a100t*.bin" 2>/dev/null | head -1 || true)
    if [ -n "${SNAP_CHIPDB}" ]; then
        CHIPDB_PATHS+=("${SNAP_CHIPDB}")
    fi
fi

CHIPDB_FOUND=""
for path in "${CHIPDB_PATHS[@]}"; do
    if [ -f "$path" ]; then
        CHIPDB_FOUND="$path"
        break
    fi
done

if [ -z "$CHIPDB_FOUND" ]; then
    OPENXC7_SNAP_ROOT=""
    for snap_root in "/snap/openxc7/current" "/snap/openxc7/x1"; do
        if [ -f "${snap_root}/opt/nextpnr-xilinx/python/bbaexport.py" ] && \
           [ -x "${snap_root}/usr/bin/bbasm" ]; then
            OPENXC7_SNAP_ROOT="${snap_root}"
            break
        fi
    done

    if [ -n "${OPENXC7_SNAP_ROOT}" ]; then
        CHIPDB_CACHE_DIR="${HOME}/.local/share/nextpnr/xilinx"
        CHIPDB_GENERATED="${CHIPDB_CACHE_DIR}/chipdb-xc7a100t.bin"
        CHIPDB_BBA="${BUILD_DIR}/chipdb-xc7a100t.bba"

        mkdir -p "${CHIPDB_CACHE_DIR}"

        if [ ! -f "${CHIPDB_GENERATED}" ]; then
            echo "Chipdb file not found. Generating it from the installed openXC7 snap..."
            echo "This can take a few minutes and only needs to be done once."

            python3 "${OPENXC7_SNAP_ROOT}/opt/nextpnr-xilinx/python/bbaexport.py" \
                --device "${PART}" \
                --bba "${CHIPDB_BBA}"

            "${OPENXC7_SNAP_ROOT}/usr/bin/bbasm" -l "${CHIPDB_BBA}" "${CHIPDB_GENERATED}"
            rm -f "${CHIPDB_BBA}"
        fi

        if [ -f "${CHIPDB_GENERATED}" ]; then
            CHIPDB_FOUND="${CHIPDB_GENERATED}"
        fi
    fi
fi

if [ -z "$CHIPDB_FOUND" ]; then
    echo -e "${RED}Chipdb file not found. The chipdb should be bundled with the openXC7 snap package.${NC}"
    echo -e "${YELLOW}If openXC7 is already installed, generate it once with:${NC}"
    echo "  mkdir -p ~/.local/share/nextpnr/xilinx"
    echo "  python3 /snap/openxc7/current/opt/nextpnr-xilinx/python/bbaexport.py \\"
    echo "    --device ${PART} --bba /tmp/chipdb-xc7a100t.bba"
    echo "  /snap/openxc7/current/usr/bin/bbasm -l /tmp/chipdb-xc7a100t.bba \\"
    echo "    ~/.local/share/nextpnr/xilinx/chipdb-xc7a100t.bin"
    echo ""
    echo "Or if you have nextpnr-xilinx installed, please ensure the chipdb is available."
    exit 1
fi

echo "Using chipdb: ${CHIPDB_FOUND}"
echo ""

run_tool_binary "${NEXTPNR_XILINX_BIN}" \
    --chipdb "${CHIPDB_FOUND}" \
    --json "${BUILD_DIR}/${PROJECT}.json" \
    --xdc "${CONSTRAINTS}" \
    --fasm "${BUILD_DIR}/${PROJECT}.fasm" \
    --verbose 2>&1 | tee ${BUILD_DIR}/nextpnr.log

if [ ! -f "${BUILD_DIR}/${PROJECT}.fasm" ]; then
    if grep -q "Assertion failure: str.back() == '}'" "${BUILD_DIR}/nextpnr.log" 2>/dev/null; then
        echo -e "${YELLOW}Hint:${NC} nextpnr-xilinx rejected the XDC syntax. Remove spaces directly inside braces, e.g. use {clk} instead of { clk }."
    fi
    echo -e "${RED}Error: Place and route failed. Check nextpnr.log for details.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 3: Generate FASM to Frames${NC}"
if [ "${XRAY_FASM2FRAMES_MODE}" = "exec" ]; then
    run_tool_binary "${XRAY_FASM2FRAMES}" --db-root "${XRAY_DATABASE_DIR}/${XRAY_DATABASE}" --part "${PART}" "${BUILD_DIR}/${PROJECT}.fasm" "${BUILD_DIR}/${PROJECT}.frames"
else
    python3 "${XRAY_FASM2FRAMES}" --db-root "${XRAY_DATABASE_DIR}/${XRAY_DATABASE}" --part "${PART}" "${BUILD_DIR}/${PROJECT}.fasm" "${BUILD_DIR}/${PROJECT}.frames"
fi

echo ""
echo -e "${YELLOW}Step 4: Generate Bitstream${NC}"
run_tool_binary "${XRAY_XC7FRAMES2BIT}" \
    --part_file "${XRAY_PART_YAML}" \
    --part_name "${PART}" \
    --frm_file "${BUILD_DIR}/${PROJECT}.frames" \
    --output_file "${PROJECT}.bit"

echo ""
echo -e "${GREEN}=== Build Complete ===${NC}"

# Copy bitstream to project directory
if [ -n "${SELECTED_DIR}" ]; then
    cp "${BUILD_DIR}/${PROJECT}.bit" "${SELECTED_DIR}/"
    echo "Bitstream saved to: ${SELECTED_DIR}/${PROJECT}.bit"
else
    cp "${BUILD_DIR}/${PROJECT}.bit" "${SOURCE_DIR}/"
    echo "Bitstream saved to: ${SOURCE_DIR}/${PROJECT}.bit"
fi
echo ""
echo "To program the FPGA:"
echo "  openFPGALoader -b nexys_a7_100 \"${SELECTED_DIR}/${PROJECT}.bit\""
