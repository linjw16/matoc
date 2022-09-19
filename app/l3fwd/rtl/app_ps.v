/*
 * Created on Thu May 26 2022
 *
 * Copyright (c) 2022 IOA UCAS
 *
 * @Filename:	 app_ps.v
 * @Author:		 Jiawei Lin
 * @Last edit:	 11:41:15
 */

module app_ps #(
	parameter AXIS_DATA_WIDTH	= 512,
	parameter AXIS_KEEP_WIDTH	= AXIS_DATA_WIDTH/8,
	parameter AXIS_ID_WIDTH		= 8,
	parameter AXIS_DEST_WIDTH	= 4,
	parameter AXIS_USER_WIDTH	= 128,

	parameter AXIS_KEEP_ENABLE	= AXIS_DATA_WIDTH>8,
	parameter AXIS_LAST_ENABLE	= 1,
	parameter AXIS_ID_ENABLE	= 1,
	parameter AXIS_DEST_ENABLE	= 1,
	parameter AXIS_USER_ENABLE	= 1,

	parameter AXIL_ADDR_WIDTH	= 16,
	parameter AXIL_DATA_WIDTH	= 32,
	parameter AXIL_STRB_WIDTH	= AXIL_DATA_WIDTH/8,

	parameter ENABLE = 1
) (
	input  wire clk,
	input  wire rst,

	input  wire [AXIS_DATA_WIDTH-1:0]	s_axis_tdata,
	input  wire [AXIS_KEEP_WIDTH-1:0]	s_axis_tkeep,
	input  wire 						s_axis_tvalid,
	output wire 						s_axis_tready,
	input  wire 						s_axis_tlast,
	input  wire [AXIS_ID_WIDTH-1:0]		s_axis_tid,
	input  wire [AXIS_DEST_WIDTH-1:0]	s_axis_tdest,
	input  wire [AXIS_USER_WIDTH-1:0]	s_axis_tuser,

	output wire [AXIS_DATA_WIDTH-1:0]	m_axis_tdata,
	output wire [AXIS_KEEP_WIDTH-1:0]	m_axis_tkeep,
	output wire 						m_axis_tvalid,
	input  wire 						m_axis_tready,
	output wire 						m_axis_tlast,
	output wire [AXIS_ID_WIDTH-1:0]		m_axis_tid,
	output wire [AXIS_DEST_WIDTH-1:0]	m_axis_tdest,
	output wire [AXIS_USER_WIDTH-1:0]	m_axis_tuser,

	input  wire [AXIL_ADDR_WIDTH-1:0]	s_axil_awaddr,
	input  wire [2:0]					s_axil_awprot,
	input  wire							s_axil_awvalid,
	output wire							s_axil_awready,
	input  wire [AXIL_DATA_WIDTH-1:0]	s_axil_wdata,
	input  wire [AXIL_STRB_WIDTH-1:0]	s_axil_wstrb,
	input  wire							s_axil_wvalid,
	output wire							s_axil_wready,
	output wire [1:0]					s_axil_bresp,
	output wire							s_axil_bvalid,
	input  wire							s_axil_bready,
	input  wire [AXIL_ADDR_WIDTH-1:0]	s_axil_araddr,
	input  wire [2:0]					s_axil_arprot,
	input  wire							s_axil_arvalid,
	output wire							s_axil_arready,
	output wire [AXIL_DATA_WIDTH-1:0]	s_axil_rdata,
	output wire [1:0]					s_axil_rresp,
	output wire							s_axil_rvalid,
	input  wire							s_axil_rready
);

/*
 * 5.1 Zynq PS
 */
localparam AXIS_PS_DATA_WIDTH = 128;
localparam AXIS_PS_KEEP_WIDTH = AXIS_PS_DATA_WIDTH/8;
localparam AXIS_PS_ID_WIDTH = 8;
localparam AXIS_PS_DEST_WIDTH = 4;
localparam AXIS_PS_USER_WIDTH = 8;

// AXI lite interface configuration (control from ps)
localparam AXIL_PS_ADDR_WIDTH = 24;
localparam AXIL_PS_DATA_WIDTH = 32;
localparam AXIL_PS_STRB_WIDTH = (AXIL_PS_DATA_WIDTH/8);

wire ps_clk;
wire ps_rst;

wire [AXIS_PS_DATA_WIDTH-1:0]	s_axis_ps_tdata, m_axis_ps_tdata;
wire [AXIS_PS_KEEP_WIDTH-1:0]	s_axis_ps_tkeep, m_axis_ps_tkeep;
wire							s_axis_ps_tvalid, m_axis_ps_tvalid;
wire							s_axis_ps_tready, m_axis_ps_tready;
wire							s_axis_ps_tlast, m_axis_ps_tlast;
wire [AXIS_PS_ID_WIDTH-1:0]		s_axis_ps_tid, m_axis_ps_tid;
wire [AXIS_PS_DEST_WIDTH-1:0]	s_axis_ps_tdest, m_axis_ps_tdest;
wire [AXIS_PS_USER_WIDTH-1:0]	s_axis_ps_tuser, m_axis_ps_tuser;

`define BYPASS_PS
`ifdef BYPASS_PS

assign ps_clk = clk;
assign ps_rst = rst;

assign m_axis_tdata = s_axis_tdata;
assign m_axis_tkeep = s_axis_tkeep;
assign m_axis_tvalid = s_axis_tvalid;
assign s_axis_tready = m_axis_tready;
assign m_axis_tlast = s_axis_tlast;
assign m_axis_tid = s_axis_tid;
assign m_axis_tdest = s_axis_tdest;
assign m_axis_tuser = s_axis_tuser;

assign s_axil_awready = 0;
assign s_axil_wready = 0;
assign s_axil_bresp = 0;
assign s_axil_bvalid = 0;
assign s_axil_arready = 0;
assign s_axil_rdata = 0;
assign s_axil_rresp = 0;
assign s_axil_rvalid = 0;

`else

zynq_soc zynq_soc_inst (
	.clk(ps_clk),
	.rst(ps_rst),

	.m_axil_araddr			(s_axil_araddr),
	.m_axil_arprot			(s_axil_arprot),
	.m_axil_arready			(s_axil_arready),
	.m_axil_arvalid			(s_axil_arvalid),
	.m_axil_awaddr			(s_axil_awaddr),
	.m_axil_awprot			(s_axil_awprot),
	.m_axil_awready			(s_axil_awready),
	.m_axil_awvalid			(s_axil_awvalid),
	.m_axil_bready			(s_axil_bready),
	.m_axil_bresp			(s_axil_bresp),
	.m_axil_bvalid			(s_axil_bvalid),
	.m_axil_rdata			(s_axil_rdata),
	.m_axil_rready			(s_axil_rready),
	.m_axil_rresp			(s_axil_rresp),
	.m_axil_rvalid			(s_axil_rvalid),
	.m_axil_wdata			(s_axil_wdata),
	.m_axil_wready			(s_axil_wready),
	.m_axil_wstrb			(s_axil_wstrb),
	.m_axil_wvalid			(s_axil_wvalid),

	.s_axis_tdata			(s_axis_ps_tdata),
	.s_axis_tkeep			(s_axis_ps_tkeep),
	.s_axis_tvalid			(s_axis_ps_tvalid),
	.s_axis_tready			(s_axis_ps_tready),
	.s_axis_tlast			(s_axis_ps_tlast),/*
	.s_axis_tid				(s_axis_ps_tid),
	.s_axis_tdest			(s_axis_ps_tdest),
	.s_axis_tuser			(s_axis_ps_tuser),*/

	.m_axis_tdata			(m_axis_ps_tdata),
	.m_axis_tkeep			(m_axis_ps_tkeep),
	.m_axis_tvalid			(m_axis_ps_tvalid),
	.m_axis_tready			(m_axis_ps_tready),
	.m_axis_tlast			(m_axis_ps_tlast)/*,
	.m_axis_tid				(m_axis_ps_tid),
	.m_axis_tdest			(m_axis_ps_tdest),
	.m_axis_tuser			(m_axis_ps_tuser)*/
);

assign m_axis_ps_tid = s_axis_ps_tid;
assign m_axis_ps_tdest = s_axis_ps_tdest;
assign m_axis_ps_tuser = s_axis_ps_tuser;

/*
 * 5.2 PKTIN datapath
 */
localparam EXPAND = AXIS_DATA_WIDTH < AXIL_PS_DATA_WIDTH;
localparam PS_FIFO_DEPTH = EXPAND ? AXIS_PS_KEEP_WIDTH*2 : AXIS_KEEP_WIDTH*2;
localparam PS_PIPELINE = 2;
localparam FRAME_FIFO = 0;
localparam USER_BAD_FRAME_VALUE = 1'b1;
localparam USER_BAD_FRAME_MASK = 1'b1;
localparam DROP_OVERSIZE_FRAME = 0;
localparam DROP_BAD_FRAME = 0;
localparam DROP_WHEN_FULL = 0;

axis_async_fifo_adapter # (
	.DEPTH						(PS_FIFO_DEPTH),
	.S_DATA_WIDTH				(AXIS_DATA_WIDTH),
	.S_KEEP_WIDTH				(AXIS_KEEP_WIDTH),
	.M_DATA_WIDTH				(AXIS_PS_DATA_WIDTH),
	.M_KEEP_WIDTH				(AXIS_PS_KEEP_WIDTH),
	.ID_WIDTH					(AXIS_ID_WIDTH),
	.DEST_WIDTH					(AXIS_DEST_WIDTH),
	.USER_WIDTH					(AXIS_USER_WIDTH),
	.S_KEEP_ENABLE				(AXIS_KEEP_ENABLE),
	.M_KEEP_ENABLE				(1),
	.ID_ENABLE					(AXIS_ID_ENABLE),
	.DEST_ENABLE				(AXIS_DEST_ENABLE),
	.USER_ENABLE				(AXIS_USER_ENABLE),
	.PIPELINE_OUTPUT			(PS_PIPELINE),
	.FRAME_FIFO					(FRAME_FIFO),
	.USER_BAD_FRAME_VALUE		(USER_BAD_FRAME_VALUE),
	.USER_BAD_FRAME_MASK		(USER_BAD_FRAME_MASK),
	.DROP_OVERSIZE_FRAME		(DROP_OVERSIZE_FRAME),
	.DROP_BAD_FRAME				(DROP_BAD_FRAME),
	.DROP_WHEN_FULL				(DROP_WHEN_FULL) 
) adapter_pktin (
	.s_clk(clk),
	.s_rst(rst),
	.s_axis_tdata				(s_axis_tdata),
	.s_axis_tkeep				(s_axis_tkeep),
	.s_axis_tvalid				(s_axis_tvalid),
	.s_axis_tready				(s_axis_tready),
	.s_axis_tlast				(s_axis_tlast),
	.s_axis_tid					(s_axis_tid),
	.s_axis_tdest				(s_axis_tdest),
	.s_axis_tuser				(s_axis_tuser),

	.m_clk						(ps_clk),
	.m_rst						(ps_rst),
	.m_axis_tdata				(s_axis_ps_tdata),
	.m_axis_tkeep				(s_axis_ps_tkeep),
	.m_axis_tvalid				(s_axis_ps_tvalid),
	.m_axis_tready				(s_axis_ps_tready),
	.m_axis_tlast				(s_axis_ps_tlast),
	.m_axis_tid					(s_axis_ps_tid),
	.m_axis_tdest				(s_axis_ps_tdest),
	.m_axis_tuser				(s_axis_ps_tuser)/*,

	.s_status_overflow			(),
	.s_status_bad_frame			(),
	.s_status_good_frame		(),
	.m_status_overflow			(),
	.m_status_bad_frame			(),
	.m_status_good_frame		()*/
);

/*
 * 5.3 PKTOUT datapath
 */

axis_async_fifo_adapter # (
	.DEPTH						(PS_FIFO_DEPTH),
	.S_DATA_WIDTH				(AXIS_PS_DATA_WIDTH),
	.S_KEEP_WIDTH				(AXIS_PS_KEEP_WIDTH),
	.M_DATA_WIDTH				(AXIS_DATA_WIDTH),
	.M_KEEP_WIDTH				(AXIS_KEEP_WIDTH),
	.ID_WIDTH					(AXIS_ID_WIDTH),
	.DEST_WIDTH					(AXIS_DEST_WIDTH),
	.USER_WIDTH					(AXIS_USER_WIDTH),
	.S_KEEP_ENABLE				(1),
	.M_KEEP_ENABLE				(AXIS_KEEP_ENABLE),
	.ID_ENABLE					(AXIS_ID_ENABLE),
	.DEST_ENABLE				(AXIS_DEST_ENABLE),
	.USER_ENABLE				(AXIS_USER_ENABLE),
	.PIPELINE_OUTPUT			(PS_PIPELINE),
	.FRAME_FIFO					(FRAME_FIFO),
	.USER_BAD_FRAME_VALUE		(USER_BAD_FRAME_VALUE),
	.USER_BAD_FRAME_MASK		(USER_BAD_FRAME_MASK),
	.DROP_OVERSIZE_FRAME		(DROP_OVERSIZE_FRAME),
	.DROP_BAD_FRAME				(DROP_BAD_FRAME),
	.DROP_WHEN_FULL				(DROP_WHEN_FULL) 
) adapter_pktout (
	.s_clk						(ps_clk),
	.s_rst						(ps_rst),
	.s_axis_tdata				(m_axis_ps_tdata),
	.s_axis_tkeep				(m_axis_ps_tkeep),
	.s_axis_tvalid				(m_axis_ps_tvalid),
	.s_axis_tready				(m_axis_ps_tready),
	.s_axis_tlast				(m_axis_ps_tlast),
/*	.s_axis_tid					(m_axis_ps_tid),
	.s_axis_tdest				(m_axis_ps_tdest),
	.s_axis_tuser				(m_axis_ps_tuser),*/

	.m_clk						(clk),
	.m_rst						(rst),
	.m_axis_tdata				(m_axis_tdata),
	.m_axis_tkeep				(m_axis_tkeep),
	.m_axis_tvalid				(m_axis_tvalid),
	.m_axis_tready				(m_axis_tready),
	.m_axis_tlast				(m_axis_tlast)/*,
	.m_axis_tid					(m_axis_tid),
	.m_axis_tdest				(m_axis_tdest),
	.m_axis_tuser				(m_axis_tuser),

	.s_status_overflow			(),
	.s_status_bad_frame			(),
	.s_status_good_frame		(),
	.m_status_overflow			(),
	.m_status_bad_frame			(),
	.m_status_good_frame		() */
);

`endif

endmodule