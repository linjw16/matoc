/*
 * Created on Sat May 07 2022
 *
 * Copyright (c) 2022 IOA UCAS
 *
 * @Filename:	 app_core.v
 * @Author:		 Jiawei Lin
 * @Last edit:	 19:23:08
 */
// Language: Verilog 2001

/* // TODO list: 
 * 1. ipv4 hdr csum error
 * 2. parser error
 */
 
/* verilator lint_off PINMISSING */
/* verilator lint_off LITENDIAN */
`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Application top interface
 */
module app_core #(
	parameter S_DATA_WIDTH = 512,
	parameter S_KEEP_WIDTH = S_DATA_WIDTH/8,
	parameter S_ID_WIDTH = 8,
	parameter S_DEST_WIDTH = 4,
	parameter S_USER_WIDTH = 4,
	parameter M_DATA_WIDTH = S_DATA_WIDTH,
	parameter M_KEEP_WIDTH = M_DATA_WIDTH/8,
	parameter M_ID_WIDTH = S_ID_WIDTH,
	parameter M_DEST_WIDTH = S_DEST_WIDTH,
	parameter M_USER_WIDTH = S_USER_WIDTH+ACTN_DATA_WIDTH,

	parameter AXIL_ADDR_WIDTH	= 16,
	parameter AXIL_DATA_WIDTH	= 32,
	parameter AXIL_STRB_WIDTH	= AXIL_DATA_WIDTH/8,

	parameter TCAM_WR_WIDTH = 32,
	parameter TCAM_DEPTH = 2**TCAM_ADDR_WIDTH,

	parameter APP_MAT_TYPE = 32'h0102_0304,	/* Vendor, Type */
	parameter APP_MAT_VER = 32'h0000_0100,	/* Major, Minor, Patch, Meta */
	parameter APP_MAT_NP = 32'h0000_0000
) (
	input  wire clk,
	input  wire rst,

	input  wire [S_DATA_WIDTH-1:0] 			s_axis_tdata,
	input  wire [S_KEEP_WIDTH-1:0] 			s_axis_tkeep,
	input  wire 							s_axis_tvalid,
	output wire 							s_axis_tready,
	input  wire 							s_axis_tlast,
	input  wire [S_ID_WIDTH-1:0] 			s_axis_tid,
	input  wire [S_DEST_WIDTH-1:0] 			s_axis_tdest,
	input  wire [S_USER_WIDTH-1:0] 			s_axis_tuser,

	output wire [M_DATA_WIDTH-1:0] 			m_axis_tdata,
	output wire [M_KEEP_WIDTH-1:0] 			m_axis_tkeep,
	output wire 							m_axis_tvalid,
	input  wire 							m_axis_tready,
	output wire 							m_axis_tlast,
	output wire [M_ID_WIDTH-1:0] 			m_axis_tid,
	output wire [M_DEST_WIDTH-1:0] 			m_axis_tdest,
	output wire [M_USER_WIDTH-1:0] 			m_axis_tuser,

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

initial begin
	if (AXIL_DATA_WIDTH != 32) begin
		$error("ERROR: CSR data width are restricted to 32.  (instance %m)");
		$finish;
	end
end

// `define BYPASS_AT
`ifdef BYPASS_AT

assign m_axis_tdata		= s_axis_tdata;
assign m_axis_tkeep		= s_axis_tkeep;
assign m_axis_tvalid	= s_axis_tvalid;
assign s_axis_tready	= m_axis_tready;
assign m_axis_tlast		= s_axis_tlast;
assign m_axis_tid		= s_axis_tid;
assign m_axis_tdest		= s_axis_tdest;
assign m_axis_tuser		= s_axis_tuser;

assign s_axil_awready	= 1'b0;
assign s_axil_wready	= 1'b0;
assign s_axil_bresp		= 2'b00;
assign s_axil_bvalid	= 1'b0;
assign s_axil_arready	= 1'b0;
assign s_axil_rdata		= {AXIL_DATA_WIDTH{1'b0}};
assign s_axil_rresp		= 2'b00;
assign s_axil_rvalid	= 1'b0;

`else

/*
 * 2.1 Control Status Register interface
 */
reg reg_wr_ack_reg;
reg reg_rd_ack_reg;
reg reg_wr_wait_reg = 1'b0, reg_wr_wait_next;		// TODO: rm
reg [AXIL_DATA_WIDTH-1:0] reg_rd_data_reg;

wire [AXIL_ADDR_WIDTH-1:0]	reg_wr_addr;
wire [AXIL_DATA_WIDTH-1:0]	reg_wr_data;
wire [AXIL_STRB_WIDTH-1:0]	reg_wr_strb;
wire 						reg_wr_en;
wire 						reg_wr_wait;
wire 						reg_wr_ack;
wire [AXIL_ADDR_WIDTH-1:0]	reg_rd_addr;
wire 						reg_rd_en;
wire [AXIL_DATA_WIDTH-1:0]	reg_rd_data;
wire 						reg_rd_wait;
wire 						reg_rd_ack;

assign reg_wr_ack = reg_wr_ack_reg || reg_wr_ack_mat;
assign reg_wr_wait = reg_wr_wait_mat || reg_wr_wait_reg; 
assign reg_rd_ack = reg_rd_ack_reg || reg_rd_ack_mat;
assign reg_rd_wait = reg_rd_wait_mat;
assign reg_rd_data = reg_rd_data_reg | reg_rd_data_mat;

axil_reg_if # (
	.DATA_WIDTH					(AXIL_DATA_WIDTH),
	.ADDR_WIDTH					(AXIL_ADDR_WIDTH),
	.STRB_WIDTH					(AXIL_STRB_WIDTH),
	.TIMEOUT					(4)
) axil_reg_if_1 (
	.clk						(clk),
	.rst						(rst),

	.s_axil_awaddr				(s_axil_awaddr	),
	.s_axil_awprot				(s_axil_awprot	),
	.s_axil_awvalid				(s_axil_awvalid	),
	.s_axil_awready				(s_axil_awready	),
	.s_axil_wdata				(s_axil_wdata	),
	.s_axil_wstrb				(s_axil_wstrb	),
	.s_axil_wvalid				(s_axil_wvalid	),
	.s_axil_wready				(s_axil_wready	),
	.s_axil_bresp				(s_axil_bresp	),
	.s_axil_bvalid				(s_axil_bvalid	),
	.s_axil_bready				(s_axil_bready	),
	.s_axil_araddr				(s_axil_araddr	),
	.s_axil_arprot				(s_axil_arprot	),
	.s_axil_arvalid				(s_axil_arvalid	),
	.s_axil_arready				(s_axil_arready	),
	.s_axil_rdata				(s_axil_rdata	),
	.s_axil_rresp				(s_axil_rresp	),
	.s_axil_rvalid				(s_axil_rvalid	),
	.s_axil_rready				(s_axil_rready	),

	.reg_wr_addr				(reg_wr_addr),
	.reg_wr_data				(reg_wr_data),
	.reg_wr_strb				(reg_wr_strb),
	.reg_wr_en					(reg_wr_en),
	.reg_wr_wait				(reg_wr_wait),
	.reg_wr_ack					(reg_wr_ack),
	.reg_rd_addr				(reg_rd_addr),
	.reg_rd_en					(reg_rd_en),
	.reg_rd_data				(reg_rd_data),
	.reg_rd_wait				(reg_rd_wait),
	.reg_rd_ack					(reg_rd_ack)
);

/*
 * 2.2 CSR implementation. 
 */
always @(posedge clk) begin
	reg_wr_ack_reg <= 1'b0;
	reg_rd_data_reg <= {AXIL_DATA_WIDTH{1'b0}};
	reg_rd_ack_reg <= 1'b0;

	if (reg_wr_en && !reg_wr_ack_reg) begin
		// write operation
		reg_wr_ack_reg <= 1'b0;
		case ({reg_wr_addr >> 2, 2'b00})
			16'h0000: reg_rd_data_reg <= reg_wr_data;
			default: reg_wr_ack_reg <= 1'b0;
		endcase
	end else begin
	end

	if (reg_rd_en && !reg_rd_ack_reg) begin
		// read operation
		// reg_rd_ack_reg <= 1'b1;
		case ({reg_rd_addr >> 2, 2'b00})
			16'h0000: reg_rd_data_reg <= APP_MAT_TYPE;
			16'h0004: reg_rd_data_reg <= APP_MAT_VER;
			16'h0008: reg_rd_data_reg <= APP_MAT_NP;
			16'h000C: reg_rd_data_reg <= 32'h05151623;	/* modification time */ 
			default: begin /* save for app_mat csr */ 
				// reg_rd_data_reg <= 32'h1234_ABCD;
				// reg_rd_ack_reg <= 1'b0;
			end
		endcase
	end

	if (rst) begin
		reg_wr_ack_reg <= 1'b0;
		reg_rd_ack_reg <= 1'b0;
	end
end

/*
 * 3. Application core module
 */
localparam TCAM_ADDR_WIDTH = 10;	/* 1024 Depth TCAM Table */
localparam TCAM_DATA_WIDTH = (TCAM_WR_WIDTH+4)/5*5;
localparam ACTN_ADDR_WIDTH = $clog2(TCAM_DEPTH);
localparam ACTN_DATA_WIDTH = 128;
localparam ACTN_STRB_WIDTH = ACTN_DATA_WIDTH/8;
localparam ACTN_EN = 1;

wire reg_wr_wait_mat;
wire reg_wr_ack_mat;
wire reg_rd_wait_mat;
wire reg_rd_ack_mat;
wire [AXIL_DATA_WIDTH-1:0]	reg_rd_data_mat;

app_mat #(
	.S_DATA_WIDTH		(S_DATA_WIDTH),
	.S_KEEP_WIDTH		(S_KEEP_WIDTH),
	.S_ID_WIDTH			(S_ID_WIDTH),
	.S_DEST_WIDTH		(S_DEST_WIDTH),
	.S_USER_WIDTH		(S_USER_WIDTH),
	.M_DATA_WIDTH		(M_DATA_WIDTH),
	.M_KEEP_WIDTH		(M_KEEP_WIDTH),
	.M_ID_WIDTH			(M_ID_WIDTH),
	.M_DEST_WIDTH		(M_DEST_WIDTH),
	.M_USER_WIDTH		(M_USER_WIDTH),

	.REG_ADDR_WIDTH		(AXIL_ADDR_WIDTH),
	.REG_DATA_WIDTH		(AXIL_DATA_WIDTH),
	.REG_STRB_WIDTH		(AXIL_STRB_WIDTH),

	.TCAM_ADDR_WIDTH	(TCAM_ADDR_WIDTH),
	.TCAM_DATA_WIDTH	(TCAM_DATA_WIDTH),
	.TCAM_WR_WIDTH		(TCAM_WR_WIDTH),
	.TCAM_DEPTH			(TCAM_DEPTH),
	.ACTN_ADDR_WIDTH	(ACTN_ADDR_WIDTH),
	.ACTN_DATA_WIDTH	(ACTN_DATA_WIDTH),
	.ACTN_STRB_WIDTH	(ACTN_STRB_WIDTH),
	.ACTN_EN			(ACTN_EN)
) app_mat_1 (
	.clk(clk),
	.rst(rst),

	.s_axis_tdata		(s_axis_tdata),
	.s_axis_tkeep		(s_axis_tkeep),
	.s_axis_tvalid		(s_axis_tvalid),
	.s_axis_tready		(s_axis_tready),
	.s_axis_tlast		(s_axis_tlast),
	.s_axis_tid			(s_axis_tid),
	.s_axis_tdest		(s_axis_tdest),
	.s_axis_tuser		(s_axis_tuser),

	.m_axis_tdata		(m_axis_tdata),
	.m_axis_tkeep		(m_axis_tkeep),
	.m_axis_tvalid		(m_axis_tvalid),
	.m_axis_tready		(m_axis_tready),
	.m_axis_tlast		(m_axis_tlast),
	.m_axis_tid			(m_axis_tid),
	.m_axis_tdest		(m_axis_tdest),
	.m_axis_tuser		(m_axis_tuser),

	.reg_wr_addr		(reg_wr_addr),
	.reg_wr_data		(reg_wr_data),
	.reg_wr_strb		(reg_wr_strb),
	.reg_wr_en			(reg_wr_en),
	.reg_wr_wait		(reg_wr_wait_mat),
	.reg_wr_ack			(reg_wr_ack_mat),
	.reg_rd_addr		(reg_rd_addr),
	.reg_rd_en			(reg_rd_en),
	.reg_rd_data		(reg_rd_data_mat),
	.reg_rd_wait		(reg_rd_wait_mat),
	.reg_rd_ack			(reg_rd_ack_mat)
);

`endif

endmodule

`resetall