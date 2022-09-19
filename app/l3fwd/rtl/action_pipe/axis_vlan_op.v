
/*
 * Created on Mon Feb 21 2022
 *
 * Copyright (c) 2022 IOA UCAS
 *
 * @Filename:	 axis_vlan_op.v
 * @Author:		 Jiawei Lin
 * @Last edit:	 11:00:43
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Modify VLAN of packet header.
 */
module axis_vlan_op #(
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

	parameter VLAN_OP_WIDTH = 2,
	parameter PT_WIDTH = 4,
	parameter PT_IPV4 = 4'h1,
	parameter PT_VLV4 = 4'h2,
	parameter PT_IPV6 = 4'h3,
	parameter PT_VLV6 = 4'h4
) (
	input  wire clk,
	input  wire rst,

	input  wire [VLAN_OP_WIDTH-1:0] 	vlan_op,
	input  wire [VLAN_WIDTH-1:0] 		vlan_data,
	input  wire [PT_WIDTH-1:0]			pkt_type,

	input  wire [S_DATA_WIDTH-1:0] 		s_axis_tdata,
	input  wire [S_KEEP_WIDTH-1:0] 		s_axis_tkeep,
	input  wire 						s_axis_tvalid,
	output wire 						s_axis_tready,
	input  wire 						s_axis_tlast,
	input  wire [S_ID_WIDTH-1:0] 		s_axis_tid,	
	input  wire [S_DEST_WIDTH-1:0] 		s_axis_tdest,	
	input  wire [S_USER_WIDTH-1:0] 		s_axis_tuser,

	output wire [M_DATA_WIDTH-1:0] 		m_axis_tdata,
	output wire [M_KEEP_WIDTH-1:0] 		m_axis_tkeep,
	output wire 						m_axis_tvalid,
	input  wire 						m_axis_tready,
	output wire 						m_axis_tlast,
	output wire [M_ID_WIDTH-1:0] 		m_axis_tid,
	output wire [M_DEST_WIDTH-1:0] 		m_axis_tdest,
	output wire [M_USER_WIDTH-1:0] 		m_axis_tuser
);

function [15:0] byte_rvs_2 (input [15:0] in_1);
	byte_rvs_2 = {in_1[7:0], in_1[15:8]};
endfunction

localparam 
	VLAN_INSERT = 2'b01,
	VLAN_MODIFY = 2'b11,
	VLAN_REMOVE = 2'b10;
localparam MAC_WIDTH = 48, MAC_OFFSET = 0;
localparam VTAG_WIDTH = 16, VTAG_TPID = byte_rvs_2(16'h8100);
localparam VLAN_WIDTH = 16, VLAN_OFFSET = 2*MAC_WIDTH+VLAN_WIDTH;
localparam ET_OFFSET_VL = VLAN_OFFSET+VLAN_WIDTH;
localparam ET_OFFSET = MAC_WIDTH*2;

reg  [M_DATA_WIDTH-1:0] 	m_axis_tdata_reg = {M_DATA_WIDTH{1'b0}}, m_axis_tdata_next;
reg  [M_KEEP_WIDTH-1:0] 	m_axis_tkeep_reg = {M_KEEP_WIDTH{1'b0}}, m_axis_tkeep_next;
reg  						m_axis_tvalid_reg = 1'b0, m_axis_tvalid_next;
reg  						m_axis_tlast_reg = 1'b0, m_axis_tlast_next;
reg  [M_ID_WIDTH-1:0] 		m_axis_tid_reg = {M_ID_WIDTH{1'b0}}, m_axis_tid_next;
reg  [M_DEST_WIDTH-1:0] 	m_axis_tdest_reg = {M_DEST_WIDTH{1'b0}}, m_axis_tdest_next;
reg  [M_USER_WIDTH-1:0]		m_axis_tuser_reg = {M_USER_WIDTH{1'b0}}, m_axis_tuser_next;

wire [M_KEEP_WIDTH-1:0]		s_axis_tkeep_pad = {
	{M_KEEP_WIDTH-S_KEEP_WIDTH{1'b0}},
	s_axis_tkeep
};

assign m_axis_tdata = m_axis_tdata_reg;
assign m_axis_tkeep = m_axis_tkeep_reg;
assign m_axis_tvalid = m_axis_tvalid_reg;
assign s_axis_tready = !m_axis_tvalid_reg || m_axis_tready;
assign m_axis_tlast = m_axis_tlast_reg;
assign m_axis_tid = m_axis_tid_reg;
assign m_axis_tdest = m_axis_tdest_reg;
assign m_axis_tuser = m_axis_tuser_reg;

/* 
	Packet Type:
		0x0: 		default
		0x1: 		ipv4
		0x2: 		vlan+ipv4
		0x3: 		ipv6
		0x4: 		vlan+ipv6
*/
always @(*) begin
	m_axis_tdata_next = m_axis_tdata_reg;
	m_axis_tkeep_next = m_axis_tkeep_reg;
	m_axis_tvalid_next = m_axis_tvalid_reg;
	m_axis_tdest_next = m_axis_tdest_reg;
	m_axis_tid_next = m_axis_tid_reg;
	m_axis_tlast_next = m_axis_tlast_reg;
	m_axis_tuser_next = m_axis_tuser_reg;

	if(m_axis_tvalid && m_axis_tready) begin
		m_axis_tvalid_next = 1'b0;
	end
	
	if(s_axis_tvalid && s_axis_tready) begin
		m_axis_tdata_next = s_axis_tdata;
		m_axis_tkeep_next = s_axis_tkeep;
		m_axis_tvalid_next = 1'b1;
		m_axis_tlast_next = s_axis_tlast;
		m_axis_tid_next = s_axis_tid;
		m_axis_tdest_next = s_axis_tdest;
		m_axis_tuser_next = s_axis_tuser;

		case (vlan_op)
			VLAN_INSERT: begin
				if (pkt_type == PT_IPV4 || pkt_type == PT_IPV6) begin
					m_axis_tdata_next = {
						{M_DATA_WIDTH-S_DATA_WIDTH{1'b0}},
						s_axis_tdata[S_DATA_WIDTH-1 : ET_OFFSET],
						byte_rvs_2(vlan_data),
						VTAG_TPID,
						s_axis_tdata[MAC_OFFSET +: 2*MAC_WIDTH]
					};
					m_axis_tkeep_next = {s_axis_tkeep_pad, 4'b1111};
				end 
			end
			VLAN_MODIFY: begin	// TODO: UT
				if (pkt_type == PT_VLV4 || pkt_type == PT_VLV6) begin
					m_axis_tdata_next = {
						{M_DATA_WIDTH-S_DATA_WIDTH{1'b0}},
						s_axis_tdata[S_DATA_WIDTH-1 : ET_OFFSET_VL],
						byte_rvs_2(vlan_data),
						VTAG_TPID,
						s_axis_tdata[MAC_OFFSET +: 2*MAC_WIDTH]
					};
					m_axis_tkeep_next = s_axis_tkeep_pad;
				end
			end
			VLAN_REMOVE: begin	// TODO: UT
				if (pkt_type == PT_VLV4 || pkt_type == PT_VLV6) begin
					m_axis_tdata_next = {
						{M_DATA_WIDTH-S_DATA_WIDTH{1'b0}},
						s_axis_tdata[S_DATA_WIDTH-1 : ET_OFFSET_VL],
						s_axis_tdata[MAC_OFFSET +: 2*MAC_WIDTH]
					};
					m_axis_tkeep_next = s_axis_tkeep_pad >> 4;
				end
			end
			default: begin	// 2'b00
			end
		endcase
	end
end

always @(posedge clk) begin
	if (rst) begin
		m_axis_tdata_reg = {M_DATA_WIDTH{1'b0}};
		m_axis_tkeep_reg = {M_KEEP_WIDTH{1'b0}};
		m_axis_tvalid_reg = 1'b0;
		m_axis_tlast_reg = 1'b0;
		m_axis_tid_reg = {M_ID_WIDTH{1'b0}};
		m_axis_tdest_reg = {M_DEST_WIDTH{1'b0}};
		m_axis_tuser_reg = {M_USER_WIDTH{1'b0}};
	end else begin
		m_axis_tdata_reg <= m_axis_tdata_next;
		m_axis_tkeep_reg <= m_axis_tkeep_next;
		m_axis_tvalid_reg <= m_axis_tvalid_next;
		m_axis_tlast_reg <= m_axis_tlast_next;
		m_axis_tid_reg <= m_axis_tid_next;
		m_axis_tdest_reg <= m_axis_tdest_next;
		m_axis_tuser_reg <= m_axis_tuser_next;
	end
end

endmodule

`resetall

/*

TCP/UDP Frame (IPv4)

			Field						Length
[47:0]		Destination MAC address	 	6 octets
[95:48]		Source MAC address			6 octets
[]			VLAN Tag					4 octets
[111:96]	Ethertype (0x0800)			2 octets
[115:112]	Version (4)					4 bits
[119:116]	IHL (5-15)					4 bits
[125:120]	DSCP (0)					6 bits
[127:126]	ECN (0)						2 bits
[143:128]	length						2 octets
[159:144]	identification (0?)			2 octets
[162:160]	flags (010)					3 bits
[175:163]	fragment offset (0)			13 bits
[183:176]	time to live (64?)			1 octet
[191:184]	protocol (6 or 17)			1 octet
[207:192]	header checksum				2 octets
[239:208]	source IP					4 octets
[271:240]	destination IP				4 octets
			options						(IHL-5)*4 octets
	
			source port					2 octets
			desination port				2 octets
			other fields + payload

TCP/UDP Frame (IPv6)

			Field						Length
[47:0]		Destination MAC address		6 octets
[95:48]		Source MAC address			6 octets
[111:96]	Ethertype (0x86dd)			2 octets
[115:112]	Version (4)					4 bits
[123:116]	Traffic class				8 bits
[143:124]	Flow label					20 bits
[159:144]	length						2 octets
[167:160]	next header (6 or 17)		1 octet
[175:168]	hop limit					1 octet
[303:176]	source IP					16 octets
[431:304]	destination IP				16 octets

[447:432]	source port					2 octets
[463:448]	desination port				2 octets
			other fields + payload

VLAN Tag in 802.1Q:

[31:16]		Tag Protocol Identifier		2 octets	0x8100
[15:13]		Priority					3 bits 		0~7
[12]		Cannonical Format Indicator	1 bits		0 for Ethernet
[11:0]		VLAN Identifier				12 bits		1~4094

*/