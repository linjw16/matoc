/*
 * Created on Sat Feb 26 2022
 *
 * Copyright (c) 2022 IOA UCAS
 *
 * @Filename:	 axis_hdr_csum.v
 * @Author:		 Xiaoying Huang, Jiawei Lin
 * @Last edit:	 23:17:59
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Header checksum offload module
 */
module axis_hdr_csum  #(
	parameter S_DATA_WIDTH = 512,
	parameter S_KEEP_WIDTH = S_DATA_WIDTH/8,
	parameter S_ID_WIDTH = 8,
	parameter S_DEST_WIDTH = 4,
	parameter S_USER_WIDTH = 4,
	parameter M_DATA_WIDTH = S_DATA_WIDTH,
	parameter M_KEEP_WIDTH =  M_DATA_WIDTH/8,
	parameter M_ID_WIDTH = S_ID_WIDTH,
	parameter M_DEST_WIDTH = S_DEST_WIDTH,
	parameter M_USER_WIDTH = S_USER_WIDTH,

	parameter CSUM_DATA_WIDTH = 160,
	parameter ENABLE = 1
)(
	input  wire clk,
	input  wire rst,
	
	input  wire 						csum_enable,
	input  wire [CL_DATA_WIDTH-1:0]		csum_start,
	input  wire [CL_DATA_WIDTH-1:0]		csum_offset,

	input  wire [S_DATA_WIDTH-1:0] 		s_axis_tdata,
	input  wire [S_KEEP_WIDTH-1:0] 		s_axis_tkeep,
	input  wire 						s_axis_tvalid,
	output wire 						s_axis_tready,
	input  wire 						s_axis_tlast,
	input  wire [S_ID_WIDTH-1:0] 		s_axis_tid,	
	input  wire [S_DEST_WIDTH-1:0] 		s_axis_tdest,	
	input  wire [S_USER_WIDTH-1:0]		s_axis_tuser,

	output wire [M_DATA_WIDTH-1:0] 		m_axis_tdata,
	output wire [M_KEEP_WIDTH-1:0] 		m_axis_tkeep,
	output wire 						m_axis_tvalid,
	input  wire 						m_axis_tready,
	output wire 						m_axis_tlast,
	output wire [M_ID_WIDTH-1:0] 		m_axis_tid,
	output wire [M_DEST_WIDTH-1:0] 		m_axis_tdest,
	output wire [M_USER_WIDTH-1:0]		m_axis_tuser
);

function [15:0] byte_rvs_2 (input [15:0] in_1);
	byte_rvs_2 = {in_1[7:0], in_1[15:8]};
endfunction

/*
 * 1. Calculate checksum. 
 */
localparam CSUM_WIDTH = 16;
localparam CL_DATA_WIDTH = $clog2(S_DATA_WIDTH);

reg  [CSUM_DATA_WIDTH-1:0] ipv4_hdr_reg = {CSUM_DATA_WIDTH{1'b0}}, ipv4_hdr_next;
reg  csum_enable_reg = 1'b0, csum_enable_next;
wire [CSUM_WIDTH-1:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7, a_8, a_9;
wire [CSUM_WIDTH+4-1:0] sum;
wire [CSUM_WIDTH+1-1:0] sum_cin_1;
wire [CSUM_WIDTH-1:0] sum_cin_2, csum;

assign {a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7, a_8, a_9} = ipv4_hdr_reg;
assign sum = 
	byte_rvs_2(a_0)+
	byte_rvs_2(a_1)+
	byte_rvs_2(a_2)+
	byte_rvs_2(a_3)+
	byte_rvs_2(a_5)+
	byte_rvs_2(a_6)+
	byte_rvs_2(a_7)+
	byte_rvs_2(a_8)+
	byte_rvs_2(a_9);
// assign sum = a_0+a_1+a_2+a_3+a_5+a_6+a_7+a_8+a_9;
assign sum_cin_1 = sum[CSUM_WIDTH +: 4] + sum[CSUM_WIDTH-1:0];
assign sum_cin_2 = sum_cin_1[CSUM_WIDTH +: 1] + sum_cin_1[CSUM_WIDTH-1:0];
assign csum = ~sum_cin_2;

/*
 * 2. Registered input and output. 
 */
reg  [S_DATA_WIDTH-1:0] 	in_axis_tdata_reg = {S_DATA_WIDTH{1'b0}},	in_axis_tdata_next;
reg  [S_KEEP_WIDTH-1:0] 	in_axis_tkeep_reg = {S_KEEP_WIDTH{1'b0}},	in_axis_tkeep_next;
reg  						in_axis_tvalid_reg = 1'b0,					in_axis_tvalid_next;
wire 						in_axis_tready;
reg  						in_axis_tlast_reg = 1'b0,					in_axis_tlast_next;
reg  [S_ID_WIDTH-1:0] 		in_axis_tid_reg = {S_ID_WIDTH{1'b0}},		in_axis_tid_next;
reg  [S_DEST_WIDTH-1:0] 	in_axis_tdest_reg = {S_DEST_WIDTH{1'b0}},	in_axis_tdest_next;
reg  [S_USER_WIDTH-1:0] 	in_axis_tuser_reg = {S_USER_WIDTH{1'b0}},	in_axis_tuser_next;

reg  [M_DATA_WIDTH-1:0] 	m_axis_tdata_reg = {M_DATA_WIDTH{1'b0}},	m_axis_tdata_next;
reg  [M_KEEP_WIDTH-1:0] 	m_axis_tkeep_reg = {M_KEEP_WIDTH{1'b0}},	m_axis_tkeep_next;
reg  						m_axis_tvalid_reg = 1'b0,					m_axis_tvalid_next;
reg  						m_axis_tlast_reg = 1'b0,					m_axis_tlast_next;
reg  [M_ID_WIDTH-1:0] 		m_axis_tid_reg = {M_ID_WIDTH{1'b0}},		m_axis_tid_next;
reg  [M_DEST_WIDTH-1:0] 	m_axis_tdest_reg = {M_DEST_WIDTH{1'b0}},	m_axis_tdest_next;
reg  [M_USER_WIDTH-1:0]		m_axis_tuser_reg = {M_USER_WIDTH{1'b0}},	m_axis_tuser_next;

assign in_axis_tready = !m_axis_tvalid_reg || m_axis_tready;

if (ENABLE) begin
	assign m_axis_tdata = m_axis_tdata_reg;
	assign m_axis_tkeep = m_axis_tkeep_reg;
	assign m_axis_tvalid = m_axis_tvalid_reg;
	assign s_axis_tready = !in_axis_tvalid_reg || in_axis_tready;
	assign m_axis_tlast = m_axis_tlast_reg;
	assign m_axis_tid = m_axis_tid_reg;
	assign m_axis_tdest = m_axis_tdest_reg;
	assign m_axis_tuser = m_axis_tuser_reg;
end else begin
	assign m_axis_tdata = s_axis_tdata;
	assign m_axis_tkeep = s_axis_tkeep;
	assign m_axis_tvalid = s_axis_tvalid;
	assign s_axis_tready = m_axis_tready;
	assign m_axis_tlast = s_axis_tlast;
	assign m_axis_tid = s_axis_tid;
	assign m_axis_tdest = s_axis_tdest;
	assign m_axis_tuser = s_axis_tuser;
end

always @(*) begin
	ipv4_hdr_next = ipv4_hdr_reg;
	csum_enable_next = csum_enable_reg;

	in_axis_tdata_next = in_axis_tdata_reg;
	in_axis_tkeep_next = in_axis_tkeep_reg;
	in_axis_tvalid_next = in_axis_tvalid_reg;
	in_axis_tlast_next = in_axis_tlast_reg;
	in_axis_tid_next = in_axis_tid_reg;
	in_axis_tdest_next = in_axis_tdest_reg;
	in_axis_tuser_next = in_axis_tuser_reg;

	m_axis_tdata_next = m_axis_tdata_reg;
	m_axis_tkeep_next = m_axis_tkeep_reg;
	m_axis_tvalid_next = m_axis_tvalid_reg;
	m_axis_tlast_next = m_axis_tlast_reg;
	m_axis_tid_next = m_axis_tid_reg;
	m_axis_tdest_next = m_axis_tdest_reg;
	m_axis_tuser_next = m_axis_tuser_reg;

	if (m_axis_tvalid && m_axis_tready) begin
		m_axis_tvalid_next = 1'b0;
	end

	if (in_axis_tvalid_reg && in_axis_tready) begin
		in_axis_tvalid_next = 1'b0;
	end

	if(s_axis_tvalid && s_axis_tready) begin
		ipv4_hdr_next = s_axis_tdata[csum_start +: CSUM_DATA_WIDTH];
		csum_enable_next = csum_enable;

		in_axis_tdata_next = s_axis_tdata;
		in_axis_tkeep_next = s_axis_tkeep;
		in_axis_tvalid_next = 1'b1;
		in_axis_tlast_next = s_axis_tlast;
		in_axis_tid_next = s_axis_tid;
		in_axis_tdest_next = s_axis_tdest;
		in_axis_tuser_next = s_axis_tuser;
	end

	if(in_axis_tvalid_reg && in_axis_tready) begin
		m_axis_tdata_next = in_axis_tdata_reg;
		m_axis_tkeep_next = in_axis_tkeep_reg;
		m_axis_tvalid_next = 1'b1;
		m_axis_tlast_next = in_axis_tlast_reg;
		m_axis_tid_next = in_axis_tid_reg;
		m_axis_tdest_next = in_axis_tdest_reg;
		m_axis_tuser_next = in_axis_tuser_reg;
		if (csum_enable_reg) begin
			m_axis_tdata_next[csum_offset +: 16] = byte_rvs_2(csum);
		end
	end
end

always @(posedge clk) begin
	if (rst) begin
		ipv4_hdr_reg <= {CSUM_DATA_WIDTH{1'b0}};
		csum_enable_reg <= 1'b0;

		in_axis_tdata_reg	<= {S_DATA_WIDTH{1'b0}};
		in_axis_tkeep_reg	<= {S_KEEP_WIDTH{1'b0}};
		in_axis_tvalid_reg	<= 1'b0;
		in_axis_tlast_reg	<= 1'b0;
		in_axis_tid_reg		<= {S_ID_WIDTH{1'b0}};
		in_axis_tdest_reg	<= {S_DEST_WIDTH{1'b0}};
		in_axis_tuser_reg	<= {S_USER_WIDTH{1'b0}};

		m_axis_tdata_reg	<= {M_DATA_WIDTH{1'b0}};
		m_axis_tkeep_reg	<= {M_KEEP_WIDTH{1'b0}};
		m_axis_tvalid_reg	<= 1'b0;
		m_axis_tlast_reg	<= 1'b0;
		m_axis_tid_reg		<= {M_ID_WIDTH{1'b0}};
		m_axis_tdest_reg	<= {M_DEST_WIDTH{1'b0}};
		m_axis_tuser_reg	<= {M_USER_WIDTH{1'b0}};
	end else begin
		ipv4_hdr_reg 		<= ipv4_hdr_next;
		csum_enable_reg		<= csum_enable_next;

		in_axis_tdata_reg	<= in_axis_tdata_next;
		in_axis_tkeep_reg	<= in_axis_tkeep_next;
		in_axis_tvalid_reg	<= in_axis_tvalid_next;
		in_axis_tlast_reg	<= in_axis_tlast_next;
		in_axis_tid_reg		<= in_axis_tid_next;
		in_axis_tdest_reg	<= in_axis_tdest_next;
		in_axis_tuser_reg	<= in_axis_tuser_next;
		
		m_axis_tdata_reg	<= m_axis_tdata_next;
		m_axis_tkeep_reg	<= m_axis_tkeep_next;
		m_axis_tvalid_reg	<= m_axis_tvalid_next;
		m_axis_tlast_reg	<= m_axis_tlast_next;
		m_axis_tid_reg		<= m_axis_tid_next;
		m_axis_tdest_reg	<= m_axis_tdest_next;
		m_axis_tuser_reg	<= m_axis_tuser_next;
	end
end

endmodule

`resetall