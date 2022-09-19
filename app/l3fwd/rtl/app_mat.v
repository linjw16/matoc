/*
 * Created on Sun Apr 24 2022
 *
 * Copyright (c) 2022 IOA UCAS
 *
 * @Filename:	 app_mat.v
 * @Author:		 Jiawei Lin
 * @Last edit:	 20:07:56
 */
/* verilator lint_off PINMISSING */
/* verilator lint_off LITENDIAN */
`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Application core module
 */
module app_mat #(
	parameter S_DATA_WIDTH = 600,
	parameter S_KEEP_WIDTH = S_DATA_WIDTH/8,
	parameter S_ID_WIDTH = 8,
	parameter S_DEST_WIDTH = 4,
	parameter S_USER_WIDTH = 128+4+32,
	parameter M_DATA_WIDTH = S_DATA_WIDTH,
	parameter M_KEEP_WIDTH =  M_DATA_WIDTH/8,
	parameter M_ID_WIDTH = S_ID_WIDTH,
	parameter M_DEST_WIDTH = S_DEST_WIDTH,
	parameter M_USER_WIDTH = S_USER_WIDTH,
	
	parameter REG_ADDR_WIDTH	= 16,
	parameter REG_DATA_WIDTH	= 32,
	parameter REG_STRB_WIDTH	= REG_DATA_WIDTH/8,

	parameter TCAM_ADDR_WIDTH	= 10,
	parameter TCAM_DATA_WIDTH	= (TCAM_WR_WIDTH+4)/5*5,
	parameter TCAM_WR_WIDTH		= 32,
	parameter TCAM_DEPTH		= 16,
	parameter ACTN_ADDR_WIDTH	= $clog2(TCAM_DEPTH),
	parameter ACTN_DATA_WIDTH	= 128,
	parameter ACTN_STRB_WIDTH	= ACTN_DATA_WIDTH/8,
	parameter ACTN_EN			= 1,
	parameter ACTN_OFFSET		= 4
) (
	input  wire clk,
	input  wire rst,

	input  wire [S_DATA_WIDTH-1:0]			s_axis_tdata,
	input  wire [S_KEEP_WIDTH-1:0]			s_axis_tkeep,
	input  wire								s_axis_tvalid,
	output wire								s_axis_tready,
	input  wire								s_axis_tlast,
	input  wire [S_ID_WIDTH-1:0]			s_axis_tid,
	input  wire [S_DEST_WIDTH-1:0]			s_axis_tdest,
	input  wire [S_USER_WIDTH-1:0]			s_axis_tuser,	/* dst_ipv4, pkt_type, tuer */

	output wire [M_DATA_WIDTH-1:0]			m_axis_tdata,
	output wire [M_KEEP_WIDTH-1:0]			m_axis_tkeep,
	output wire								m_axis_tvalid,
	input  wire								m_axis_tready,
	output wire								m_axis_tlast,
	output wire [M_ID_WIDTH-1:0]			m_axis_tid,
	output wire [M_DEST_WIDTH-1:0]			m_axis_tdest,
	output wire [M_USER_WIDTH-1:0]			m_axis_tuser,

	input  wire [REG_ADDR_WIDTH-1:0]		reg_wr_addr,
	input  wire [REG_DATA_WIDTH-1:0]		reg_wr_data,
	input  wire [REG_STRB_WIDTH-1:0]		reg_wr_strb,
	input  wire								reg_wr_en,
	output wire								reg_wr_wait,
	output wire								reg_wr_ack,
	input  wire [REG_ADDR_WIDTH-1:0]		reg_rd_addr,
	input  wire								reg_rd_en,
	output wire [REG_DATA_WIDTH-1:0]		reg_rd_data,
	output wire								reg_rd_wait,
	output wire								reg_rd_ack
);

function [15:0] byte_rvs_2 (input [15:0] in_1);
	byte_rvs_2 = {in_1[7:0], in_1[15:8]};
endfunction

function [31:0] byte_rvs_4(input [31:0] in_1);
	byte_rvs_4 = {byte_rvs_2(in_1[15:0]), byte_rvs_2(in_1[31:16])};
endfunction

// wire [32-1:0] dbg_ipv4_dst_psr = byte_rvs_4(axis_hdr_psr_tdata[240 +: 32]);
wire [32-1:0] dbg_ipv4_dst_mch = byte_rvs_4(axis_hdr_mch_tdata[240 +: 32]);
wire [32-1:0] dbg_ipv4_src_act = byte_rvs_4(axis_hdr_act_tdata[240 +: 32]);
wire [32-1:0] dbg_ipv4_dst_act = byte_rvs_4(axis_hdr_act_tdata[240+32 +: 32]);
wire [32-1:0] dbg_ipv4_dst_in = byte_rvs_4(s_axis_tdata[240 +: 32]);
// wire [32-1:0] dbg_ipv4_dst_fifo = byte_rvs_4(axis_fifo_tdata[240 +: 32]);
// wire [32-1:0] dbg_ipv4_src_dps = byte_rvs_4(axis_dps_tdata[240 +: 32]);
// wire [32-1:0] dbg_ipv4_dst_dps = byte_rvs_4(axis_dps_tdata[240+32 +: 32]);

reg [32-1:0] dbg_ipv4_dst_psr_reg = 0, dbg_ipv4_dst_psr_next;
reg [32-1:0] dbg_ipv4_dst_mch_reg = 0, dbg_ipv4_dst_mch_next;
reg [32-1:0] dbg_ipv4_src_act_reg = 0, dbg_ipv4_src_act_next;
reg [32-1:0] dbg_ipv4_dst_act_reg = 0, dbg_ipv4_dst_act_next;
reg [32-1:0] dbg_ipv4_dst_in_reg = 0, dbg_ipv4_dst_in_next;
reg [32-1:0] dbg_ipv4_dst_fifo_reg = 0, dbg_ipv4_dst_fifo_next;
reg [32-1:0] dbg_ipv4_src_dps_reg = 0, dbg_ipv4_src_dps_next;
reg [32-1:0] dbg_ipv4_dst_dps_reg = 0, dbg_ipv4_dst_dps_next;

always @(*) begin
	dbg_ipv4_dst_psr_next = dbg_ipv4_dst_psr_reg;
	dbg_ipv4_dst_mch_next = dbg_ipv4_dst_mch_reg;
	dbg_ipv4_src_act_next = dbg_ipv4_src_act_reg;
	dbg_ipv4_dst_act_next = dbg_ipv4_dst_act_reg;
	dbg_ipv4_dst_in_next = dbg_ipv4_dst_in_reg;
	dbg_ipv4_dst_fifo_next = dbg_ipv4_dst_fifo_reg;
	dbg_ipv4_src_dps_next = dbg_ipv4_src_dps_reg;
	dbg_ipv4_dst_dps_next = dbg_ipv4_dst_dps_reg;
	dbg_cnt_next = dbg_cnt_reg;

	// if (axis_hdr_psr_tvalid && axis_hdr_psr_tready) begin
	// 	dbg_cnt_next[0*32+:32] = dbg_cnt_reg[0*32+:32]+1;
	// 	dbg_ipv4_dst_psr_next = dbg_ipv4_dst_psr;
	// end
	if (axis_hdr_mch_tvalid && axis_hdr_mch_tready) begin
		dbg_cnt_next[1*32+:32] = dbg_cnt_reg[1*32+:32]+1;
		dbg_ipv4_dst_mch_next = dbg_ipv4_dst_mch;
	end
	if (axis_hdr_act_tvalid && axis_hdr_act_tready) begin
		dbg_cnt_next[2*32+:32] = dbg_cnt_reg[2*32+:32]+1;
		dbg_ipv4_src_act_next = dbg_ipv4_src_act;
		dbg_ipv4_dst_act_next = dbg_ipv4_dst_act;
	end
	if (s_axis_tvalid && s_axis_tready) begin
		dbg_cnt_next[3*32+:32] = dbg_cnt_reg[3*32+:32]+1;
		dbg_ipv4_dst_in_next = dbg_ipv4_dst_in;
	end
	// if (axis_psr_tvalid && axis_psr_tready) begin
	// 	dbg_cnt_next[4*32+:32] = dbg_cnt_reg[4*32+:32]+1;
	// end
	// if (axis_fifo_tvalid && axis_fifo_tready) begin
	// 	dbg_cnt_next[5*32+:32] = dbg_cnt_reg[5*32+:32]+1;
	// 	dbg_ipv4_dst_fifo_next = dbg_ipv4_dst_fifo;
	// end
	// if (axis_dps_tvalid && axis_dps_tready) begin
	// 	dbg_cnt_next[6*32+:32] = dbg_cnt_reg[6*32+:32]+1;
	// 	dbg_ipv4_src_dps_next = dbg_ipv4_src_dps;
	// 	dbg_ipv4_dst_dps_next = dbg_ipv4_dst_dps;
	// end
	if (m_axis_tvalid && m_axis_tready) begin
		dbg_cnt_next[7*32+:32] = dbg_cnt_reg[7*32+:32]+1;
	end

end

always @(posedge clk) begin
	if (rst | clear_reg) begin
		dbg_cnt_reg <= {CNT_NUM*REG_DATA_WIDTH{1'b0}};
		dbg_ipv4_dst_psr_reg <= 0;
		dbg_ipv4_dst_mch_reg <= 0;
		dbg_ipv4_src_act_reg <= 0;
		dbg_ipv4_dst_act_reg <= 0;
		dbg_ipv4_dst_in_reg <= 0;
		dbg_ipv4_dst_fifo_reg <= 0;
		dbg_ipv4_src_dps_reg <= 0;
		dbg_ipv4_dst_dps_reg <= 0;
	end else begin
		dbg_cnt_reg <= dbg_cnt_next;
		dbg_ipv4_dst_psr_reg	<= dbg_ipv4_dst_psr_next;
		dbg_ipv4_dst_mch_reg	<= dbg_ipv4_dst_mch_next;
		dbg_ipv4_src_act_reg	<= dbg_ipv4_src_act_next;
		dbg_ipv4_dst_act_reg	<= dbg_ipv4_dst_act_next;
		dbg_ipv4_dst_in_reg		<= dbg_ipv4_dst_in_next;
		dbg_ipv4_dst_fifo_reg	<= dbg_ipv4_dst_fifo_next;
		dbg_ipv4_src_dps_reg	<= dbg_ipv4_src_dps_next;
		dbg_ipv4_dst_dps_reg	<= dbg_ipv4_dst_dps_next;
	end
end
/*
 * 1. CSR define
 */
localparam BAR_CSR = 16'h0020;	/* size: 0x04 */
localparam BAR_ACTN_WR_DATA = 16'h0010;	/* size: 0x10 */
localparam BAR_ACTN_RD_DATA = 16'h0050;	/* size: 0x10 */
localparam BAR_TCAM_RD_DATA = 16'h0060;	/* size: 0x10 */
localparam BAR_TCAM_RD_KEEP = 16'h0070;	/* size: 0x10 */
localparam BAR_TCAM_WR_DATA = 16'h0100;	/* size: 0x80 */
localparam BAR_TCAM_WR_KEEP = 16'h0180;	/* size: 0x80 */
localparam BAR_CNT = 16'h0200;	/* size: 0x20 */
localparam BAR_CLR = 16'h0220;	/* size: 0x04 */
localparam BAR_TRACE = 16'h0230;	/* size: 0x20 */

localparam CSR_TCAM_RD = 14, CSR_ACTN_RD = 30;
localparam CSR_TCAM_WR = 15, CSR_ACTN_WR = 31;
localparam CSR_TCAM_OFFSET = 0, CSR_TCAM_WIDTH = 16;
localparam CSR_ACTN_OFFSET = CSR_TCAM_OFFSET+CSR_TCAM_WIDTH, CSR_ACTN_WIDTH = 16;
localparam CNT_NUM = 8;

reg  [8*TCAM_WR_WIDTH-1:0] tcam_wr_data_reg = {8*TCAM_WR_WIDTH{1'b0}};
reg  [8*TCAM_WR_WIDTH-1:0] tcam_wr_keep_reg = {8*TCAM_WR_WIDTH{1'b0}};
reg  [ACTN_DATA_WIDTH-1:0] actn_wr_data_reg = {ACTN_DATA_WIDTH{1'b0}};
reg  [ACTN_STRB_WIDTH-1:0] actn_wr_strb_reg = {ACTN_STRB_WIDTH{1'b1}};
reg  [REG_DATA_WIDTH-1:0] csr_data_reg = {REG_DATA_WIDTH{1'b0}}, csr_data_next;
reg  [CNT_NUM*REG_DATA_WIDTH-1:0] dbg_cnt_reg = {CNT_NUM*REG_DATA_WIDTH{1'b0}}, dbg_cnt_next;
reg  clear_reg = 1'b0;

/*
 * 1.2 CSR Implementation
 */
reg reg_wr_ack_reg = 1'b0, reg_wr_ack_next;
reg reg_rd_ack_reg = 1'b0, reg_rd_ack_next;
reg reg_wr_wait_reg = 1'b0, reg_wr_wait_next;		// TODO: rm
reg [REG_DATA_WIDTH-1:0] reg_rd_data_reg;
reg reg_rd_wait_reg = 1'b0, reg_rd_wait_next;

assign reg_rd_ack = reg_rd_ack_reg;
assign reg_rd_data = reg_rd_data_reg;
assign reg_rd_wait = reg_rd_wait_reg;
assign reg_wr_ack = reg_wr_ack_reg;
assign reg_wr_wait = !tcam_wr_ready || !actn_wr_cmd_ready;

always @(*) begin
	reg_rd_ack_next = 1'b0;
	// reg_rd_ack_next = reg_rd_ack_reg;
	reg_rd_wait_next = reg_rd_wait_reg;
	reg_wr_ack_next = reg_wr_ack_reg;
	csr_data_next = csr_data_reg;
	if (tcam_wr_valid && tcam_wr_ready) begin
		csr_data_next = csr_data_next & {{CSR_ACTN_WIDTH{1'b1}},{CSR_TCAM_WIDTH{1'b0}}};
		reg_wr_ack_next = 1'b0;
	end
	if (tcam_rd_cmd_valid && tcam_rd_cmd_ready) begin
		csr_data_next = csr_data_next & {{CSR_ACTN_WIDTH{1'b1}},{CSR_TCAM_WIDTH{1'b0}}};
		reg_wr_ack_next = 1'b0;
		reg_rd_wait_next = 1'b1;
	end
	if (tcam_rd_rsp_valid && tcam_rd_rsp_ready) begin
		csr_data_next = csr_data_next & {{CSR_ACTN_WIDTH{1'b1}},{CSR_TCAM_WIDTH{1'b0}}};
		reg_rd_ack_next = 1'b0;
		reg_rd_wait_next = 1'b0;
	end
	if (actn_wr_cmd_valid && actn_wr_cmd_ready) begin
		csr_data_next = csr_data_next & {{CSR_ACTN_WIDTH{1'b0}},{CSR_TCAM_WIDTH{1'b1}}};
		reg_wr_ack_next = 1'b0;
	end
	if (actn_rd_cmd_valid && actn_rd_cmd_ready) begin
		csr_data_next = csr_data_next & {{CSR_ACTN_WIDTH{1'b0}},{CSR_TCAM_WIDTH{1'b1}}};
		reg_wr_ack_next = 1'b0;
		reg_rd_wait_next = 1'b1;
	end
	if (actn_rd_rsp_valid && actn_rd_rsp_ready) begin
		csr_data_next = csr_data_next & {{CSR_ACTN_WIDTH{1'b0}},{CSR_TCAM_WIDTH{1'b1}}};
		reg_rd_ack_next = 1'b0;
		reg_rd_wait_next = 1'b0;
	end
end

always @(posedge clk) begin
	reg_rd_data_reg <= 32'h0000_0000;
	reg_rd_ack_reg <= reg_rd_ack_next;
	reg_wr_ack_reg <= reg_wr_ack_next;
	reg_rd_wait_reg <= reg_rd_wait_next;

	if (reg_wr_en && !reg_wr_ack_reg) begin
		// write operation
		case ({reg_wr_addr >> 2, 2'b00})
			BAR_TCAM_WR_DATA+16'h0000: tcam_wr_data_reg[0*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0004: tcam_wr_data_reg[1*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0008: tcam_wr_data_reg[2*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h000C: tcam_wr_data_reg[3*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0010: tcam_wr_data_reg[4*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0014: tcam_wr_data_reg[5*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0018: tcam_wr_data_reg[6*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h001C: tcam_wr_data_reg[7*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;/*
			BAR_TCAM_WR_DATA+16'h0020: tcam_wr_data_reg[8*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0024: tcam_wr_data_reg[9*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0028: tcam_wr_data_reg[10*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h002C: tcam_wr_data_reg[11*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0030: tcam_wr_data_reg[12*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0034: tcam_wr_data_reg[13*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0038: tcam_wr_data_reg[14*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h003C: tcam_wr_data_reg[15*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0040: tcam_wr_data_reg[16*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0044: tcam_wr_data_reg[17*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0048: tcam_wr_data_reg[18*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h004C: tcam_wr_data_reg[19*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0050: tcam_wr_data_reg[20*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0054: tcam_wr_data_reg[21*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0058: tcam_wr_data_reg[22*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h005C: tcam_wr_data_reg[23*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0060: tcam_wr_data_reg[24*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0064: tcam_wr_data_reg[25*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0068: tcam_wr_data_reg[26*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h006C: tcam_wr_data_reg[27*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0070: tcam_wr_data_reg[28*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0074: tcam_wr_data_reg[29*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h0078: tcam_wr_data_reg[30*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_DATA+16'h007C: tcam_wr_data_reg[31*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;*/

			BAR_TCAM_WR_KEEP+16'h0000: tcam_wr_keep_reg[0*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0004: tcam_wr_keep_reg[1*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0008: tcam_wr_keep_reg[2*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h000C: tcam_wr_keep_reg[3*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0010: tcam_wr_keep_reg[4*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0014: tcam_wr_keep_reg[5*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0018: tcam_wr_keep_reg[6*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h001C: tcam_wr_keep_reg[7*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;/* 
			BAR_TCAM_WR_KEEP+16'h0020: tcam_wr_keep_reg[8*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0024: tcam_wr_keep_reg[9*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0028: tcam_wr_keep_reg[10*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h002C: tcam_wr_keep_reg[11*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0030: tcam_wr_keep_reg[12*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0034: tcam_wr_keep_reg[13*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0038: tcam_wr_keep_reg[14*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h003C: tcam_wr_keep_reg[15*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0040: tcam_wr_keep_reg[16*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0044: tcam_wr_keep_reg[17*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0048: tcam_wr_keep_reg[18*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h004C: tcam_wr_keep_reg[19*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0050: tcam_wr_keep_reg[20*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0054: tcam_wr_keep_reg[21*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0058: tcam_wr_keep_reg[22*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h005C: tcam_wr_keep_reg[23*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0060: tcam_wr_keep_reg[24*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0064: tcam_wr_keep_reg[25*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0068: tcam_wr_keep_reg[26*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h006C: tcam_wr_keep_reg[27*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0070: tcam_wr_keep_reg[28*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0074: tcam_wr_keep_reg[29*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h0078: tcam_wr_keep_reg[30*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;
			BAR_TCAM_WR_KEEP+16'h007C: tcam_wr_keep_reg[31*REG_DATA_WIDTH +: REG_DATA_WIDTH]	 <= reg_wr_data;*/

			BAR_ACTN_WR_DATA+16'h0000: actn_wr_data_reg[0*REG_DATA_WIDTH +: REG_DATA_WIDTH] <= reg_wr_data;
			BAR_ACTN_WR_DATA+16'h0004: actn_wr_data_reg[1*REG_DATA_WIDTH +: REG_DATA_WIDTH] <= reg_wr_data;
			BAR_ACTN_WR_DATA+16'h0008: actn_wr_data_reg[2*REG_DATA_WIDTH +: REG_DATA_WIDTH] <= reg_wr_data;
			BAR_ACTN_WR_DATA+16'h000C: actn_wr_data_reg[3*REG_DATA_WIDTH +: REG_DATA_WIDTH] <= reg_wr_data;

			BAR_CLR: clear_reg <= reg_wr_data;

			BAR_CSR: begin
				reg_wr_ack_reg <= 1'b1;	/* pause csr for one cycle */
				csr_data_reg <= reg_wr_data;
			end
			default: ; // reg_wr_ack_reg <= 1'b0;
		endcase
	end else begin
		csr_data_reg <= csr_data_next;
	end

	if (reg_rd_en && !reg_rd_ack_reg) begin
		// read operation
		case ({reg_rd_addr >> 2, 2'b00})
			BAR_TCAM_WR_DATA+16'h0000: reg_rd_data_reg <= tcam_wr_data_reg[0*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0004: reg_rd_data_reg <= tcam_wr_data_reg[1*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0008: reg_rd_data_reg <= tcam_wr_data_reg[2*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h000C: reg_rd_data_reg <= tcam_wr_data_reg[3*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0010: reg_rd_data_reg <= tcam_wr_data_reg[4*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0014: reg_rd_data_reg <= tcam_wr_data_reg[5*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0018: reg_rd_data_reg <= tcam_wr_data_reg[6*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h001C: reg_rd_data_reg <= tcam_wr_data_reg[7*REG_DATA_WIDTH +: REG_DATA_WIDTH];/*
			BAR_TCAM_WR_DATA+16'h0020: reg_rd_data_reg <= tcam_wr_data_reg[8*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0024: reg_rd_data_reg <= tcam_wr_data_reg[9*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0028: reg_rd_data_reg <= tcam_wr_data_reg[10*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h002C: reg_rd_data_reg <= tcam_wr_data_reg[11*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0030: reg_rd_data_reg <= tcam_wr_data_reg[12*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0034: reg_rd_data_reg <= tcam_wr_data_reg[13*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0038: reg_rd_data_reg <= tcam_wr_data_reg[14*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h003C: reg_rd_data_reg <= tcam_wr_data_reg[15*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0040: reg_rd_data_reg <= tcam_wr_data_reg[16*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0044: reg_rd_data_reg <= tcam_wr_data_reg[17*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0048: reg_rd_data_reg <= tcam_wr_data_reg[18*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h004C: reg_rd_data_reg <= tcam_wr_data_reg[19*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0050: reg_rd_data_reg <= tcam_wr_data_reg[20*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0054: reg_rd_data_reg <= tcam_wr_data_reg[21*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0058: reg_rd_data_reg <= tcam_wr_data_reg[22*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h005C: reg_rd_data_reg <= tcam_wr_data_reg[23*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0060: reg_rd_data_reg <= tcam_wr_data_reg[24*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0064: reg_rd_data_reg <= tcam_wr_data_reg[25*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0068: reg_rd_data_reg <= tcam_wr_data_reg[26*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h006C: reg_rd_data_reg <= tcam_wr_data_reg[27*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0070: reg_rd_data_reg <= tcam_wr_data_reg[28*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0074: reg_rd_data_reg <= tcam_wr_data_reg[29*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h0078: reg_rd_data_reg <= tcam_wr_data_reg[30*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_DATA+16'h007C: reg_rd_data_reg <= tcam_wr_data_reg[31*REG_DATA_WIDTH +: REG_DATA_WIDTH];*/

			BAR_TCAM_WR_KEEP+16'h0000: reg_rd_data_reg <= tcam_wr_keep_reg[0*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0004: reg_rd_data_reg <= tcam_wr_keep_reg[1*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0008: reg_rd_data_reg <= tcam_wr_keep_reg[2*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h000C: reg_rd_data_reg <= tcam_wr_keep_reg[3*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0010: reg_rd_data_reg <= tcam_wr_keep_reg[4*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0014: reg_rd_data_reg <= tcam_wr_keep_reg[5*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0018: reg_rd_data_reg <= tcam_wr_keep_reg[6*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h001C: reg_rd_data_reg <= tcam_wr_keep_reg[7*REG_DATA_WIDTH +: REG_DATA_WIDTH];/*
			BAR_TCAM_WR_KEEP+16'h0020: reg_rd_data_reg <= tcam_wr_keep_reg[8*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0024: reg_rd_data_reg <= tcam_wr_keep_reg[9*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0028: reg_rd_data_reg <= tcam_wr_keep_reg[10*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h002C: reg_rd_data_reg <= tcam_wr_keep_reg[11*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0030: reg_rd_data_reg <= tcam_wr_keep_reg[12*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0034: reg_rd_data_reg <= tcam_wr_keep_reg[13*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0038: reg_rd_data_reg <= tcam_wr_keep_reg[14*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h003C: reg_rd_data_reg <= tcam_wr_keep_reg[15*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0040: reg_rd_data_reg <= tcam_wr_keep_reg[16*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0044: reg_rd_data_reg <= tcam_wr_keep_reg[17*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0048: reg_rd_data_reg <= tcam_wr_keep_reg[18*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h004C: reg_rd_data_reg <= tcam_wr_keep_reg[19*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0050: reg_rd_data_reg <= tcam_wr_keep_reg[20*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0054: reg_rd_data_reg <= tcam_wr_keep_reg[21*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0058: reg_rd_data_reg <= tcam_wr_keep_reg[22*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h005C: reg_rd_data_reg <= tcam_wr_keep_reg[23*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0060: reg_rd_data_reg <= tcam_wr_keep_reg[24*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0064: reg_rd_data_reg <= tcam_wr_keep_reg[25*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0068: reg_rd_data_reg <= tcam_wr_keep_reg[26*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h006C: reg_rd_data_reg <= tcam_wr_keep_reg[27*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0070: reg_rd_data_reg <= tcam_wr_keep_reg[28*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0074: reg_rd_data_reg <= tcam_wr_keep_reg[29*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h0078: reg_rd_data_reg <= tcam_wr_keep_reg[30*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_WR_KEEP+16'h007C: reg_rd_data_reg <= tcam_wr_keep_reg[31*REG_DATA_WIDTH +: REG_DATA_WIDTH];*/

			BAR_ACTN_WR_DATA+16'h0000: reg_rd_data_reg <= actn_wr_data_reg[0*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_ACTN_WR_DATA+16'h0004: reg_rd_data_reg <= actn_wr_data_reg[1*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_ACTN_WR_DATA+16'h0008: reg_rd_data_reg <= actn_wr_data_reg[2*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_ACTN_WR_DATA+16'h000C: reg_rd_data_reg <= actn_wr_data_reg[3*REG_DATA_WIDTH +: REG_DATA_WIDTH];

			BAR_ACTN_RD_DATA+16'h0000: reg_rd_data_reg <= actn_rd_rsp_data_reg[0*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_ACTN_RD_DATA+16'h0004: reg_rd_data_reg <= actn_rd_rsp_data_reg[1*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_ACTN_RD_DATA+16'h0008: reg_rd_data_reg <= actn_rd_rsp_data_reg[2*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_ACTN_RD_DATA+16'h000C: reg_rd_data_reg <= actn_rd_rsp_data_reg[3*REG_DATA_WIDTH +: REG_DATA_WIDTH];

			BAR_TCAM_RD_DATA+16'h0000: reg_rd_data_reg <= tcam_rd_rsp_data_reg[0*REG_DATA_WIDTH +: REG_DATA_WIDTH];/*
			BAR_TCAM_RD_DATA+16'h0004: reg_rd_data_reg <= tcam_rd_rsp_data_reg[1*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_RD_DATA+16'h0008: reg_rd_data_reg <= tcam_rd_rsp_data_reg[2*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_RD_DATA+16'h000C: reg_rd_data_reg <= tcam_rd_rsp_data_reg[3*REG_DATA_WIDTH +: REG_DATA_WIDTH];*/

			BAR_TCAM_RD_KEEP+16'h0000: reg_rd_data_reg <= tcam_rd_rsp_keep_reg[0*REG_DATA_WIDTH +: REG_DATA_WIDTH];/*
			BAR_TCAM_RD_KEEP+16'h0004: reg_rd_data_reg <= tcam_rd_rsp_keep_reg[1*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_RD_KEEP+16'h0008: reg_rd_data_reg <= tcam_rd_rsp_keep_reg[2*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_TCAM_RD_KEEP+16'h000C: reg_rd_data_reg <= tcam_rd_rsp_keep_reg[3*REG_DATA_WIDTH +: REG_DATA_WIDTH];*/

			BAR_CSR: begin 
				reg_rd_data_reg <= csr_data_reg;	/* addr: 16'h0110 */
				reg_rd_ack_reg <= 1'b1;
			end

			BAR_CNT+16'h0000: reg_rd_data_reg <= dbg_cnt_reg[0*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_CNT+16'h0004: reg_rd_data_reg <= dbg_cnt_reg[1*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_CNT+16'h0008: reg_rd_data_reg <= dbg_cnt_reg[2*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_CNT+16'h000C: reg_rd_data_reg <= dbg_cnt_reg[3*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_CNT+16'h0010: reg_rd_data_reg <= dbg_cnt_reg[4*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_CNT+16'h0014: reg_rd_data_reg <= dbg_cnt_reg[5*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_CNT+16'h0018: reg_rd_data_reg <= dbg_cnt_reg[6*REG_DATA_WIDTH +: REG_DATA_WIDTH];
			BAR_CNT+16'h001C: reg_rd_data_reg <= dbg_cnt_reg[7*REG_DATA_WIDTH +: REG_DATA_WIDTH];

			BAR_CLR: reg_rd_data_reg <= clear_reg;

			BAR_TRACE+16'h0000: reg_rd_data_reg <= dbg_ipv4_dst_psr_reg;
			BAR_TRACE+16'h0004: reg_rd_data_reg <= dbg_ipv4_dst_mch_reg;
			BAR_TRACE+16'h0008: reg_rd_data_reg <= dbg_ipv4_src_act_reg;
			BAR_TRACE+16'h000C: reg_rd_data_reg <= dbg_ipv4_dst_act_reg;
			BAR_TRACE+16'h0010: reg_rd_data_reg <= dbg_ipv4_dst_in_reg;
			BAR_TRACE+16'h0014: reg_rd_data_reg <= dbg_ipv4_dst_fifo_reg;
			BAR_TRACE+16'h0018: reg_rd_data_reg <= dbg_ipv4_src_dps_reg;
			BAR_TRACE+16'h001C: reg_rd_data_reg <= dbg_ipv4_dst_dps_reg;
			default: begin
			end
		endcase
	end

	if (rst | clear_reg) begin
		clear_reg <= 1'b0;
		reg_wr_ack_reg <= 1'b0;
		reg_rd_ack_reg <= 1'b0;
	end
end

/*
 * 2.1 Match Action Table
 */

/*
 * CSR format:
 * 	[31]		Action write enable
 * 	[30]		Action read enable
 * 	[29:16]		Action address
 * 	[15]		TCAM write enable
 * 	[14]		TCAM read enable
 * 	[9:0]		TCAM address
 */
localparam HDR_USER_WIDTH = S_USER_WIDTH + ACTN_DATA_WIDTH;

wire [S_DATA_WIDTH-1:0]		axis_hdr_mch_tdata;
wire [S_KEEP_WIDTH-1:0]		axis_hdr_mch_tkeep;
wire						axis_hdr_mch_tvalid;
wire						axis_hdr_mch_tready;
wire						axis_hdr_mch_tlast;
wire [S_ID_WIDTH-1:0]		axis_hdr_mch_tid;
wire [S_DEST_WIDTH-1:0]		axis_hdr_mch_tdest;
wire [HDR_USER_WIDTH-1:0]	axis_hdr_mch_tuser;

// TODO: 
wire [TCAM_ADDR_WIDTH-1:0]	tcam_wr_addr;
wire [8*TCAM_WR_WIDTH-1:0]	tcam_wr_data;
wire [8*TCAM_WR_WIDTH-1:0]	tcam_wr_keep;
wire						tcam_wr_valid;
wire						tcam_wr_ready;

wire [TCAM_ADDR_WIDTH-1:0]	tcam_rd_cmd_addr;
wire						tcam_rd_cmd_valid;
wire						tcam_rd_cmd_ready;
wire [TCAM_WR_WIDTH-1:0]	tcam_rd_rsp_data;
wire [TCAM_WR_WIDTH-1:0]	tcam_rd_rsp_keep;
wire						tcam_rd_rsp_valid;
wire						tcam_rd_rsp_ready;

wire [ACTN_ADDR_WIDTH-1:0]	actn_wr_cmd_addr;
wire [ACTN_DATA_WIDTH-1:0]	actn_wr_cmd_data;
wire [ACTN_STRB_WIDTH-1:0]	actn_wr_cmd_strb;
wire						actn_wr_cmd_valid;
wire						actn_wr_cmd_ready;
wire						actn_wr_cmd_done;

wire [ACTN_ADDR_WIDTH-1:0]	actn_rd_cmd_addr;
wire						actn_rd_cmd_valid;
wire						actn_rd_cmd_ready;
wire [ACTN_DATA_WIDTH-1:0]	actn_rd_rsp_data;
wire						actn_rd_rsp_valid;
wire						actn_rd_rsp_ready;

assign tcam_wr_data = tcam_wr_data_reg;
assign tcam_wr_keep = tcam_wr_keep_reg;
assign tcam_wr_addr = csr_data_reg[CSR_TCAM_OFFSET +: TCAM_ADDR_WIDTH];
assign tcam_wr_valid = csr_data_reg[CSR_TCAM_WR];
assign tcam_rd_cmd_addr = csr_data_reg[CSR_TCAM_OFFSET +: TCAM_ADDR_WIDTH];
assign tcam_rd_cmd_valid = csr_data_reg[CSR_TCAM_RD];
assign tcam_rd_rsp_ready = 1'b1;
assign actn_wr_cmd_addr = csr_data_reg[CSR_ACTN_OFFSET +: ACTN_ADDR_WIDTH];
assign actn_wr_cmd_valid = csr_data_reg[CSR_ACTN_WR];
assign actn_wr_cmd_data = actn_wr_data_reg;
assign actn_wr_cmd_strb = actn_wr_strb_reg;
assign actn_rd_cmd_addr = csr_data_reg[CSR_ACTN_OFFSET +: ACTN_ADDR_WIDTH];
assign actn_rd_cmd_valid = csr_data_reg[CSR_ACTN_RD];
assign actn_rd_rsp_ready = 1'b1;

match_pipe #(
	.S_DATA_WIDTH			(S_DATA_WIDTH),
	.S_KEEP_WIDTH			(S_KEEP_WIDTH),
	.S_ID_WIDTH				(S_ID_WIDTH),
	.S_DEST_WIDTH			(S_DEST_WIDTH),
	.S_USER_WIDTH			(S_USER_WIDTH),
	.M_DATA_WIDTH			(S_DATA_WIDTH),
	.M_KEEP_WIDTH			(S_KEEP_WIDTH),
	.M_ID_WIDTH				(S_ID_WIDTH),
	.M_DEST_WIDTH			(S_DEST_WIDTH),
	.M_USER_WIDTH			(HDR_USER_WIDTH),

	.FRACTCAM_ENABLE		(1),
	.TCAM_ADDR_WIDTH		(TCAM_ADDR_WIDTH),
	.TCAM_DATA_WIDTH		(TCAM_DATA_WIDTH),
	.TCAM_WR_WIDTH			(TCAM_WR_WIDTH),
	.TCAM_DEPTH				(TCAM_DEPTH),
	.ACTN_ADDR_WIDTH		(ACTN_ADDR_WIDTH),
	.ACTN_DATA_WIDTH		(ACTN_DATA_WIDTH),
	.ACTN_STRB_WIDTH		(ACTN_STRB_WIDTH)
) match_pipe_inst (
	.clk(clk),
	.rst(rst),

	.s_axis_tdata			(s_axis_tdata),
	.s_axis_tkeep			(s_axis_tkeep),
	.s_axis_tvalid			(s_axis_tvalid),
	.s_axis_tready			(s_axis_tready),
	.s_axis_tlast			(s_axis_tlast),
	.s_axis_tid				(s_axis_tid),
	.s_axis_tdest			(s_axis_tdest),
	.s_axis_tuser			(s_axis_tuser),

	.m_axis_tdata			(axis_hdr_mch_tdata),
	.m_axis_tkeep			(axis_hdr_mch_tkeep),
	.m_axis_tvalid			(axis_hdr_mch_tvalid),
	.m_axis_tready			(axis_hdr_mch_tready),
	.m_axis_tlast			(axis_hdr_mch_tlast),
	.m_axis_tid				(axis_hdr_mch_tid),
	.m_axis_tdest			(axis_hdr_mch_tdest),
	.m_axis_tuser			(axis_hdr_mch_tuser),

	.tcam_wr_addr			(tcam_wr_addr),
	.tcam_wr_data			(tcam_wr_data),
	.tcam_wr_keep			(tcam_wr_keep),
	.tcam_wr_valid			(tcam_wr_valid),
	.tcam_wr_ready			(tcam_wr_ready),

	.tcam_rd_cmd_addr		(tcam_rd_cmd_addr),
	.tcam_rd_cmd_valid		(tcam_rd_cmd_valid),
	.tcam_rd_cmd_ready		(tcam_rd_cmd_ready),
	.tcam_rd_rsp_data		(tcam_rd_rsp_data),
	.tcam_rd_rsp_keep		(tcam_rd_rsp_keep),
	.tcam_rd_rsp_valid		(tcam_rd_rsp_valid),
	.tcam_rd_rsp_ready		(tcam_rd_rsp_ready),

	.actn_wr_cmd_addr		(actn_wr_cmd_addr),
	.actn_wr_cmd_data		(actn_wr_cmd_data),
	.actn_wr_cmd_strb		(actn_wr_cmd_strb),
	.actn_wr_cmd_valid		(actn_wr_cmd_valid),
	.actn_wr_cmd_ready		(actn_wr_cmd_ready),
	.actn_wr_cmd_done		(actn_wr_cmd_done),

	.actn_rd_cmd_addr		(actn_rd_cmd_addr),
	.actn_rd_cmd_valid		(actn_rd_cmd_valid),
	.actn_rd_cmd_ready		(actn_rd_cmd_ready),
	.actn_rd_rsp_data		(actn_rd_rsp_data),
	.actn_rd_rsp_valid		(actn_rd_rsp_valid),
	.actn_rd_rsp_ready		(actn_rd_rsp_ready)
);

reg  [TCAM_WR_WIDTH-1:0]	tcam_rd_rsp_data_reg = {TCAM_WR_WIDTH{1'b0}}, tcam_rd_rsp_data_next;
reg  [TCAM_WR_WIDTH-1:0]	tcam_rd_rsp_keep_reg = {TCAM_WR_WIDTH{1'b0}}, tcam_rd_rsp_keep_next;
reg  [ACTN_DATA_WIDTH-1:0]	actn_rd_rsp_data_reg = {ACTN_DATA_WIDTH{1'b0}}, actn_rd_rsp_data_next;

always @(*) begin
	tcam_rd_rsp_data_next = tcam_rd_rsp_data_reg;
	tcam_rd_rsp_keep_next = tcam_rd_rsp_keep_reg;
	if (tcam_rd_rsp_valid && tcam_rd_rsp_ready) begin
		tcam_rd_rsp_data_next = tcam_rd_rsp_data;
		tcam_rd_rsp_keep_next = tcam_rd_rsp_keep;
	end	

	actn_rd_rsp_data_next = actn_rd_rsp_data_reg;
	if (actn_rd_rsp_valid && actn_rd_rsp_ready) begin
		actn_rd_rsp_data_next = actn_rd_rsp_data;
	end	
end

always @(posedge clk) begin
	if (rst) begin
		tcam_rd_rsp_data_reg <= {TCAM_WR_WIDTH{1'b0}};
		tcam_rd_rsp_keep_reg <= {TCAM_WR_WIDTH{1'b0}};
		actn_rd_rsp_data_reg <= {ACTN_DATA_WIDTH{1'b0}};
	end else begin
		tcam_rd_rsp_data_reg <= tcam_rd_rsp_data_next;
		tcam_rd_rsp_keep_reg <= tcam_rd_rsp_keep_next;
		actn_rd_rsp_data_reg <= actn_rd_rsp_data_next;
	end
end

/*
 * 2.2 Action processor
 */
localparam IPv4_WIDTH = 32;
localparam PT_WIDTH = 4;
localparam PT_OFFSET = S_USER_WIDTH-IPv4_WIDTH-PT_WIDTH;

wire [M_DATA_WIDTH-1:0]	axis_hdr_act_tdata;
wire [M_KEEP_WIDTH-1:0]	axis_hdr_act_tkeep;
wire					axis_hdr_act_tvalid;
wire					axis_hdr_act_tready;
wire					axis_hdr_act_tlast;
wire [M_ID_WIDTH-1:0]	axis_hdr_act_tid;
wire [M_DEST_WIDTH-1:0]	axis_hdr_act_tdest;
wire [M_USER_WIDTH-1:0]	axis_hdr_act_tuser;

action_pipe #(
	.S_DATA_WIDTH			(S_DATA_WIDTH),
	.S_KEEP_WIDTH			(S_KEEP_WIDTH),
	.S_ID_WIDTH				(S_ID_WIDTH),
	.S_DEST_WIDTH			(S_DEST_WIDTH),
	.S_USER_WIDTH			(HDR_USER_WIDTH),
	.M_DATA_WIDTH			(M_DATA_WIDTH),
	.M_KEEP_WIDTH			(M_KEEP_WIDTH),
	.M_ID_WIDTH				(M_ID_WIDTH),
	.M_DEST_WIDTH			(M_DEST_WIDTH),
	.M_USER_WIDTH			(M_USER_WIDTH),
	.PT_OFFSET				(PT_OFFSET),
	.ENABLE					(ACTN_EN)
) action_pipe_inst (
	.clk(clk),
	.rst(rst),

	.s_axis_tdata			(axis_hdr_mch_tdata		),
	.s_axis_tkeep			(axis_hdr_mch_tkeep		),
	.s_axis_tvalid			(axis_hdr_mch_tvalid	),
	.s_axis_tready			(axis_hdr_mch_tready	),
	.s_axis_tlast			(axis_hdr_mch_tlast		),
	.s_axis_tid				(axis_hdr_mch_tid		),
	.s_axis_tdest			(axis_hdr_mch_tdest		),
	.s_axis_tuser			(axis_hdr_mch_tuser		),

	.m_axis_tdata			(axis_hdr_act_tdata		),
	.m_axis_tkeep			(axis_hdr_act_tkeep		),
	.m_axis_tvalid			(axis_hdr_act_tvalid	),
	.m_axis_tready			(axis_hdr_act_tready	),
	.m_axis_tlast			(axis_hdr_act_tlast		),
	.m_axis_tid				(axis_hdr_act_tid		),
	.m_axis_tdest			(axis_hdr_act_tdest		),
	.m_axis_tuser			(axis_hdr_act_tuser		)
);

assign m_axis_tdata		= axis_hdr_act_tdata;
assign m_axis_tkeep		= axis_hdr_act_tkeep;
assign m_axis_tvalid	= axis_hdr_act_tvalid;
assign axis_hdr_act_tready	= m_axis_tready;
assign m_axis_tlast		= axis_hdr_act_tlast;
assign m_axis_tid		= axis_hdr_act_tid;
assign m_axis_tdest		= axis_hdr_act_tdest;
assign m_axis_tuser		= axis_hdr_act_tuser;

endmodule

`resetall