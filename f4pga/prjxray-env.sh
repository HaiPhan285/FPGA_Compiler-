#!/bin/bash
# Custom environment setup for prjxray without Vivado dependency
# Source this file before running the build script

export XRAY_DIR="/home/hai/f4pga/prjxray"
export XRAY_UTILS_DIR="${XRAY_DIR}/utils"
export XRAY_DATABASE_DIR="${XRAY_DIR}/database"
export XRAY_TOOLS_DIR="${XRAY_DIR}/build/tools"
export XRAY_FUZZERS_DIR="${XRAY_DIR}/fuzzers"

# Set default part for Nexys A7-100T
export XRAY_DATABASE="artix7"
export XRAY_PART="xc7a100tcsg324-1"
export XRAY_PART_YAML="${XRAY_DATABASE_DIR}/${XRAY_DATABASE}/${XRAY_PART}/part.yaml"

# Activate Python virtual environment
if [ -f "${XRAY_DIR}/../env/bin/activate" ]; then
    source "${XRAY_DIR}/../env/bin/activate"
fi

# Set PYTHONPATH
export PYTHONPATH="${XRAY_DIR}:${PYTHONPATH}"

# Tool paths
export XRAY_GENHEADER="${XRAY_UTILS_DIR}/genheader.sh"
export XRAY_BITREAD="${XRAY_TOOLS_DIR}/bitread --part_file ${XRAY_PART_YAML}"
export XRAY_MERGEDB="bash ${XRAY_UTILS_DIR}/mergedb.sh"
export XRAY_DBFIXUP="python3 ${XRAY_UTILS_DIR}/dbfixup.py"
export XRAY_MASKMERGE="bash ${XRAY_UTILS_DIR}/maskmerge.sh"
export XRAY_SEGMATCH="${XRAY_TOOLS_DIR}/segmatch"
export XRAY_SEGPRINT="python3 ${XRAY_UTILS_DIR}/segprint.py"
export XRAY_BIT2FASM="python3 ${XRAY_UTILS_DIR}/bit2fasm.py"
export XRAY_FASM2FRAMES="${XRAY_UTILS_DIR}/fasm2frames.py"
export XRAY_BITTOOL="${XRAY_TOOLS_DIR}/bittool"
export XRAY_BLOCKWIDTH="python3 ${XRAY_UTILS_DIR}/blockwidth.py"
export XRAY_PARSEDB="python3 ${XRAY_UTILS_DIR}/parsedb.py"

# Suppress warnings
export PYTHONWARNINGS=ignore::DeprecationWarning:distutils

echo "prjxray environment configured for ${XRAY_PART}"
echo "Tools available at: ${XRAY_TOOLS_DIR}"
