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
PROJECT_SET_BY_USER=false
TOP_SET_BY_USER=false
CONSTRAINTS_SET_BY_USER=false

is_excluded_source_file() {
    local basename="$1"
    case "${basename}" in
        tb_*|*_tb.sv|*_tb.v|sim.sv|sim.v|gates.v|defines.v|params.v)
            return 0
            ;;
    esac
    return 1
}

list_project_sources() {
    local project_dir="$1"
    while IFS= read -r src; do
        if [ -s "${src}" ] && ! is_excluded_source_file "$(basename "${src}")"; then
            echo "${src}"
        fi
    done < <(find "${project_dir}" -maxdepth 1 -type f \( -name "*.sv" -o -name "*.v" \) | sort)
}

list_project_constraints() {
    local project_dir="$1"
    find "${project_dir}" -maxdepth 1 -type f -name "*.xdc" -size +0c | sort
}

detect_module_name() {
    local src_file="$1"
    grep -oP '^\s*module\s+\K[a-zA-Z_][a-zA-Z0-9_]*' "${src_file}" | head -1
}

project_has_build_inputs() {
    list_project_sources "${1}" | grep -q . &&
    list_project_constraints "${1}" | grep -q .
}

recommend_source_file() {
    local project_dir="$1"
    local project_name="$2"
    local candidate
    mapfile -t src_files < <(list_project_sources "${project_dir}")

    if [ ${#src_files[@]} -eq 0 ]; then
        return 1
    fi

    for candidate in "top.sv" "top.v" "${project_name}.sv" "${project_name}.v" "main.sv" "main.v"; do
        for src in "${src_files[@]}"; do
            if [ "$(basename "${src}")" = "${candidate}" ]; then
                printf '%s\n' "${src}"
                return 0
            fi
        done
    done

    if [ ${#src_files[@]} -eq 1 ]; then
        printf '%s\n' "${src_files[0]}"
        return 0
    fi

    return 1
}

prompt_for_source_file() {
    local project_dir="$1"
    mapfile -t src_files < <(list_project_sources "${project_dir}")

    if [ ${#src_files[@]} -eq 0 ]; then
        return 1
    fi

    if [ ${#src_files[@]} -eq 1 ]; then
        printf '%s\n' "${src_files[0]}"
        return 0
    fi

    echo "Multiple source files found. Select the top module file:"
    for i in "${!src_files[@]}"; do
        echo "  [$((i+1))] $(basename "${src_files[$i]}")"
    done
    read -rp "Enter number (default 1): " SRC_CHOICE
    if [[ -z "${SRC_CHOICE}" ]]; then
        SRC_CHOICE=1
    fi

    if [[ "${SRC_CHOICE}" =~ ^[0-9]+$ ]] && [ "${SRC_CHOICE}" -ge 1 ] && [ "${SRC_CHOICE}" -le ${#src_files[@]} ]; then
        printf '%s\n' "${src_files[$((SRC_CHOICE-1))]}"
        return 0
    fi

    return 1
}

recommend_constraints_file() {
    local project_dir="$1"
    local selected_src="$2"
    local project_name="$3"
    local selected_base
    local candidate
    mapfile -t xdc_files < <(list_project_constraints "${project_dir}")

    if [ ${#xdc_files[@]} -eq 0 ]; then
        return 1
    fi

    if [ -n "${selected_src}" ]; then
        selected_base="$(basename "${selected_src}")"
        selected_base="${selected_base%.*}"
    else
        selected_base=""
    fi

    for candidate in "${selected_base}.xdc" "${project_name}.xdc" "constraints.xdc" "top.xdc"; do
        if [ "${candidate}" = ".xdc" ]; then
            continue
        fi
        for xdc in "${xdc_files[@]}"; do
            if [ "$(basename "${xdc}")" = "${candidate}" ]; then
                printf '%s\n' "${xdc}"
                return 0
            fi
        done
    done

    if [ ${#xdc_files[@]} -eq 1 ]; then
        printf '%s\n' "${xdc_files[0]}"
        return 0
    fi

    return 1
}

prompt_for_constraints_file() {
    local project_dir="$1"
    mapfile -t xdc_files < <(list_project_constraints "${project_dir}")

    if [ ${#xdc_files[@]} -eq 0 ]; then
        return 1
    fi

    if [ ${#xdc_files[@]} -eq 1 ]; then
        printf '%s\n' "${xdc_files[0]}"
        return 0
    fi

    echo "Multiple constraints files found. Select the XDC file:"
    for i in "${!xdc_files[@]}"; do
        echo "  [$((i+1))] $(basename "${xdc_files[$i]}")"
    done
    read -rp "Enter number (default 1): " XDC_CHOICE
    if [[ -z "${XDC_CHOICE}" ]]; then
        XDC_CHOICE=1
    fi

    if [[ "${XDC_CHOICE}" =~ ^[0-9]+$ ]] && [ "${XDC_CHOICE}" -ge 1 ] && [ "${XDC_CHOICE}" -le ${#xdc_files[@]} ]; then
        printf '%s\n' "${xdc_files[$((XDC_CHOICE-1))]}"
        return 0
    fi

    return 1
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

        SELECTED_SRC="$(recommend_source_file "${SELECTED_DIR}" "${PROJECT}" || true)"
        if [ -z "${SELECTED_SRC}" ]; then
            SELECTED_SRC="$(prompt_for_source_file "${SELECTED_DIR}" || true)"
        fi
        if [ -z "${SELECTED_SRC}" ]; then
            echo -e "\033[0;31mError: No usable .sv/.v files found in ${PROJECT}.\033[0m"
            exit 1
        fi

        DETECTED_MODULE="$(detect_module_name "${SELECTED_SRC}")"
        if [ -n "${DETECTED_MODULE}" ]; then
            TOP="${DETECTED_MODULE}"
        else
            if [ ! -s "${SELECTED_SRC}" ]; then
                echo -e "\033[0;31mError: $(basename "${SELECTED_SRC}") is empty. Please add your Verilog design before building.\033[0m"
            else
                echo -e "\033[0;31mError: No 'module' declaration found in $(basename "${SELECTED_SRC}"). Please check your Verilog syntax.\033[0m"
            fi
            exit 1
        fi

        CONSTRAINTS="$(recommend_constraints_file "${SELECTED_DIR}" "${SELECTED_SRC}" "${PROJECT}" || true)"
        if [ -z "${CONSTRAINTS}" ]; then
            CONSTRAINTS="$(prompt_for_constraints_file "${SELECTED_DIR}" || true)"
        fi
        if [ -z "${CONSTRAINTS}" ]; then
            echo -e "\033[0;31mError: No usable .xdc file found in ${PROJECT}.\033[0m"
            exit 1
        fi

        echo ""
        echo "  Design file : $(basename "${SELECTED_SRC}")"
        echo "  Top module  : ${TOP}"
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

    python3 - "${xdc_file}" "${sanitized_file}" <<'PY'
import re
import sys

src_path, dst_path = sys.argv[1:3]

brace_space_re = re.compile(r'\{\s+([^{}]*?)\s+\}')
set_property_dict_re = re.compile(
    r'^(?P<indent>\s*)set_property\s+-dict\s+\{(?P<dict>[^}]*)\}\s+'
    r'(?P<target>\[(?:get_ports|get_nets)\s+(?:\{[^}]+\}|[^\s\[\]]+)\])\s*;?\s*$'
)
create_clock_re = re.compile(
    r'^(?P<indent>\s*)create_clock\b(?P<body>.*?)(?P<target>\[(?:get_ports|get_nets)\s+(?:\{[^}]+\}|[^\s\[\]]+)\])\s*;?\s*$'
)
period_re = re.compile(r'-period\s+([0-9]+(?:\.[0-9]+)?)')

changed = False
out_lines = []

with open(src_path, "r", encoding="utf-8") as fh:
    for raw_line in fh:
        line = raw_line.rstrip("\n")
        sanitized_line = brace_space_re.sub(r'{\1}', line)

        match = set_property_dict_re.match(sanitized_line)
        if match:
            dict_tokens = match.group("dict").split()
            if len(dict_tokens) >= 2 and len(dict_tokens) % 2 == 0:
                indent = match.group("indent")
                target = match.group("target")
                for prop, value in zip(dict_tokens[0::2], dict_tokens[1::2]):
                    out_lines.append(f"{indent}set_property {prop} {value} {target}\n")
                if sanitized_line != line or len(dict_tokens) > 2:
                    changed = True
                continue

        clock_match = create_clock_re.match(sanitized_line)
        if clock_match and "-period" in clock_match.group("body"):
            period_match = period_re.search(clock_match.group("body"))
            if period_match:
                simplified = (
                    f"{clock_match.group('indent')}create_clock -period "
                    f"{period_match.group(1)} {clock_match.group('target')}"
                )
                out_lines.append(simplified + "\n")
                if simplified != line:
                    changed = True
                continue

        out_lines.append(sanitized_line + "\n")
        if sanitized_line != line:
            changed = True

with open(dst_path, "w", encoding="utf-8") as fh:
    fh.writelines(out_lines)
PY

    if ! cmp -s "${xdc_file}" "${sanitized_file}"; then
        mv "${sanitized_file}" "${xdc_file}"
        echo "  Normalized XDC for nextpnr compatibility"
    else
        rm -f "${sanitized_file}"
    fi
}

print_log_errors() {
    local logfile="$1"
    local title="$2"
    local log_excerpt

    if [ ! -f "${logfile}" ]; then
        return 0
    fi

    log_excerpt="$(grep -E '(^ERROR:|Assertion failure|Traceback|^fatal:|^FATAL:)' "${logfile}" | tail -20 || true)"
    if [ -n "${log_excerpt}" ]; then
        echo ""
        echo -e "${YELLOW}${title}${NC}"
        printf '%s\n' "${log_excerpt}"
    fi
}

generate_nextpnr_wrapper() {
    local json_file="$1"
    local original_top="$2"
    local xdc_file="$3"
    local wrapper_file="$4"
    local wrapper_xdc="$5"

    python3 - "${json_file}" "${original_top}" "${xdc_file}" "${wrapper_file}" "${wrapper_xdc}" <<'PY'
import json
import re
import sys

json_file, original_top, xdc_file, wrapper_file, wrapper_xdc = sys.argv[1:6]

wrapper_top = "__nextpnr_top_wrapper"
bit_target_re = re.compile(r'get_ports\s+(?P<braced>\{(?P<inner>[^}]+)\}|(?P<plain>[^\s\[\]]+))')
bit_name_re = re.compile(r'^(?P<base>[A-Za-z_][A-Za-z0-9_]*)\[(?P<idx>\d+)\]$')

with open(json_file, "r", encoding="utf-8") as fh:
    data = json.load(fh)

module = data.get("modules", {}).get(original_top)
if module is None:
    sys.exit(1)

ports = []
needs_wrapper = False
for name, info in module.get("ports", {}).items():
    direction = info.get("direction", "input")
    width = len(info.get("bits", [])) or 1
    if width > 1:
        needs_wrapper = True
    ports.append((name, direction, width))

if not needs_wrapper:
    print("none")
    sys.exit(0)

wrapper_ports = []
decl_lines = []
assign_lines = []
instance_lines = []

for name, direction, width in ports:
    if width == 1:
        wrapper_ports.append((direction, name))
        instance_lines.append(f"        .{name}({name})")
        continue

    scalar_names = [f"{name}__{idx}" for idx in range(width)]
    for scalar_name in scalar_names:
        wrapper_ports.append((direction, scalar_name))

    if direction == "input":
        decl_lines.append(f"    wire [{width-1}:0] {name} = " + "{" + ", ".join(reversed(scalar_names)) + "};")
    elif direction == "output":
        decl_lines.append(f"    wire [{width-1}:0] {name};")
        for idx, scalar_name in enumerate(scalar_names):
            assign_lines.append(f"    assign {scalar_name} = {name}[{idx}];")
    elif direction == "inout":
        decl_lines.append(f"    wire [{width-1}:0] {name};")
        for idx, scalar_name in enumerate(scalar_names):
            assign_lines.append(f"    assign {name}[{idx}] = {scalar_name};")
            assign_lines.append(f"    assign {scalar_name} = {name}[{idx}];")
    else:
        raise SystemExit(f"Unsupported direction '{direction}' for port '{name}'")

    instance_lines.append(f"        .{name}({name})")

with open(wrapper_file, "w", encoding="utf-8") as fh:
    fh.write(f"module {wrapper_top} (\n")
    for idx, (direction, name) in enumerate(wrapper_ports):
        comma = "," if idx < len(wrapper_ports) - 1 else ""
        fh.write(f"    {direction} wire {name}{comma}\n")
    fh.write(");\n")
    if decl_lines:
        fh.write("\n")
        for line in decl_lines:
            fh.write(line + "\n")
    fh.write(f"\n    {original_top} u_top (\n")
    for idx, line in enumerate(instance_lines):
        comma = "," if idx < len(instance_lines) - 1 else ""
        fh.write(line + comma + "\n")
    fh.write("    );\n")
    if assign_lines:
        fh.write("\n")
        for line in assign_lines:
            fh.write(line + "\n")
    fh.write("endmodule\n")

with open(xdc_file, "r", encoding="utf-8") as src, open(wrapper_xdc, "w", encoding="utf-8") as dst:
    for raw_line in src:
        def repl(match):
            target = match.group("inner") or match.group("plain") or ""
            target = target.strip()
            bit_match = bit_name_re.match(target)
            if not bit_match:
                return match.group(0)
            return f"get_ports {bit_match.group('base')}__{bit_match.group('idx')}"

        dst.write(bit_target_re.sub(repl, raw_line))

print(wrapper_top)
PY
}

validate_constraints_file() {
    local json_file="$1"
    local top_module="$2"
    local xdc_file="$3"

    python3 - "${json_file}" "${top_module}" "${xdc_file}" <<'PY'
import json
import re
import sys

json_file, top_module, xdc_file = sys.argv[1:4]

with open(json_file, "r", encoding="utf-8") as fh:
    data = json.load(fh)

module = data.get("modules", {}).get(top_module)
if module is None:
    print(f"Constraint pre-check skipped: top module '{top_module}' was not found in {json_file}.")
    sys.exit(0)

ports = {}
for name, info in module.get("ports", {}).items():
    width = len(info.get("bits", [])) or 1
    ports[name] = width

port_props = {}
unknown_targets = set()
line_re = re.compile(r'get_ports\s+(?:\{([^}]+)\}|([^\s\[\]]+))')
bit_re = re.compile(r'^(?P<base>[A-Za-z_][A-Za-z0-9_]*)\[(?P<idx>\d+|\*)\]$')

def ensure_port_entry(name):
    if name not in port_props:
        port_props[name] = {"all": set(), "bits": {}}
    return port_props[name]

with open(xdc_file, "r", encoding="utf-8") as fh:
    for raw_line in fh:
        line = raw_line.split("#", 1)[0].strip()
        if not line or "get_ports" not in line:
            continue

        match = line_re.search(line)
        if not match:
            continue

        target = (match.group(1) or match.group(2) or "").strip()
        if not target:
            continue

        props = set()
        if "PACKAGE_PIN" in line:
            props.add("PACKAGE_PIN")
        if "IOSTANDARD" in line:
            props.add("IOSTANDARD")
        if not props:
            continue

        bit_match = bit_re.match(target)
        if bit_match:
            port_name = bit_match.group("base")
            bit_idx = bit_match.group("idx")
            wrapper_port = f"{port_name}__{bit_idx}"
        else:
            port_name = target
            bit_idx = "*"
            wrapper_port = port_name

        if wrapper_port not in ports:
            unknown_targets.add(target)
            continue

        entry = ensure_port_entry(wrapper_port)
        if bit_idx == "*":
            entry["all"].update(props)
        else:
            idx = int(bit_idx)
            entry["bits"].setdefault(idx, set()).update(props)

missing_any = []
missing_package = []
missing_iostandard = []

for port_name, width in ports.items():
    entry = port_props.get(port_name, {"all": set(), "bits": {}})
    for bit in range(width):
        props = set(entry["all"])
        props.update(entry["bits"].get(bit, set()))
        label = port_name if width == 1 else f"{port_name}[{bit}]"
        if not props:
            missing_any.append(label)
        if "PACKAGE_PIN" not in props:
            missing_package.append(label)
        if "IOSTANDARD" not in props:
            missing_iostandard.append(label)

def format_items(items):
    if not items:
        return ""
    if len(items) <= 10:
        return ", ".join(items)
    head = ", ".join(items[:10])
    return f"{head}, ... ({len(items)} total)"

if missing_any or missing_package or missing_iostandard:
    print(f"Constraint pre-check failed for top module '{top_module}'.")
    print(f"XDC file: {xdc_file}")
    if missing_any:
        print(f"- Missing any XDC entry: {format_items(missing_any)}")
    if missing_package:
        print(f"- Missing PACKAGE_PIN: {format_items(missing_package)}")
    if missing_iostandard:
        print(f"- Missing IOSTANDARD: {format_items(missing_iostandard)}")
    if unknown_targets:
        unknown_list = sorted(unknown_targets)
        print(f"- XDC entries not present in this top module: {format_items(unknown_list)}")
    print("Example fix:")
    example_target = missing_iostandard[0] if missing_iostandard else missing_package[0]
    print(f"  set_property -dict {{PACKAGE_PIN <PIN> IOSTANDARD LVCMOS33}} [get_ports {{{example_target}}}]")
    sys.exit(1)

if unknown_targets:
    print(f"Constraint pre-check passed, but the XDC has extra entries not in '{top_module}': {format_items(sorted(unknown_targets))}")
else:
    print("Constraint pre-check passed")
PY
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --top)
            TOP="$2"
            TOP_SET_BY_USER=true
            shift 2
            ;;
        --constraints|--contraints)
            CONSTRAINTS="$2"
            CONSTRAINTS_SET_BY_USER=true
            shift 2
            ;;
        --project)
            PROJECT="$2"
            PROJECT_SET_BY_USER=true
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
    if [ "${PROJECT_SET_BY_USER}" = false ] && [ "${SOURCE_DIR}" != "." ]; then
        PROJECT="$(basename "${SOURCE_DIR}")"
    fi

    mapfile -t SRC_FILES < <(list_project_sources "$SOURCE_DIR")
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

    if [ -z "${SELECTED_SRC}" ]; then
        SELECTED_SRC="$(recommend_source_file "${SOURCE_DIR}" "${PROJECT}" || true)"
    fi

    if [ -z "${SELECTED_SRC}" ] && [ ${#SRC_FILES[@]} -eq 1 ]; then
        SELECTED_SRC="${SRC_FILES[0]}"
    fi

    if [ -z "${TOP}" ] && [ -n "${SELECTED_SRC}" ]; then
        TOP="$(detect_module_name "${SELECTED_SRC}")"
    fi

    if [ -z "${CONSTRAINTS}" ]; then
        CONSTRAINTS="$(recommend_constraints_file "${SOURCE_DIR}" "${SELECTED_SRC}" "${PROJECT}" || true)"
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

        SELECTED_SRC="$(recommend_source_file "${proj_dir}" "${proj_name}" || true)"
        if [ -z "${SELECTED_SRC}" ]; then
            mapfile -t SRC_FILES < <(list_project_sources "${proj_dir}")
        else
            SRC_FILES=("${SELECTED_SRC}")
        fi

        if [ ${#SRC_FILES[@]} -eq 0 ]; then
            echo -e "${RED}  Skipping ${proj_name}: no .sv/.v source found${NC}"
            FAILED+=("$proj_name")
            continue
        fi

        if [ -z "${SELECTED_SRC}" ]; then
            SELECTED_SRC="${SRC_FILES[0]}"
            echo -e "${YELLOW}  Warning:${NC} ambiguous source files, defaulting to $(basename "${SELECTED_SRC}")"
        fi
        detected_top="$(detect_module_name "${SELECTED_SRC}")"
        if [ -z "${detected_top}" ]; then
            echo -e "${RED}  Skipping ${proj_name}: could not detect a module in $(basename "${SELECTED_SRC}")${NC}"
            FAILED+=("$proj_name")
            continue
        fi

        detected_constraints="$(recommend_constraints_file "${proj_dir}" "${SELECTED_SRC}" "${proj_name}" || true)"
        if [ -z "${detected_constraints}" ]; then
            mapfile -t XDC_FILES < <(list_project_constraints "${proj_dir}")
        else
            XDC_FILES=("${detected_constraints}")
        fi

        if [ ${#XDC_FILES[@]} -eq 0 ]; then
            echo -e "${RED}  Skipping ${proj_name}: no .xdc constraints found${NC}"
            FAILED+=("$proj_name")
            continue
        fi

        if [ -z "${detected_constraints}" ]; then
            detected_constraints="${XDC_FILES[0]}"
            echo -e "${YELLOW}  Warning:${NC} ambiguous XDC files, defaulting to $(basename "${detected_constraints}")"
        fi
        detected_xdc=$(basename "${detected_constraints}")

        echo "  Design file: $(basename "${SELECTED_SRC}")"
        echo "  Top module : $detected_top"
        echo "  Constraints: $detected_xdc"
        echo "  Project    : $proj_name"

        if "$BUILD_SCRIPT_DIR/build.sh" \
            --source-dir "$proj_dir" \
            --top "$detected_top" \
            --constraints "${detected_constraints}" \
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
    if [ -n "${SELECTED_SRC:-}" ]; then
        TOP="$(detect_module_name "${SELECTED_SRC}")"
    fi
fi

if [ -z "${TOP}" ]; then
    TOP="$PROJECT"
fi

# Change to source directory
cd "${SOURCE_DIR}"
echo "Building from directory: $(pwd)"
echo ""

# Auto-detect constraints file if not specified
if [ -z "$CONSTRAINTS" ]; then
    CONSTRAINTS="$(recommend_constraints_file "$(pwd)" "${SELECTED_SRC:-}" "${PROJECT}" || true)"
fi

if [ -z "$CONSTRAINTS" ]; then
    echo -e "${RED}Error: No constraints file found. Use --constraints to specify.${NC}"
    exit 1
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
YOSYS_READ_CMD="read_verilog -sv ${SELECTED_BASENAME}"
if [ -n "$SV_FILES" ]; then
    YOSYS_READ_CMD="${YOSYS_READ_CMD}; read_verilog -sv ${SV_FILES}"
fi
if [ -n "$V_FILES" ]; then
    YOSYS_READ_CMD="${YOSYS_READ_CMD}; read_verilog ${V_FILES}"
fi

PRESCAN_JSON="${BUILD_DIR}/${PROJECT}.ports.json"
SYNTH_TOP="${TOP}"
PNR_CONSTRAINTS="${CONSTRAINTS}"
WRAPPER_FILE="${BUILD_DIR}/__nextpnr_wrapper.v"
WRAPPER_XDC="${BUILD_DIR}/__nextpnr_wrapper.xdc"

if yosys -q -p "${YOSYS_READ_CMD}; hierarchy -check -top ${TOP}; proc; opt; write_json \"${PRESCAN_JSON}\"" >/dev/null 2>&1; then
    GENERATED_WRAPPER_TOP="$(generate_nextpnr_wrapper "${PRESCAN_JSON}" "${TOP}" "${CONSTRAINTS}" "${WRAPPER_FILE}" "${WRAPPER_XDC}" || true)"
    if [ -n "${GENERATED_WRAPPER_TOP}" ] && [ "${GENERATED_WRAPPER_TOP}" != "none" ] && [ -f "${WRAPPER_FILE}" ] && [ -f "${WRAPPER_XDC}" ]; then
        SYNTH_TOP="${GENERATED_WRAPPER_TOP}"
        PNR_CONSTRAINTS="${WRAPPER_XDC}"
        echo "  Generated temporary scalar wrapper for nextpnr compatibility"
    fi
fi

YOSYS_CMD="${YOSYS_READ_CMD}"
if [ "${SYNTH_TOP}" != "${TOP}" ] && [ -f "${WRAPPER_FILE}" ]; then
    YOSYS_CMD="${YOSYS_CMD}; read_verilog -sv $(basename "${WRAPPER_FILE}")"
fi
YOSYS_CMD="${YOSYS_CMD}; hierarchy -check -top ${SYNTH_TOP}; synth_xilinx -family xc7 -flatten -nowidelut -nocarry -top ${SYNTH_TOP}; write_json \"${BUILD_DIR}/${PROJECT}.json\""

yosys -p "${YOSYS_CMD}" 2>&1 | tee ${BUILD_DIR}/yosys.log

if [ ! -f "${BUILD_DIR}/${PROJECT}.json" ]; then
    print_log_errors "${BUILD_DIR}/yosys.log" "Yosys errors"
    echo -e "${RED}Error: Synthesis failed. Check yosys.log for details.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 2: Constraint pre-check${NC}"
constraint_check_output="$(validate_constraints_file "${BUILD_DIR}/${PROJECT}.json" "${SYNTH_TOP}" "${PNR_CONSTRAINTS}" 2>&1 || true)"
printf '%s\n' "${constraint_check_output}" | tee "${BUILD_DIR}/constraints.log"
if printf '%s\n' "${constraint_check_output}" | grep -q '^Constraint pre-check failed'; then
    echo -e "${RED}Error: Constraint validation failed before place-and-route.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 3: Place and Route with nextpnr-xilinx${NC}"

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
    --xdc "${PNR_CONSTRAINTS}" \
    --fasm "${BUILD_DIR}/${PROJECT}.fasm" \
    --verbose 2>&1 | tee ${BUILD_DIR}/nextpnr.log

if [ ! -f "${BUILD_DIR}/${PROJECT}.fasm" ]; then
    print_log_errors "${BUILD_DIR}/nextpnr.log" "nextpnr errors"
    if grep -q "Assertion failure: str.back() == '}'" "${BUILD_DIR}/nextpnr.log" 2>/dev/null; then
        echo -e "${YELLOW}Hint:${NC} nextpnr-xilinx rejected the XDC syntax. Remove spaces directly inside braces, e.g. use {clk} instead of { clk }."
    fi
    if grep -q "has no IOSTANDARD property" "${BUILD_DIR}/nextpnr.log" 2>/dev/null; then
        missing_ports="$(sed -n 's/.*ERROR: port \(.*\) of type PAD has no IOSTANDARD property.*/\1/p' "${BUILD_DIR}/nextpnr.log" | paste -sd ', ' -)"
        if [ -n "${missing_ports}" ]; then
            echo -e "${YELLOW}Hint:${NC} Add 'IOSTANDARD LVCMOS33' for: ${missing_ports}"
        fi
    fi
    if grep -q "has no PACKAGE_PIN property" "${BUILD_DIR}/nextpnr.log" 2>/dev/null; then
        missing_ports="$(sed -n 's/.*ERROR: port \(.*\) of type PAD has no PACKAGE_PIN property.*/\1/p' "${BUILD_DIR}/nextpnr.log" | paste -sd ', ' -)"
        if [ -n "${missing_ports}" ]; then
            echo -e "${YELLOW}Hint:${NC} Add 'PACKAGE_PIN <PIN>' for: ${missing_ports}"
        fi
    fi
    echo -e "${RED}Error: Place and route failed. Check nextpnr.log for details.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 4: Generate FASM to Frames${NC}"
if [ "${XRAY_FASM2FRAMES_MODE}" = "exec" ]; then
    run_tool_binary "${XRAY_FASM2FRAMES}" --db-root "${XRAY_DATABASE_DIR}/${XRAY_DATABASE}" --part "${PART}" "${BUILD_DIR}/${PROJECT}.fasm" "${BUILD_DIR}/${PROJECT}.frames"
else
    python3 "${XRAY_FASM2FRAMES}" --db-root "${XRAY_DATABASE_DIR}/${XRAY_DATABASE}" --part "${PART}" "${BUILD_DIR}/${PROJECT}.fasm" "${BUILD_DIR}/${PROJECT}.frames"
fi

echo ""
echo -e "${YELLOW}Step 5: Generate Bitstream${NC}"
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
