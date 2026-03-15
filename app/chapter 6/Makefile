# Nexys A7-100T Chapter 6 Traffic Light Build
# Uses Yosys + NextPNR + PRJXRAY (no Vivado)

CHIP := xc7a100t
CHIPDB := $(HOME)/.local/share/nextpnr/xilinx/chipdb-$(CHIP).bin
PART := xc7a100tcsg324-1
PRJXRAY_DB := $(HOME)/FPGA_Compiler-/.tools/prjxray-db/artix7

SV_FILES := top.sv

JSON := chapter6.json
FASM := chapter6.fasm
BITSTREAM := chapter6.bit

XDC_FILE := constraints.xdc

.PHONY: all clean

all: $(BITSTREAM)

$(JSON): $(SV_FILES)
	yosys -p "read_verilog -sv $^; synth_xilinx -top top -family xc7; write_json $@"

$(FASM): $(JSON) $(XDC_FILE)
	nextpnr-xilinx --chipdb $(CHIPDB) --json $< --xdc $(XDC_FILE) --fasm $(FASM)

$(BITSTREAM): $(FASM)
	python3 /home/hai/FPGA_Compiler-/.tools/prjxray/utils/fasm2frames.py \
		--part $(PART) --db-root $(PRJXRAY_DB) $< chapter6.frames
	xc7frames2bit -part_file $(PRJXRAY_DB)/$(PART)/part.yaml -frm_file chapter6.frames -output_file $@

clean:
	rm -f $(JSON) $(BITSTREAM) $(FASM) chapter6.frames chapter6.asc chapter6.bin
