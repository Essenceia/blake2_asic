############
# Sim type #
############

# Define simulator we are using, priority to iverilog
SIM ?= verilator
$(info Using simulator: $(SIM))

###########
# Globals #
###########

# Global configs.
FPGA_DIR := fpga
SW_DIR := firmware
TB_DIR := test
TV_DIR := tv
SRC_DIR := src
CONF := conf
DEBUG_FLAG := $(if $(debug), debug=1)
DEFINES := $(if $(wave),wave=1)
WAIVER_FILE := waiver.vlt
FPGA_LIB:= lib

.PHONY: firmware openocd gdb fpga fpga_prog lint lint_fpga tv test

########
# Lint #
########

# Lint variables.
LINT_FLAGS :=
ifeq ($(SIM),icarus)
LINT_FLAGS +=-Wall -g2012 $(if $(assert),-gassertions) -gstrict-expr-width
LINT_FLAGS +=$(if $(debug),-DDEBUG) 
else
LINT_FLAGS += -Wall -Wpedantic -Wno-GENUNNAMED -Wno-LATCH -Wno-IMPLICIT
LINT_FLAGS += -Wno-DECLFILENAME
LINT_FLAGS +=$(if $(wip),-Wno-UNUSEDSIGNAL)
LINT_FLAGS += -Ilib
endif

# Lint commands.
ifeq ($(SIM),icarus)
define LINT
	mkdir -p build
	iverilog $(LINT_FLAGS) -s $2 -o $(BUILD_DIR)/$2 $1
endef
else
	
define LINT
	mkdir -p build
	verilator $(CONF)/$(WAIVER_FILE) --lint-only $(LINT_FLAGS) --no-timing $1 --top $2
endef
endif

########
# Lint #
########

entry_deps := $(wildcard $(SRC_DIR)/*.v)
fpga_deps := $(entry_deps) $(wildcard $(FPGA_DIR)/*.v)

lint: $(entry_deps)
	$(call LINT,$^,tt_um_essen)

lint_fpga: $(fpga_deps)
	$(call LINT,$^,emulator)
 
#############
# Testbench #
#############
# Call cocotb
test:
	$(MAKE) -C $(TB_DIR) WAVES=1

###############
# Test vector #
###############
# Build and run test vector generation
tv:
	$(MAKE) -C $(TV_DIR) run

#############
# Firmware  #
#############
# Build RP2040 firmware
firmware:
	$(MAKE) -C $(SW_DIR) build

# start openocd, connect to RPi via JLink JTAG, start gdb server
openocd:
	$(MAKE) -C $(SW_DIR) debug

gdb:
	$(MAKE) -C $(SW_DIR) gdb

#############
# FPGA      #
#############
# Build vivado project and run PnR, not generating bitstream or flashing
fpga:
	$(MAKE) -C $(FPGA_DIR) build $(DEBUG_FLAG)

# Program the FPGA using a xilinx approved probe, no openocd config this time
fpga_prog:
	$(MAKE) -C $(FPGA_DIR) prog $(DEBUG_FLAG)

# Cleanup
clean:
	rm -f vgcore.* vgd.log*
	rm -f callgrind.out.*
	rm -fr build/*
	rm -fr obj_dir/*
	rm -fr $(WAVE_DIR)/*
	$(MAKE) -C $(FPGA_DIR) clean
	$(MAKE) -C $(SW_DIR) clean

