#
# Created on Tue Feb 22 2022
#
# Copyright (c) 2022 IOA UCAS
#
# @Filename:	 testbench.py
# @Author:		 Jiawei Lin
# @Last edit:	 09:04:13
#

TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 1

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

DUT = action_pipe
TOPLEVEL = $(DUT)
MODULE = testbench

VERILOG_SOURCES += ../../rtl/action_pipe/action_pipe.v
VERILOG_SOURCES += ../../rtl/action_pipe/axis_ttl_dec.v
VERILOG_SOURCES += ../../rtl/action_pipe/axis_hdr_csum.v
VERILOG_SOURCES += ../../rtl/action_pipe/axis_set_field.v
VERILOG_SOURCES += ../../rtl/action_pipe/set_field_async.v
VERILOG_SOURCES += ../../rtl/action_pipe/axis_vlan_op.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_mux.v

export PARAM_ACTN_DATA_WIDTH ?= 128
export PARAM_S_DATA_WIDTH ?= 512
export PARAM_M_DATA_WIDTH ?= 560
export PARAM_PT_OFFSET ?= 0

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).ACTN_DATA_WIDTH=$(PARAM_ACTN_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).S_DATA_WIDTH=$(PARAM_S_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).M_DATA_WIDTH=$(PARAM_M_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).PT_OFFSET=$(PARAM_PT_OFFSET)

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GACTN_DATA_WIDTH=$(PARAM_ACTN_DATA_WIDTH)
	COMPILE_ARGS += -GS_DATA_WIDTH=$(PARAM_S_DATA_WIDTH)
	COMPILE_ARGS += -GM_DATA_WIDTH=$(PARAM_M_DATA_WIDTH)
	COMPILE_ARGS += -GPT_OFFSET=$(PARAM_PT_OFFSET)
	
	# COMPILE_ARGS += -I $(HEADER_FILES)

	ifeq ($(WAVES), 1)
		COMPILE_ARGS += --trace-fst
	endif
endif

ifneq ($(filter $(SIM),ius xcelium),)
	SIM_ARGS += -v93
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

iverilog_dump.v:
	echo 'module iverilog_dump();' > $@
	echo 'initial begin' >> $@
	echo '	$$dumpfile("$(TOPLEVEL).fst");' >> $@
	echo '	$$dumpvars(0, $(TOPLEVEL));' >> $@
	echo 'end' >> $@
	echo 'endmodule' >> $@

clean::
	@rm -rf iverilog_dump.v
	@rm -rf dump.fst $(TOPLEVEL).fst
	@rm -rf *.xml
	@rm -rf __pycache__