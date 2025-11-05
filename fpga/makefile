SHELL := /bin/bash

ifndef debug
#debug := 
endif 

VIVADO_PRJ_DIR=emulator
VIVADO_PRJ_NAME=$(VIVADO_PRJ_DIR)
VIVADO_PRJ_PATH=$(VIVADO_PRJ_DIR)/$(VIVADO_PRJ_NAME).xpr
VIVADO_CHECKPOINT_PATH=$(VIVADO_PRJ_DIR)/$(VIVADO_PRJ_NAME)_checkpoint.dcp
VIVADO_DEBUG_PROBE_PATH=$(VIVADO_PRJ_DIR)/$(VIVADO_PRJ_NAME)_debug_probes.ltx
VIVADO_BIT_PATH=$(VIVADO_PRJ_DIR)/$(VIVADO_PRJ_NAME).svf

VIVADO_CMD=vivado -mode batch -source

SRC_PATH=../src


.PHONY: setup build prog gui

all: setup build gen

$(VIVADO_PRJ_PATH): setup.tcl 
	mkdir -p $(VIVADO_PRJ_DIR)
	$(VIVADO_CMD) setup.tcl -tclargs $(VIVADO_PRJ_DIR) $(VIVADO_PRJ_NAME) $(SRC_PATH)  

setup: $(VIVADO_PRJ_PATH) 

$(VIVADO_CHECKPOINT_PATH): $(VIVADO_PRJ_PATH) $(wildcard *.xdc) $(wildcard $(SRC_PATH)/*.v) $(wildcard *.v)
	$(VIVADO_CMD) build.tcl -tclargs $(VIVADO_PRJ_PATH) $(VIVADO_CHECKPOINT_PATH) $(if $(debug), $(debug) $(VIVADO_DEBUG_PROBE_PATH) )

build: $(VIVADO_CHECKPOINT_PATH)

$(VIVADO_BIT_PATH): $(VIVADO_CHECKPOINT_PATH) 
	$(VIVADO_CMD) program.tcl -tclargs $(VIVADO_CHECKPOINT_PATH) $(VIVADO_PRJ_DIR)

prog: $(VIVADO_BIT_PATH)

gui: $(VIVADO_CHECKPOINT_PATH)
	vivado $(VIVADO_CHECKPOINT_PATH)

clean:
	rm -rf .Xil 
	rm -rf $(VIVADO_PRJ_DIR)
	rm -f vivado*
	rm -f webtalk*{log,jou}
	rm -f usage_statistics_webtalk*{html,xml}
	rm -f hs_err*.log
