#!/bin/bash
# Environment setup for the open-source Xilinx 7-series toolchain.
# Prefer the tools bundled in the installed openXC7 snap. Fall back to
# locally built .tools assets only when the snap bundle is unavailable.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export XRAY_DATABASE="artix7"
export XRAY_PART="xc7a100tcsg324-1"

OPENXC7_SNAP_ROOT=""
for snap_root in "/snap/openxc7/current" "/snap/openxc7/x1"; do
    if [ -x "${snap_root}/usr/bin/nextpnr-xilinx" ] && \
       [ -x "${snap_root}/usr/bin/xc7frames2bit" ] && \
       [ -x "${snap_root}/bin/fasm2frames" ] && \
       [ -f "${snap_root}/opt/nextpnr-xilinx/external/prjxray-db/${XRAY_DATABASE}/${XRAY_PART}/part.yaml" ]; then
        OPENXC7_SNAP_ROOT="${snap_root}"
        break
    fi
done

if [ -n "${OPENXC7_SNAP_ROOT}" ]; then
    export XRAY_SETUP_SOURCE="openxc7-snap"
    export OPENXC7_SNAP_ROOT
    export OPENXC7_LD_LIBRARY_PATH="${OPENXC7_SNAP_ROOT}/usr/lib/x86_64-linux-gnu:${OPENXC7_SNAP_ROOT}/lib/x86_64-linux-gnu:${OPENXC7_SNAP_ROOT}/usr/lib:${OPENXC7_SNAP_ROOT}/lib"

    export XRAY_DATABASE_DIR="${OPENXC7_SNAP_ROOT}/opt/nextpnr-xilinx/external/prjxray-db"
    export XRAY_PART_YAML="${XRAY_DATABASE_DIR}/${XRAY_DATABASE}/${XRAY_PART}/part.yaml"
    export XRAY_TOOLS_DIR="${OPENXC7_SNAP_ROOT}/usr/bin"
    export XRAY_FASM2FRAMES="${OPENXC7_SNAP_ROOT}/bin/fasm2frames"
    export XRAY_FASM2FRAMES_MODE="exec"
    export XRAY_XC7FRAMES2BIT="${OPENXC7_SNAP_ROOT}/usr/bin/xc7frames2bit"
else
    export XRAY_SETUP_SOURCE="local-tools"
    export XRAY_DIR="${SCRIPT_DIR}/.tools/prjxray"
    export XRAY_UTILS_DIR="${XRAY_DIR}/utils"
    export XRAY_DATABASE_DIR="${SCRIPT_DIR}/.tools/prjxray-db"
    export XRAY_TOOLS_DIR="${XRAY_DIR}/build/tools"
    export XRAY_PART_YAML="${XRAY_DATABASE_DIR}/${XRAY_DATABASE}/${XRAY_PART}/part.yaml"
    export XRAY_FASM2FRAMES="${XRAY_UTILS_DIR}/fasm2frames.py"
    export XRAY_FASM2FRAMES_MODE="python"
    export XRAY_XC7FRAMES2BIT="${XRAY_TOOLS_DIR}/xc7frames2bit"

    if [ -f "${XRAY_DIR}/../env/bin/activate" ]; then
        # shellcheck disable=SC1091
        source "${XRAY_DIR}/../env/bin/activate"
    fi

    export PYTHONPATH="${XRAY_DIR}:${PYTHONPATH}"
    export PATH="${XRAY_TOOLS_DIR}:${PATH}"
fi

export PYTHONWARNINGS=ignore::DeprecationWarning:distutils

echo "prjxray environment configured for ${XRAY_PART} using ${XRAY_SETUP_SOURCE}"
echo "Database root: ${XRAY_DATABASE_DIR}"
