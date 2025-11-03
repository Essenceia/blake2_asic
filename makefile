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
TB_DIR := tb
CONF := conf
DEBUG_FLAG := $(if $(debug), debug=1)
DEFINES := $(if $(wave),wave=1)
WAIVER_FILE := waiver.vlt
FPGA_LIB:= lib
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

entry_deps := $(wildcard *.v)
fpga_deps := $(entry_deps) $(wildcard fpga/*.v) $(wildcard fpga/basys3/*.v)

lint: $(entry_deps)
	$(call LINT,$^,top)

lint_fpga: $(fpga_deps)
	$(call LINT,$^,emulator)
 
#############
# Testbench #
#############
# Call cocotb
test:
	$(MAKE) -C $(TB_DIR)


#############
# Firmware  #
#############
# Build RP2040 firmware
firmware:
	$(MAKE) -C $(SW_DIR) build

#############
# FPGA      #
#############
# Build vivado project and run PnR, not generating bitstream or flashing
fpga:
	$(MAKE) -C $(FPGA_DIR) build

# Cleanup
clean:
	rm -f vgcore.* vgd.log*
	rm -f callgrind.out.*
	rm -fr build/*
	rm -fr obj_dir/*
	rm -fr $(WAVE_DIR)/*
	$(MAKE) -C $(FPGA_DIR) clean
	$(MAKE) -C $(SW_DIR) clean

