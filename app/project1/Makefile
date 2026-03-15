# Nexys A7-100T Bare-Metal FPGA Build
# Uses Yosys + NextPNR + PRJXRAY (no Vivado)

CHIP := xc7a100t
CHIPDB := $(HOME)/.local/share/nextpnr/xilinx/chipdb-$(CHIP).bin
PART := xc7a100tcsg324-1
PRJXRAY_DB := $(HOME)/FPGA_Compiler-/.tools/prjxray-db/artix7

# Source files
SV_FILES := simple.v

# Generated files
JSON := project.json
FASM := top.fasm
BITSTREAM := top.bit

# Pinout for Nexys A7-100T (XC7A100T-1CSG324C)
XDC_FILE := constraints.xdc

.PHONY: all clean

all: $(BITSTREAM)

# Synthesis with Yosys
$(JSON): $(SV_FILES)
	yosys -p "read_verilog -sv $^; synth_xilinx -top top -family xc7; write_json $@"

# Place & Route with NextPNR and generate FASM
$(FASM): $(JSON) $(XDC_FILE)
	nextpnr-xilinx --chipdb $(CHIPDB) --json $< --xdc $(XDC_FILE) --fasm top.fasm

# Convert FASM to bitstream using PRJXRAY
$(BITSTREAM): $(FASM)
	python3 /home/hai/FPGA_Compiler-/.tools/prjxray/utils/fasm2frames.py \
		--part $(PART) --db-root $(PRJXRAY_DB) $< top.frames
	xc7frames2bit -part_file $(PRJXRAY_DB)/$(PART)/part.yaml -frm_file top.frames -output_file $@

clean:
	rm -f $(JSON) $(BITSTREAM) top.fasm top.frames top.asc top.bin
