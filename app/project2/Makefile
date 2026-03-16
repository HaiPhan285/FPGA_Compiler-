################################################################################
# FPGA Build System - Project 2: 8-bit ALU
# Target: Nexys A7-100T (Xilinx XC7A100T)
# Toolchain: Yosys + NextPNR + PRJXRAY
################################################################################

CHIP := xc7a100t
CHIPDB := $(HOME)/.local/share/nextpnr/xilinx/chipdb-$(CHIP).bin
PART := xc7a100tcsg324-1
PRJXRAY_DB := $(HOME)/FPGA_Compiler-/.tools/prjxray-db/artix7

# Source files
RTL_FILES := top.v alu.v
CONSTRAINTS := top.xdc

# Generated files
JSON := top.json
FASM := top.fasm
BITSTREAM := top.bit

.PHONY: all clean help

all: $(BITSTREAM)
	@echo "✓ Build complete: $(BITSTREAM)"

$(JSON): $(RTL_FILES)
	@echo "Synthesizing with Yosys..."
	yosys -p "read_verilog $^; synth_xilinx -top top -family xc7; write_json $@" 2>&1 | tee yosys.log

$(FASM): $(JSON) $(CONSTRAINTS)
	@echo "Place & Route with NextPNR..."
	nextpnr-xilinx --chipdb $(CHIPDB) --json $< --xdc $(CONSTRAINTS) --fasm $@

$(BITSTREAM): $(FASM)
	@echo "Generating bitstream..."
	python3 /home/hai/FPGA_Compiler-/.tools/prjxray/utils/fasm2frames.py \
		--part $(PART) --db-root $(PRJXRAY_DB) $< top.frames
	xc7frames2bit -part_file $(PRJXRAY_DB)/$(PART)/part.yaml \
		-frm_file top.frames -output_file $@

program: $(BITSTREAM)
	@echo "Programming FPGA..."
	openFPGALoader -b nexys_a7_100 $<

clean:
	rm -f $(JSON) $(BITSTREAM) $(FASM) top.frames yosys.log

help:
	@echo "Available targets:"
	@echo "  make           - Build bitstream"
	@echo "  make program   - Build and program FPGA"
	@echo "  make clean     - Remove build artifacts"
