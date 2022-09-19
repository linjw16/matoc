/*
 * Created on Sun May 15 2022
 *
 * Copyright (c) 2022 IOA UCAS
 *
 * @Filename:	 zynq_soc.v
 * @Author:		 Jiawei Lin
 * @Last edit:	 19:14:15
 */
module zynq_soc #(
	parameter AXIS_DATA_WIDTH = 128,
	parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
	parameter AXIS_ID_WIDTH = 8,
	parameter AXIS_DEST_WIDTH = 4,
	parameter AXIS_USER_WIDTH = 8,
	parameter AXIL_ADDR_WIDTH = 24,
	parameter AXIL_DATA_WIDTH = 32,
	parameter AXIL_STRB_WIDTH = AXIL_DATA_WIDTH/8
) (
	output wire clk,
	output wire rst,

	output wire [AXIL_ADDR_WIDTH-1:0]	m_axil_awaddr,
	output wire [2:0]					m_axil_awprot,
	output wire							m_axil_awvalid,
	input  wire							m_axil_awready,
	output wire [AXIL_DATA_WIDTH-1:0]	m_axil_wdata,
	output wire [AXIL_STRB_WIDTH-1:0]	m_axil_wstrb,
	output wire							m_axil_wvalid,
	input  wire							m_axil_wready,
	input  wire [1:0]					m_axil_bresp,
	input  wire							m_axil_bvalid,
	output wire							m_axil_bready,
	output wire [AXIL_ADDR_WIDTH-1:0]	m_axil_araddr,
	output wire [2:0]					m_axil_arprot,
	output wire							m_axil_arvalid,
	input  wire							m_axil_arready,
	input  wire [AXIL_DATA_WIDTH-1:0]	m_axil_rdata,
	input  wire [1:0]					m_axil_rresp,
	input  wire							m_axil_rvalid,
	output wire							m_axil_rready,

	input  wire [AXIS_DATA_WIDTH-1:0]	s_axis_tdata,
	input  wire [AXIS_KEEP_WIDTH-1:0]	s_axis_tkeep,
	input  wire							s_axis_tvalid,
	output wire							s_axis_tready,
	input  wire							s_axis_tlast,
	input  wire [AXIS_ID_WIDTH-1:0]		s_axis_tid,
	input  wire [AXIS_DEST_WIDTH-1:0]	s_axis_tdest,
	input  wire [AXIS_USER_WIDTH-1:0]	s_axis_tuser,

	output wire [AXIS_DATA_WIDTH-1:0]	m_axis_tdata,
	output wire [AXIS_KEEP_WIDTH-1:0]	m_axis_tkeep,
	output wire							m_axis_tvalid,
	input  wire							m_axis_tready,
	output wire							m_axis_tlast,
	output wire [AXIS_ID_WIDTH-1:0]		m_axis_tid,
	output wire [AXIS_DEST_WIDTH-1:0]	m_axis_tdest,
	output wire [AXIS_USER_WIDTH-1:0]	m_axis_tuser
);

assign m_axis_tdata = s_axis_tdata;
assign m_axis_tkeep = s_axis_tkeep;
assign m_axis_tvalid = s_axis_tvalid;
assign s_axis_tready = m_axis_tready;
assign m_axis_tlast = s_axis_tlast;
assign m_axis_tid = s_axis_tid;
assign m_axis_tdest = s_axis_tdest;
assign m_axis_tuser = s_axis_tuser;

assign m_axil_awaddr	= {AXIL_ADDR_WIDTH{1'b0}};
assign m_axil_awprot	= 2'b00;
assign m_axil_awvalid	= 1'b0;
assign m_axil_wdata		= {AXIL_DATA_WIDTH{1'b0}};
assign m_axil_wstrb		= {AXIL_STRB_WIDTH{1'b0}};
assign m_axil_wvalid	= 1'b0;
assign m_axil_bready	= 1'b1;
assign m_axil_araddr	= {AXIL_ADDR_WIDTH{1'b0}};
assign m_axil_arprot	= 2'b00;
assign m_axil_arvalid	= 1'b0;
assign m_axil_rready	= 1'b1;

endmodule