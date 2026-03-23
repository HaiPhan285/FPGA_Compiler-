#!/bin/bash
# Quick environment verifier for the FPGA toolchain.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRJXRAY_ENV="${SCRIPT_DIR}/prjxray-env.sh"

if [ ! -f "${PRJXRAY_ENV}" ]; then
    echo "Error: missing ${PRJXRAY_ENV}"
    exit 1
fi

# shellcheck disable=SC1090
source "${PRJXRAY_ENV}"

run_tool_binary() {
    local tool_bin="$1"
    shift

    if [ -n "${OPENXC7_LD_LIBRARY_PATH:-}" ] && [[ "${tool_bin}" == /snap/openxc7/* ]]; then
        env LD_LIBRARY_PATH="${OPENXC7_LD_LIBRARY_PATH}" "${tool_bin}" "$@"
    else
        "${tool_bin}" "$@"
    fi
}

find_chipdb() {
    local path
    for path in \
        "${HOME}/.local/share/nextpnr/xilinx/chipdb-xc7a100t.bin" \
        "/usr/share/nextpnr/xilinx/chipdb-xc7a100t.bin" \
        "/usr/local/share/nextpnr/xilinx/chipdb-xc7a100t.bin"; do
        if [ -f "${path}" ]; then
            printf '%s\n' "${path}"
            return 0
        fi
    done
    return 1
}

SMOKE_TEST=false
if [ "${1:-}" = "--smoke" ]; then
    SMOKE_TEST=true
fi

echo "=== FPGA Doctor ==="
echo "Repo: ${SCRIPT_DIR}"
echo "Tool source: ${XRAY_SETUP_SOURCE}"

if ! command -v yosys >/dev/null 2>&1; then
    echo "Error: yosys not found"
    exit 1
fi
echo "yosys: $(yosys --version | head -1)"

NEXTPNR_XILINX_BIN=""
if [ -n "${OPENXC7_SNAP_ROOT:-}" ] && [ -x "${OPENXC7_SNAP_ROOT}/usr/bin/nextpnr-xilinx" ]; then
    NEXTPNR_XILINX_BIN="${OPENXC7_SNAP_ROOT}/usr/bin/nextpnr-xilinx"
else
    NEXTPNR_XILINX_BIN="$(command -v nextpnr-xilinx 2>/dev/null || true)"
fi

if [ -z "${NEXTPNR_XILINX_BIN}" ]; then
    echo "Error: nextpnr-xilinx not found"
    exit 1
fi
echo "nextpnr-xilinx: ${NEXTPNR_XILINX_BIN}"
run_tool_binary "${NEXTPNR_XILINX_BIN}" --help >/dev/null

if [ ! -x "${XRAY_XC7FRAMES2BIT}" ]; then
    echo "Error: xc7frames2bit not found at ${XRAY_XC7FRAMES2BIT}"
    exit 1
fi
echo "xc7frames2bit: ${XRAY_XC7FRAMES2BIT}"

if [ ! -f "${XRAY_FASM2FRAMES}" ]; then
    echo "Error: fasm2frames not found at ${XRAY_FASM2FRAMES}"
    exit 1
fi
echo "fasm2frames: ${XRAY_FASM2FRAMES}"

if [ ! -f "${XRAY_PART_YAML}" ]; then
    echo "Error: part.yaml not found at ${XRAY_PART_YAML}"
    exit 1
fi
echo "part.yaml: ${XRAY_PART_YAML}"

CHIPDB_PATH="$(find_chipdb || true)"
if [ -z "${CHIPDB_PATH}" ]; then
    echo "Warning: chipdb-xc7a100t.bin not found yet. Run ./setup.sh or ./build.sh once."
else
    echo "chipdb: ${CHIPDB_PATH}"
fi

if [ "${SMOKE_TEST}" = true ]; then
    echo ""
    echo "Running smoke test builds (.v and .sv)..."

    run_smoke_build() {
        local name="$1"
        local source_dir="$2"
        local top="$3"
        local constraints="$4"
        local tmp_project="$5"
        local tmp_bit="${source_dir}/${tmp_project}.bit"
        local tmp_log="/tmp/${tmp_project}.log"

        rm -f "${tmp_bit}"
        "${SCRIPT_DIR}/build.sh" \
            --source-dir "${source_dir}" \
            --top "${top}" \
            --constraints "${constraints}" \
            --project "${tmp_project}" >"${tmp_log}" 2>&1

        if [ ! -f "${tmp_bit}" ]; then
            echo "Error: ${name} smoke test did not produce ${tmp_bit}"
            echo "See ${tmp_log}"
            exit 1
        fi

        rm -f "${tmp_bit}"
        echo "Smoke test passed: ${name}"
        echo "Log: ${tmp_log}"
    }

    run_smoke_build \
        "Verilog (project5)" \
        "${SCRIPT_DIR}/app/project5" \
        "and_gate" \
        "${SCRIPT_DIR}/app/project5/and_gate.xdc" \
        "_doctor_project5"

    run_smoke_build \
        "SystemVerilog (chapter 6)" \
        "${SCRIPT_DIR}/app/chapter 6" \
        "top" \
        "${SCRIPT_DIR}/app/chapter 6/constraints.xdc" \
        "_doctor_chapter6"
fi

echo ""
echo "Doctor check passed"
