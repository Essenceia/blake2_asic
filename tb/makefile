# defaults
SIM ?= icarus
WAVES=1
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(wildcard ../*.v)

COCOTB_TOPLEVEL = top

COCOTB_TEST_MODULES = test_top

include $(shell cocotb-config --makefiles)/Makefile.sim
