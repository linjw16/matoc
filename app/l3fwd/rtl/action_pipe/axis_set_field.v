/*
 * Created on Sat Feb 19 2022
 *
 * Copyright (c) 2022 IOA UCAS
 *
 * @Filename:	 axis_set_field.v
 * @Author:		 Jiawei Lin
 * @Last edit:	 14:34:27
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module axis_set_field #(
	parameter S_DATA_WIDTH = 600,
	parameter S_KEEP_WIDTH = S_DATA_WIDTH/8,
	parameter S_ID_WIDTH = 8,
	parameter S_DEST_WIDTH = 4,
	parameter S_USER_WIDTH = 6,
	parameter M_DATA_WIDTH = S_DATA_WIDTH,
	parameter M_KEEP_WIDTH =  M_DATA_WIDTH/8,
	parameter M_ID_WIDTH = S_ID_WIDTH,
	parameter M_DEST_WIDTH = S_DEST_WIDTH,
	parameter M_USER_WIDTH = S_USER_WIDTH,

	parameter SET_DATA_WIDTH = 8,
	parameter SET_ADDR_OFFSET = 0
)(
	input  wire clk,
	input  wire rst,
	
	input  wire [SET_DATA_WIDTH-1:0]	set_data,
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

initial begin
	if (SET_ADDR_OFFSET+SET_DATA_WIDTH > M_DATA_WIDTH) begin
		$error("no, %m");
		$finish;
	end
end

reg  [M_DATA_WIDTH-1:0] 	s_axis_tdata_temp = {M_DATA_WIDTH{1'b0}};
reg  [M_DATA_WIDTH-1:0] 	m_axis_tdata_reg = {M_DATA_WIDTH{1'b0}}, m_axis_tdata_next;
reg  [M_KEEP_WIDTH-1:0] 	m_axis_tkeep_reg = {M_KEEP_WIDTH{1'b0}}, m_axis_tkeep_next;
reg  						m_axis_tvalid_reg = 1'b0, m_axis_tvalid_next;
reg  						m_axis_tlast_reg = 1'b0, m_axis_tlast_next;
reg  [M_ID_WIDTH-1:0] 		m_axis_tid_reg = {M_ID_WIDTH{1'b0}}, m_axis_tid_next;
reg  [M_DEST_WIDTH-1:0] 	m_axis_tdest_reg = {M_DEST_WIDTH{1'b0}}, m_axis_tdest_next;
reg  [M_USER_WIDTH-1:0] 	m_axis_tuser_reg = {M_USER_WIDTH{1'b0}}, m_axis_tuser_next;

assign m_axis_tdata = m_axis_tdata_reg;
assign m_axis_tkeep = m_axis_tkeep_reg;
assign m_axis_tvalid = m_axis_tvalid_reg;
assign s_axis_tready = !m_axis_tvalid_reg || m_axis_tready;
assign m_axis_tuser = m_axis_tuser_reg;
assign m_axis_tlast = m_axis_tlast_reg;
assign m_axis_tdest = m_axis_tdest_reg;
assign m_axis_tid = m_axis_tid_reg;

always @(*) begin
	m_axis_tdata_next = m_axis_tdata_reg;
	m_axis_tkeep_next = m_axis_tkeep_reg;
	m_axis_tvalid_next = m_axis_tvalid_reg;
	m_axis_tuser_next = m_axis_tuser_reg;
	m_axis_tlast_next = m_axis_tlast_reg;
	m_axis_tdest_next = m_axis_tdest_reg;
	m_axis_tid_next = m_axis_tid_reg;

	if(m_axis_tvalid && m_axis_tready) begin
		m_axis_tvalid_next = 1'b0;
	end
	
	if (SET_ADDR_OFFSET == 0) begin
		s_axis_tdata_temp = {
			{M_DATA_WIDTH-S_DATA_WIDTH{1'b0}},
			s_axis_tdata[S_DATA_WIDTH-1:SET_ADDR_OFFSET+SET_DATA_WIDTH],
			set_data
		};
	end else if (SET_ADDR_OFFSET+SET_DATA_WIDTH == S_DATA_WIDTH) begin
		s_axis_tdata_temp = {
			{M_DATA_WIDTH-S_DATA_WIDTH{1'b0}},
			set_data,
			s_axis_tdata[SET_ADDR_OFFSET-1:0]
		};
	end else begin
		s_axis_tdata_temp = {
			{M_DATA_WIDTH-S_DATA_WIDTH{1'b0}},
			s_axis_tdata[S_DATA_WIDTH-1:SET_ADDR_OFFSET+SET_DATA_WIDTH],
			set_data,
			s_axis_tdata[SET_ADDR_OFFSET-1:0]
		};
	end
	
	if(s_axis_tvalid && s_axis_tready) begin
		m_axis_tdata_next = s_axis_tdata_temp;
		m_axis_tkeep_next = s_axis_tkeep+M_KEEP_WIDTH-S_KEEP_WIDTH;
		m_axis_tvalid_next = 1'b1;
		m_axis_tuser_next = s_axis_tuser;
		m_axis_tlast_next = s_axis_tlast;
		m_axis_tdest_next = s_axis_tdest;
		m_axis_tid_next = s_axis_tid;
	end
end

always @(posedge clk) begin
	if (rst) begin
		m_axis_tdata_reg = {M_DATA_WIDTH{1'b0}};
		m_axis_tkeep_reg = {M_KEEP_WIDTH{1'b0}};
		m_axis_tvalid_reg = 1'b0;
		m_axis_tuser_reg = {M_USER_WIDTH{1'b0}};
		m_axis_tlast_reg = 1'b0;
		m_axis_tdest_reg = {M_DEST_WIDTH{1'b0}};
		m_axis_tid_reg = {M_ID_WIDTH{1'b0}};
	end else begin
		m_axis_tdata_reg <= m_axis_tdata_next;
		m_axis_tkeep_reg <= m_axis_tkeep_next;
		m_axis_tvalid_reg <= m_axis_tvalid_next;
		m_axis_tuser_reg <= m_axis_tuser_next;
		m_axis_tlast_reg <= m_axis_tlast_next;
		m_axis_tdest_reg <= m_axis_tdest_next;
		m_axis_tid_reg <= m_axis_tid_next;
	end
end

endmodule

`resetall