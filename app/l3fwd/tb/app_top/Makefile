# Copyright (c) 2021 Alex Forencich
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 0

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

export PORTS ?= 8

DUT      = dut
WRAPPER  = dut_wrap_$(PORTS)
TOPLEVEL = $(WRAPPER)
MODULE   = testbench

VERILOG_SOURCES += $(WRAPPER).v
VERILOG_SOURCES += ../../rtl/app_top.v
VERILOG_SOURCES += ../../rtl/app_core.v
VERILOG_SOURCES += ../../rtl/app_mat.v
VERILOG_SOURCES += ../../rtl/app_ps.v
VERILOG_SOURCES += ../../rtl/axis_pred_mux.v
VERILOG_SOURCES += ../../rtl/arbiter_pred.v
VERILOG_SOURCES += ../../rtl/sim/zynq_soc.v
VERILOG_SOURCES += ../../lib/axis/rtl/arbiter.v
VERILOG_SOURCES += ../../lib/axis/rtl/priority_encoder.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_adapter.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_fifo.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_mux.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_register.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_arb_mux.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_async_fifo.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_async_fifo_adapter.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_demux.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_fifo_adapter.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_pipeline_fifo.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_switch.v
VERILOG_SOURCES += ../../lib/pcie/rtl/dma_psdpram.v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_reg_if.v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_reg_if_rd.v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_reg_if_wr.v
# FracTCAM
VERILOG_SOURCES += ../../lib/fractcam/rtl/fractcam/fractcam_top.v
VERILOG_SOURCES += ../../lib/fractcam/rtl/fractcam/fractcam.v
VERILOG_SOURCES += ../../lib/fractcam/rtl/fractcam/fractcam8x5.v
VERILOG_SOURCES += ../../lib/fractcam/rtl/fractcam/and0.v
VERILOG_SOURCES += ../../lib/fractcam/rtl/fractcam/and6.v
VERILOG_SOURCES += ../../lib/fractcam/rtl/fractcam/and6x4.v
# FracTCAM sim
VERILOG_SOURCES += ../../lib/fractcam/rtl/sim/FDRE.v
VERILOG_SOURCES += ../../lib/fractcam/rtl/sim/LUT6.v
VERILOG_SOURCES += ../../lib/fractcam/rtl/sim/RAM32M.v
VERILOG_SOURCES += ../../lib/fractcam/rtl/sim/SRLC32E.v
## Match Pipeline
VERILOG_SOURCES += ../../rtl/match_pipe.v	# TODO: DEBUG match_pipe_0525
# ## Action Pipeline
VERILOG_SOURCES += ../../rtl/action_pipe/action_pipe.v
VERILOG_SOURCES += ../../rtl/action_pipe/axis_ttl_dec.v
VERILOG_SOURCES += ../../rtl/action_pipe/axis_hdr_csum.v
VERILOG_SOURCES += ../../rtl/action_pipe/axis_set_field.v
VERILOG_SOURCES += ../../rtl/action_pipe/set_field_async.v
VERILOG_SOURCES += ../../rtl/action_pipe/axis_vlan_op.v
# ## Parser, deparser 
VERILOG_SOURCES += ../../rtl/axis_parser.v
VERILOG_SOURCES += ../../rtl/axis_deparser.v

# module parameters
export PARAM_AXIS_DATA_WIDTH	?= 512
export PARAM_AXIS_KEEP_WIDTH	?= $(shell python -c "print(int($(PARAM_AXIS_DATA_WIDTH)/8))")
export PARAM_AXIS_RX_ID_WIDTH	?= 4
export PARAM_AXIS_RX_DEST_WIDTH	?= 4
export PARAM_AXIS_RX_USER_WIDTH	?= 4
export PARAM_AXIS_TX_ID_WIDTH	?= 4
export PARAM_AXIS_TX_DEST_WIDTH	?= 4
export PARAM_AXIS_TX_USER_WIDTH	?= 4
export PARAM_AXIL_DATA_WIDTH	?= 32
export PARAM_AXIL_ADDR_WIDTH	?= 10
export PARAM_AXIL_STRB_WIDTH	?= 4
export PARAM_COUNT			?= $(PORTS)

# export PARAM_TCAM_WR_WIDTH		?= 32
# export PARAM_TCAM_DEPTH			?= 16

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_DATA_WIDTH=$(PARAM_AXIS_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_KEEP_WIDTH=$(PARAM_AXIS_KEEP_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_RX_ID_WIDTH=$(PARAM_AXIS_RX_ID_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_RX_DEST_WIDTH=$(PARAM_AXIS_RX_DEST_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_RX_USER_WIDTH=$(PARAM_AXIS_RX_USER_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_TX_ID_WIDTH=$(PARAM_AXIS_TX_ID_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_TX_DEST_WIDTH=$(PARAM_AXIS_TX_DEST_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_TX_USER_WIDTH=$(PARAM_AXIS_TX_USER_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIL_DATA_WIDTH=$(PARAM_AXIL_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIL_ADDR_WIDTH=$(PARAM_AXIL_ADDR_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIL_STRB_WIDTH=$(PARAM_AXIL_STRB_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).COUNT=$(PARAM_COUNT)

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GAXIS_DATA_WIDTH=$(PARAM_AXIS_DATA_WIDTH)
	COMPILE_ARGS += -GAXIS_KEEP_WIDTH=$(PARAM_AXIS_KEEP_WIDTH)
	COMPILE_ARGS += -GAXIS_RX_ID_WIDTH=$(PARAM_AXIS_RX_ID_WIDTH)
	COMPILE_ARGS += -GAXIS_RX_DEST_WIDTH=$(PARAM_AXIS_RX_DEST_WIDTH)
	COMPILE_ARGS += -GAXIS_RX_USER_WIDTH=$(PARAM_AXIS_RX_USER_WIDTH)
	COMPILE_ARGS += -GAXIS_TX_ID_WIDTH=$(PARAM_AXIS_TX_ID_WIDTH)
	COMPILE_ARGS += -GAXIS_TX_DEST_WIDTH=$(PARAM_AXIS_TX_DEST_WIDTH)
	COMPILE_ARGS += -GAXIS_TX_USER_WIDTH=$(PARAM_AXIS_TX_USER_WIDTH)
	COMPILE_ARGS += -GAXIL_DATA_WIDTH=$(PARAM_AXIL_DATA_WIDTH)
	COMPILE_ARGS += -GAXIL_ADDR_WIDTH=$(PARAM_AXIL_ADDR_WIDTH)
	COMPILE_ARGS += -GAXIL_STRB_WIDTH=$(PARAM_AXIL_STRB_WIDTH)
	COMPILE_ARGS += -GCOUNT=$(PARAM_COUNT)

	ifeq ($(WAVES), 1)
		COMPILE_ARGS += --trace-fst
	endif

endif

ifneq ($(filter $(SIM),ius xcelium),)
	SIM_ARGS += -v93
endif
include $(shell cocotb-config --makefiles)/Makefile.sim

$(WRAPPER).v: ../app_top/$(DUT)_wrap.py
	$< -p $(PORTS)

iverilog_dump.v:
	echo 'module iverilog_dump();' > $@
	echo 'initial begin' >> $@
	echo '    $$dumpfile("$(TOPLEVEL).fst");' >> $@
	echo '    $$dumpvars(0, $(TOPLEVEL));' >> $@
	echo 'end' >> $@
	echo 'endmodule' >> $@

clean::
	@rm -rf iverilog_dump.v
	@rm -rf dump.fst *.fst 
	@rm -rf *_wrap_*.v
	@rm -rf __pycache__ *.xml
