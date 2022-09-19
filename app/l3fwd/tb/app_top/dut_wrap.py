#!/usr/bin/env python
"""
Generates an wrapper with the specified number of ports
"""

import argparse
from jinja2 import Template


def main():
	parser = argparse.ArgumentParser(description=__doc__.strip())
	parser.add_argument('-p', '--ports',  type=int, default=4, help="number of ports")
	parser.add_argument('-n', '--name',	type=str, help="module name")
	parser.add_argument('-o', '--output', type=str, help="output file name")

	args = parser.parse_args()

	try:
		generate(**args.__dict__)
	except IOError as ex:
		print(ex)
		exit(1)


def generate(ports=4, name=None, output=None):
	n = ports

	if name is None:
		name = "dut_wrap_{0}".format(n)

	if output is None:
		output = name + ".v"

	print("Generating {0} port AXI stream arbitrated mux wrapper {1}...".format(n, name))

	cn = (n-1).bit_length()

	t = Template(u"""/*

Copyright (c) 2018-2021 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4-Stream {{n}} port arbitrated mux (wrapper)
 */
module {{name}} #
(
	parameter COUNT = 8,

	parameter AXIS_DATA_WIDTH		= 128,
	parameter AXIS_KEEP_WIDTH		= AXIS_DATA_WIDTH/8,
	parameter AXIS_RX_ID_WIDTH		= 8,
	parameter AXIS_RX_DEST_WIDTH	= 4,
	parameter AXIS_RX_USER_WIDTH	= 1,
	parameter AXIS_TX_ID_WIDTH		= 8,
	parameter AXIS_TX_DEST_WIDTH	= 4,
	parameter AXIS_TX_USER_WIDTH	= 1,
	parameter AXIL_ADDR_WIDTH		= 16,
	parameter AXIL_DATA_WIDTH		= 32,
	parameter AXIL_STRB_WIDTH		= AXIL_DATA_WIDTH/8
)
(
	input  wire					clk,
	input  wire					rst,

{%- for p in range(n) %}
	input  wire [AXIS_DATA_WIDTH-1:0]		s{{'%02d'%p}}_axis_rx_tdata,
	input  wire [AXIS_KEEP_WIDTH-1:0]		s{{'%02d'%p}}_axis_rx_tkeep,
	input  wire								s{{'%02d'%p}}_axis_rx_tvalid,
	output wire								s{{'%02d'%p}}_axis_rx_tready,
	input  wire								s{{'%02d'%p}}_axis_rx_tlast,
	input  wire [AXIS_RX_ID_WIDTH-1:0]		s{{'%02d'%p}}_axis_rx_tid,
	input  wire [AXIS_RX_DEST_WIDTH-1:0]	s{{'%02d'%p}}_axis_rx_tdest,
	input  wire [AXIS_RX_USER_WIDTH-1:0]	s{{'%02d'%p}}_axis_rx_tuser,
{% endfor %}

{%- for p in range(n) %}
	output wire [AXIS_DATA_WIDTH-1:0]		m{{'%02d'%p}}_axis_rx_tdata,
	output wire [AXIS_KEEP_WIDTH-1:0]		m{{'%02d'%p}}_axis_rx_tkeep,
	output wire								m{{'%02d'%p}}_axis_rx_tvalid,
	input  wire								m{{'%02d'%p}}_axis_rx_tready,
	output wire								m{{'%02d'%p}}_axis_rx_tlast,
	output wire [AXIS_RX_ID_WIDTH-1:0]		m{{'%02d'%p}}_axis_rx_tid,
	output wire [AXIS_RX_DEST_WIDTH-1:0]	m{{'%02d'%p}}_axis_rx_tdest,
	output wire [AXIS_RX_USER_WIDTH-1:0]	m{{'%02d'%p}}_axis_rx_tuser,
{% endfor %}

{%- for p in range(n) %}
	input  wire	[AXIS_DATA_WIDTH-1:0]		s{{'%02d'%p}}_axis_tx_tdata,
	input  wire	[AXIS_KEEP_WIDTH-1:0]		s{{'%02d'%p}}_axis_tx_tkeep,
	input  wire								s{{'%02d'%p}}_axis_tx_tvalid,
	output wire								s{{'%02d'%p}}_axis_tx_tready,
	input  wire								s{{'%02d'%p}}_axis_tx_tlast,
	input  wire	[AXIS_TX_ID_WIDTH-1:0]		s{{'%02d'%p}}_axis_tx_tid,
	input  wire	[AXIS_TX_DEST_WIDTH-1:0]	s{{'%02d'%p}}_axis_tx_tdest,
	input  wire	[AXIS_TX_USER_WIDTH-1:0]	s{{'%02d'%p}}_axis_tx_tuser,
{% endfor %}

{%- for p in range(n) %}
	output wire	[AXIS_DATA_WIDTH-1:0]		m{{'%02d'%p}}_axis_tx_tdata,
	output wire	[AXIS_KEEP_WIDTH-1:0]		m{{'%02d'%p}}_axis_tx_tkeep,
	output wire								m{{'%02d'%p}}_axis_tx_tvalid,
	input  wire								m{{'%02d'%p}}_axis_tx_tready,
	output wire								m{{'%02d'%p}}_axis_tx_tlast,
	output wire	[AXIS_TX_ID_WIDTH-1:0]		m{{'%02d'%p}}_axis_tx_tid,
	output wire	[AXIS_TX_DEST_WIDTH-1:0]	m{{'%02d'%p}}_axis_tx_tdest,
	output wire	[AXIS_TX_USER_WIDTH-1:0]	m{{'%02d'%p}}_axis_tx_tuser,
{% endfor %}

	input  wire [AXIL_ADDR_WIDTH-1:0]		s_axil_awaddr,
	input  wire [2:0]						s_axil_awprot,
	input  wire								s_axil_awvalid,
	output wire								s_axil_awready,
	input  wire [AXIL_DATA_WIDTH-1:0]		s_axil_wdata,
	input  wire [AXIL_STRB_WIDTH-1:0]		s_axil_wstrb,
	input  wire								s_axil_wvalid,
	output wire								s_axil_wready,
	output wire [1:0]						s_axil_bresp,
	output wire								s_axil_bvalid,
	input  wire								s_axil_bready,
	input  wire [AXIL_ADDR_WIDTH-1:0]		s_axil_araddr,
	input  wire [2:0]						s_axil_arprot,
	input  wire								s_axil_arvalid,
	output wire								s_axil_arready,
	output wire [AXIL_DATA_WIDTH-1:0]		s_axil_rdata,
	output wire [1:0]						s_axil_rresp,
	output wire								s_axil_rvalid,
	input  wire								s_axil_rready
);

app_top #(
	.COUNT					({{n}}),
	.AXIS_DATA_WIDTH		(AXIS_DATA_WIDTH),
	.AXIS_KEEP_WIDTH		(AXIS_KEEP_WIDTH),
	.AXIS_TX_ID_WIDTH		(AXIS_TX_ID_WIDTH),
	.AXIS_RX_ID_WIDTH		(AXIS_RX_ID_WIDTH),
	.AXIS_TX_DEST_WIDTH		(AXIS_TX_DEST_WIDTH),
	.AXIS_RX_DEST_WIDTH		(AXIS_RX_DEST_WIDTH),
	.AXIS_TX_USER_WIDTH		(AXIS_TX_USER_WIDTH),
	.AXIS_RX_USER_WIDTH		(AXIS_RX_USER_WIDTH),
	.AXIL_ADDR_WIDTH		(AXIL_ADDR_WIDTH),
	.AXIL_DATA_WIDTH		(AXIL_DATA_WIDTH),
	.AXIL_STRB_WIDTH		(AXIL_STRB_WIDTH)
) app_top_1 (

	.clk					(clk),
	.rst					(rst),

	.s_axis_rx_tdata	({ {% for p in range(n-1,-1,-1) %}s{{'%02d'%p}}_axis_rx_tdata{% if not loop.last %}, {% endif %}{% endfor %} }),
	.s_axis_rx_tkeep	({ {% for p in range(n-1,-1,-1) %}s{{'%02d'%p}}_axis_rx_tkeep{% if not loop.last %}, {% endif %}{% endfor %} }),
	.s_axis_rx_tvalid	({ {% for p in range(n-1,-1,-1) %}s{{'%02d'%p}}_axis_rx_tvalid{% if not loop.last %}, {% endif %}{% endfor %} }),
	.s_axis_rx_tready	({ {% for p in range(n-1,-1,-1) %}s{{'%02d'%p}}_axis_rx_tready{% if not loop.last %}, {% endif %}{% endfor %} }),
	.s_axis_rx_tlast	({ {% for p in range(n-1,-1,-1) %}s{{'%02d'%p}}_axis_rx_tlast{% if not loop.last %}, {% endif %}{% endfor %} }),
	.s_axis_rx_tid		({ {% for p in range(n-1,-1,-1) %}s{{'%02d'%p}}_axis_rx_tid{% if not loop.last %}, {% endif %}{% endfor %} }),
	.s_axis_rx_tdest	({ {% for p in range(n-1,-1,-1) %}s{{'%02d'%p}}_axis_rx_tdest{% if not loop.last %}, {% endif %}{% endfor %} }),
	.s_axis_rx_tuser	({ {% for p in range(n-1,-1,-1) %}s{{'%02d'%p}}_axis_rx_tuser{% if not loop.last %}, {% endif %}{% endfor %} }),

	.m_axis_rx_tdata	({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axis_rx_tdata{% if not loop.last %}, {% endif %}{% endfor %} }),
	.m_axis_rx_tkeep	({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axis_rx_tkeep{% if not loop.last %}, {% endif %}{% endfor %} }),
	.m_axis_rx_tvalid	({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axis_rx_tvalid{% if not loop.last %}, {% endif %}{% endfor %} }),
	.m_axis_rx_tready	({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axis_rx_tready{% if not loop.last %}, {% endif %}{% endfor %} }),
	.m_axis_rx_tlast	({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axis_rx_tlast{% if not loop.last %}, {% endif %}{% endfor %} }),
	.m_axis_rx_tid		({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axis_rx_tid{% if not loop.last %}, {% endif %}{% endfor %} }),
	.m_axis_rx_tdest	({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axis_rx_tdest{% if not loop.last %}, {% endif %}{% endfor %} }),
	.m_axis_rx_tuser	({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axis_rx_tuser{% if not loop.last %}, {% endif %}{% endfor %} }),

	.s_axis_tx_tdata	({ {% for p in range(n-1,-1,-1) %}s{{'%02d'%p}}_axis_tx_tdata{% if not loop.last %}, {% endif %}{% endfor %} }),
	.s_axis_tx_tkeep	({ {% for p in range(n-1,-1,-1) %}s{{'%02d'%p}}_axis_tx_tkeep{% if not loop.last %}, {% endif %}{% endfor %} }),
	.s_axis_tx_tvalid	({ {% for p in range(n-1,-1,-1) %}s{{'%02d'%p}}_axis_tx_tvalid{% if not loop.last %}, {% endif %}{% endfor %} }),
	.s_axis_tx_tready	({ {% for p in range(n-1,-1,-1) %}s{{'%02d'%p}}_axis_tx_tready{% if not loop.last %}, {% endif %}{% endfor %} }),
	.s_axis_tx_tlast	({ {% for p in range(n-1,-1,-1) %}s{{'%02d'%p}}_axis_tx_tlast{% if not loop.last %}, {% endif %}{% endfor %} }),
	.s_axis_tx_tid		({ {% for p in range(n-1,-1,-1) %}s{{'%02d'%p}}_axis_tx_tid{% if not loop.last %}, {% endif %}{% endfor %} }),
	.s_axis_tx_tdest	({ {% for p in range(n-1,-1,-1) %}s{{'%02d'%p}}_axis_tx_tdest{% if not loop.last %}, {% endif %}{% endfor %} }),
	.s_axis_tx_tuser	({ {% for p in range(n-1,-1,-1) %}s{{'%02d'%p}}_axis_tx_tuser{% if not loop.last %}, {% endif %}{% endfor %} }),

	.m_axis_tx_tdata	({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axis_tx_tdata{% if not loop.last %}, {% endif %}{% endfor %} }),
	.m_axis_tx_tkeep	({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axis_tx_tkeep{% if not loop.last %}, {% endif %}{% endfor %} }),
	.m_axis_tx_tvalid	({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axis_tx_tvalid{% if not loop.last %}, {% endif %}{% endfor %} }),
	.m_axis_tx_tready	({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axis_tx_tready{% if not loop.last %}, {% endif %}{% endfor %} }),
	.m_axis_tx_tlast	({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axis_tx_tlast{% if not loop.last %}, {% endif %}{% endfor %} }),
	.m_axis_tx_tid		({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axis_tx_tid{% if not loop.last %}, {% endif %}{% endfor %} }),
	.m_axis_tx_tdest	({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axis_tx_tdest{% if not loop.last %}, {% endif %}{% endfor %} }),
	.m_axis_tx_tuser	({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axis_tx_tuser{% if not loop.last %}, {% endif %}{% endfor %} }),

	.s_axil_awaddr			(s_axil_awaddr),
	.s_axil_awprot			(s_axil_awprot),
	.s_axil_awvalid			(s_axil_awvalid),
	.s_axil_awready			(s_axil_awready),
	.s_axil_wdata			(s_axil_wdata),
	.s_axil_wstrb			(s_axil_wstrb),
	.s_axil_wvalid			(s_axil_wvalid),
	.s_axil_wready			(s_axil_wready),
	.s_axil_bresp			(s_axil_bresp),
	.s_axil_bvalid			(s_axil_bvalid),
	.s_axil_bready			(s_axil_bready),
	.s_axil_araddr			(s_axil_araddr),
	.s_axil_arprot			(s_axil_arprot),
	.s_axil_arvalid			(s_axil_arvalid),
	.s_axil_arready			(s_axil_arready),
	.s_axil_rdata			(s_axil_rdata),
	.s_axil_rresp			(s_axil_rresp),
	.s_axil_rvalid			(s_axil_rvalid),
	.s_axil_rready			(s_axil_rready)
);

endmodule

`resetall

""")

	print(f"Writing file '{output}'...")

	with open(output, 'w') as f:
		f.write(t.render(
			n=n,
			cn=cn,
			name=name
		))
		f.flush()

	print("Done")


if __name__ == "__main__":
	main()
