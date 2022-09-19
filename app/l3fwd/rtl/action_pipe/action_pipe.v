/*
 * Created on Sat Feb 19 2022
 *
 * Copyright (c) 2022 IOA UCAS
 *
 * @Filename:	 action_pipe.v
 * @Author:		 Jiawei Lin
 * @Last edit:	 11:23:40
 */
/*
	Action Code: size: 16B
		[127:80]	Destination MAC		6 octets
		[79:32]		Source MAC			6 octets
		[31:16]		VLAN Data			2 octets
		[15:8]		channel				1 octets
		[7:0]		Op. code			1 octets
	Operation code: size 1 byte
		[7]			set DMAC			1 bit
		[6]			set DMAC			1 bit
		[5:4]		VLAN OP				2 bit
					2'b01				insert
					2'b10				remove
					2'b11				modify
		[3]			set tdest			1 bit
		[2]			set tid				1 bit
		[1]			Calculate Checksum 	1 bit
		[0]			Reserved			2 bit
*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

module action_pipe #(
	parameter S_DATA_WIDTH = 600,
	parameter S_KEEP_WIDTH = S_DATA_WIDTH/8,
	parameter S_ID_WIDTH = 8,
	parameter S_DEST_WIDTH = 8,
	parameter S_USER_WIDTH = 132,
	parameter M_DATA_WIDTH = S_DATA_WIDTH,
	parameter M_KEEP_WIDTH =  M_DATA_WIDTH/8,
	parameter M_ID_WIDTH = S_ID_WIDTH,
	parameter M_DEST_WIDTH = S_DEST_WIDTH,
	parameter M_USER_WIDTH = S_USER_WIDTH,
	parameter PT_OFFSET = 0,
    parameter ACTN_OFFSET = S_USER_WIDTH-128,
	parameter ENABLE = 1
) (
	input  wire clk,
	input  wire rst,

	input  wire [S_DATA_WIDTH-1:0] 	s_axis_tdata,
	input  wire [S_KEEP_WIDTH-1:0] 	s_axis_tkeep,
	input  wire 					s_axis_tvalid,
	output wire 					s_axis_tready,
	input  wire 					s_axis_tlast,
	input  wire [S_ID_WIDTH-1:0] 	s_axis_tid,	
	input  wire [S_DEST_WIDTH-1:0] 	s_axis_tdest,	
	input  wire [S_USER_WIDTH-1:0] 	s_axis_tuser,

	output wire [M_DATA_WIDTH-1:0] 	m_axis_tdata,
	output wire [M_KEEP_WIDTH-1:0] 	m_axis_tkeep,
	output wire 					m_axis_tvalid,
	input  wire 					m_axis_tready,
	output wire 					m_axis_tlast,
	output wire [M_ID_WIDTH-1:0] 	m_axis_tid,
	output wire [M_DEST_WIDTH-1:0] 	m_axis_tdest,
	output wire [M_USER_WIDTH-1:0] 	m_axis_tuser
);

wire [7:0] dbg_opcode = s_axis_tuser[ACTN_OFFSET+:8];

localparam LEVELS = 4;
localparam VD_OFFSET = 34;

localparam PT_WIDTH = 4;
localparam ACTN_DATA_WIDTH = 128;
localparam 
	PT_IPV4 = 4'h1,
	PT_VLV4 = 4'h2,
	PT_IPV6 = 4'h3,
	PT_VLV6 = 4'h4;

initial begin
	if (S_USER_WIDTH < ACTN_DATA_WIDTH+PT_WIDTH) begin
		$error("ACTN_DATA_WIDTH should be 128! %m");
		$error("Error: Self-defined type width should be 4 (instance %m)");
		$finish;
	end
	if (M_DATA_WIDTH < S_DATA_WIDTH+32) begin
		$error("Error: Output width should expand at least 4 bytes for vlan insert (instance %m)");
		$finish;
	end
end

function [15:0] byte_rvs_2 (input [15:0] in_1);
	byte_rvs_2 = {in_1[7:0], in_1[15:8]};
endfunction

function [31:0] byte_rvs_4(input [31:0] in_1);
	byte_rvs_4 = {byte_rvs_2(in_1[15:0]), byte_rvs_2(in_1[31:16])};
endfunction

function [47:0] byte_rvs_6(input [47:0] in_1);
	byte_rvs_6 = {byte_rvs_4(in_1[31:0]), byte_rvs_2(in_1[47:32])};
endfunction

// `define BYPASS_AP
`ifdef BYPASS_AP
`ifdef PHONY
assign m_axis_tdata = {
	48'hDAD1D2D3D4D5,	/* Destination MAC address */
	48'h5A5152535455,	/* Source MAC address */
	32'h8100_FFFF,		/* VLAN */
	16'h0800,			/* EtherType(0x0800) */
	16'h4500,			/* Version (4), IHL (5-15), DSCP (0), ECN (0) */
	16'h0034,			/* L3 packet length */
	16'hABCD,			/* identification (0?) */
	16'h4000,			/* flags (010), fragment offset (0) */
	16'h4011,			/* time to live (64), protocol (6 or 17) */
	16'h0000,			/* header checksum */
	32'hC0A8010A,		/* source IP */
	32'hC0A8010F,		/* destination IP */
	16'h0001,			/* source port */
	16'h0002,			/* desination port */
	16'h0008,			/* length */
	16'h0000,			/* checksum */
	{3{64'h123456789ABCDEF}},{2{8'hFF}}		/* payload */
};
assign m_axis_tkeep = {
	{M_KEEP_WIDTH-68{1'b0}},
	{68{1'h1}}
};
`endif
assign m_axis_tdata = {{M_DATA_WIDTH-S_DATA_WIDTH{1'b0}}, s_axis_tdata};
assign m_axis_tkeep = {{M_KEEP_WIDTH-S_KEEP_WIDTH{1'b0}}, s_axis_tkeep};
assign m_axis_tvalid = s_axis_tvalid;
assign s_axis_tready = m_axis_tready;
assign m_axis_tlast = s_axis_tlast;
assign m_axis_tid = s_axis_tid;
assign m_axis_tdest = s_axis_tdest;
assign m_axis_tuser = s_axis_tuser;

`else

/*
 * Pipeline registers assignment. 
 */
localparam TTL_WIDTH = 8;
localparam 
	TTL_OFFSET_IPV4 = (14+2+2+2+2)*8,
	TTL_OFFSET_VLV4 = (18+2+2+2+2)*8,
	TTL_OFFSET_IPV6 = (14+4+2+1)*8,		// TODO: not sure
	TTL_OFFSET_VLV6 = (18+4+2+1)*8;

wire [S_DATA_WIDTH-1:0] 	axis_hdr_tdata[LEVELS-1:0];
wire [S_KEEP_WIDTH-1:0] 	axis_hdr_tkeep[LEVELS-1:0];
wire [LEVELS-1:0] 			axis_hdr_tvalid;
wire [LEVELS-1:0] 			axis_hdr_tready;
wire [LEVELS-1:0] 			axis_hdr_tlast;
wire [S_ID_WIDTH-1:0] 		axis_hdr_tid[LEVELS-1:0];
wire [S_DEST_WIDTH-1:0] 	axis_hdr_tdest[LEVELS-1:0];
wire [S_USER_WIDTH-1:0] 	axis_hdr_tuser[LEVELS-1:0];

wire [TTL_WIDTH-1:0] dbg_ttl_ipv4_in = s_axis_tdata[TTL_OFFSET_IPV4 +: TTL_WIDTH];
wire [TTL_WIDTH-1:0] dbg_ttl_ipv4_dec = axis_hdr_tdata[0][TTL_OFFSET_IPV4 +: TTL_WIDTH];
/*
 * 1. Decrease the TTL of packet header 
 */

axis_ttl_dec #(
	.DATA_WIDTH			(S_DATA_WIDTH),
	.KEEP_WIDTH			(S_KEEP_WIDTH),
	.ID_WIDTH			(S_ID_WIDTH),
	.DEST_WIDTH			(S_DEST_WIDTH),
	.USER_WIDTH			(S_USER_WIDTH),

	.PT_IPV4			(PT_IPV4),
	.PT_VLV4			(PT_VLV4),
	.PT_IPV6			(PT_IPV6),
	.PT_VLV6			(PT_VLV6),
	.PT_OFFSET			(PT_OFFSET),
	.PT_WIDTH			(PT_WIDTH),
	.ENABLE				(ENABLE)
) ttl_dec_1 (
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

	.m_axis_tdata		(axis_hdr_tdata[0]),
	.m_axis_tkeep		(axis_hdr_tkeep[0]),
	.m_axis_tvalid		(axis_hdr_tvalid[0]),
	.m_axis_tready		(axis_hdr_tready[0]),
	.m_axis_tlast		(axis_hdr_tlast[0]),
	.m_axis_tid			(axis_hdr_tid[0]),
	.m_axis_tdest		(axis_hdr_tdest[0]),
	.m_axis_tuser		(axis_hdr_tuser[0])
);

/*
 * 2. Set the MAC of packet header 
 */
localparam MAC_WIDTH = 48;
localparam DMAC_OFFSET = 0;
localparam SMAC_OFFSET = DMAC_OFFSET+MAC_WIDTH;
localparam ACTN_DMAC_OFFSET = ACTN_OFFSET+ACTN_DATA_WIDTH-MAC_WIDTH;
localparam ACTN_SMAC_OFFSET = ACTN_OFFSET+ACTN_DATA_WIDTH-2*MAC_WIDTH;
localparam OP_DMAC_OFFSET = 7+ACTN_OFFSET;
localparam OP_SMAC_OFFSET = 6+ACTN_OFFSET;

wire [MAC_WIDTH-1:0] dmac_init = axis_hdr_tdata[0][DMAC_OFFSET +: MAC_WIDTH];
wire [MAC_WIDTH-1:0] smac_init = axis_hdr_tdata[0][SMAC_OFFSET +: MAC_WIDTH];
wire [MAC_WIDTH-1:0] dmac_act = axis_hdr_tuser[0][ACTN_DMAC_OFFSET +: MAC_WIDTH];
wire [MAC_WIDTH-1:0] smac_act = axis_hdr_tuser[0][ACTN_SMAC_OFFSET +: MAC_WIDTH];
wire [MAC_WIDTH-1:0] dmac_rvs = byte_rvs_6(dmac_act);
wire [MAC_WIDTH-1:0] smac_rvs = byte_rvs_6(smac_act);
wire op_dmac = axis_hdr_tuser[0][OP_DMAC_OFFSET];
wire op_smac = axis_hdr_tuser[0][OP_SMAC_OFFSET];
wire [MAC_WIDTH-1:0] dmac = op_dmac ? dmac_rvs : dmac_init;
wire [MAC_WIDTH-1:0] smac = op_smac ? smac_rvs : smac_init;

axis_set_field #(
	.S_DATA_WIDTH			(S_DATA_WIDTH),
	.S_KEEP_WIDTH			(S_KEEP_WIDTH),
	.S_ID_WIDTH				(S_ID_WIDTH),
	.S_DEST_WIDTH			(S_DEST_WIDTH),
	.S_USER_WIDTH			(S_USER_WIDTH),

	.SET_DATA_WIDTH			(2*MAC_WIDTH),
	.SET_ADDR_OFFSET		(DMAC_OFFSET)
) set_mac (
	.clk(clk),
	.rst(rst),

	.set_data				({smac, dmac}),
	
	.s_axis_tdata			(axis_hdr_tdata[0]),
	.s_axis_tkeep			(axis_hdr_tkeep[0]),
	.s_axis_tvalid			(axis_hdr_tvalid[0]),
	.s_axis_tready			(axis_hdr_tready[0]),
	.s_axis_tlast			(axis_hdr_tlast[0]),
	.s_axis_tid				(axis_hdr_tid[0]),
	.s_axis_tdest			(axis_hdr_tdest[0]),
	.s_axis_tuser			(axis_hdr_tuser[0]),

	.m_axis_tdata			(axis_hdr_tdata[1]),
	.m_axis_tkeep			(axis_hdr_tkeep[1]),
	.m_axis_tvalid			(axis_hdr_tvalid[1]),
	.m_axis_tready			(axis_hdr_tready[1]),
	.m_axis_tlast			(axis_hdr_tlast[1]),
	.m_axis_tid				(axis_hdr_tid[1]),
	.m_axis_tdest			(axis_hdr_tdest[1]),
	.m_axis_tuser			(axis_hdr_tuser[1])
);

/*
 * 3. Calculate header's checksum
 * CSUM_START_IPV4 = S_DATA_WIDTH-272,
 * CSUM_START_VLV4 = S_DATA_WIDTH-304,
 * CSUM_OFFSET_IPV4 = CSUM_START_IPV4 + IPv4_WIDTH*2,
 * CSUM_OFFSET_VLV4 = CSUM_START_VLV4 + IPv4_WIDTH*2;
 */
localparam OP_CSUM_OFFSET = ACTN_OFFSET+1;
localparam IPv4_WIDTH = 32;	// TODO: err in avst ver.
localparam 
	CSUM_START_IPV4 = (14)*8,
	CSUM_START_VLV4 = (18)*8,
	CSUM_OFFSET_IPV4 = CSUM_START_IPV4 + 10*8,
	CSUM_OFFSET_VLV4 = CSUM_START_VLV4 + 10*8;
localparam CSUM_DATA_WIDTH = 160;
localparam CL_DATA_WIDTH = $clog2(S_DATA_WIDTH);

wire csum_en = axis_hdr_tuser[1][OP_CSUM_OFFSET];
wire [PT_WIDTH-1:0] hdr_pkt_type_1 = axis_hdr_tuser[1][PT_OFFSET +: PT_WIDTH];
wire csum_enable = csum_en && ((hdr_pkt_type_1 == PT_IPV4) || (hdr_pkt_type_1 == PT_VLV4));	// TODO: control by op code
wire [CL_DATA_WIDTH-1:0] csum_start, csum_offset;

assign csum_start = (hdr_pkt_type_1 == PT_IPV4) ? CSUM_START_IPV4 : CSUM_START_VLV4;
assign csum_offset = (hdr_pkt_type_1 == PT_IPV4) ? CSUM_OFFSET_IPV4 : CSUM_OFFSET_VLV4;

axis_hdr_csum  #(
	.S_DATA_WIDTH				(S_DATA_WIDTH),
	.S_KEEP_WIDTH				(S_KEEP_WIDTH),
	.S_ID_WIDTH					(S_ID_WIDTH),
	.S_DEST_WIDTH				(S_DEST_WIDTH),
	.S_USER_WIDTH				(S_USER_WIDTH),
	.M_DATA_WIDTH				(S_DATA_WIDTH),
	.M_KEEP_WIDTH				(S_KEEP_WIDTH),
	.M_DEST_WIDTH				(S_DEST_WIDTH),
	.M_USER_WIDTH				(S_USER_WIDTH),
	.M_ID_WIDTH					(S_ID_WIDTH),
	.CSUM_DATA_WIDTH			(CSUM_DATA_WIDTH),
	.ENABLE						(ENABLE)
) hdr_csum_inst (
	.clk(clk),
	.rst(rst),
	
	.csum_enable				(csum_enable),
	.csum_start					(csum_start),
	.csum_offset				(csum_offset),
			
	.s_axis_tdata				(axis_hdr_tdata[1]),
	.s_axis_tkeep				(axis_hdr_tkeep[1]),
	.s_axis_tvalid				(axis_hdr_tvalid[1]),
	.s_axis_tready				(axis_hdr_tready[1]),
	.s_axis_tlast				(axis_hdr_tlast[1]),
	.s_axis_tid					(axis_hdr_tid[1]),
	.s_axis_tdest				(axis_hdr_tdest[1]),
	.s_axis_tuser				(axis_hdr_tuser[1]),
			
	.m_axis_tdata				(axis_hdr_tdata[2]),
	.m_axis_tkeep				(axis_hdr_tkeep[2]),
	.m_axis_tvalid				(axis_hdr_tvalid[2]),
	.m_axis_tready				(axis_hdr_tready[2]),
	.m_axis_tlast				(axis_hdr_tlast[2]),
	.m_axis_tid					(axis_hdr_tid[2]),
	.m_axis_tdest				(axis_hdr_tdest[2]),
	.m_axis_tuser				(axis_hdr_tuser[2])
);

/*
 * 4. VLAN modification.
 */
localparam OP_VLAN_WIDTH = 2;
localparam OP_VLAN_OFFSET = ACTN_OFFSET+4;
localparam ACTN_VLAN_WIDTH = 16;
localparam ACTN_VLAN_OFFSET = ACTN_OFFSET+16;

wire [PT_WIDTH-1:0] hdr_pkt_type_2 = axis_hdr_tuser[2][PT_OFFSET +: PT_WIDTH];
wire [OP_VLAN_WIDTH-1:0] vlan_op;
wire [ACTN_VLAN_WIDTH-1:0] vlan_data;

assign vlan_op = axis_hdr_tuser[2][OP_VLAN_OFFSET +: OP_VLAN_WIDTH];
assign vlan_data = axis_hdr_tuser[2][ACTN_VLAN_OFFSET +: ACTN_VLAN_WIDTH];

axis_vlan_op #(
	.S_DATA_WIDTH			(S_DATA_WIDTH),
	.S_KEEP_WIDTH			(S_KEEP_WIDTH),
	.S_ID_WIDTH				(S_ID_WIDTH),
	.S_DEST_WIDTH			(S_DEST_WIDTH),
	.S_USER_WIDTH			(S_USER_WIDTH),
	.M_DATA_WIDTH			(M_DATA_WIDTH),
	.M_KEEP_WIDTH			(M_KEEP_WIDTH),
	.M_ID_WIDTH				(M_ID_WIDTH),
	.M_DEST_WIDTH			(M_DEST_WIDTH),
	.M_USER_WIDTH			(S_USER_WIDTH),

	.VLAN_OP_WIDTH			(OP_VLAN_WIDTH),
	.PT_IPV4				(PT_IPV4),
	.PT_VLV4				(PT_VLV4),
	.PT_IPV6				(PT_IPV6),
	.PT_VLV6				(PT_VLV6)
) vlan_op_inst (
	.clk(clk),
	.rst(rst),
	
	.pkt_type				(hdr_pkt_type_2),
	.vlan_op				(vlan_op),
	.vlan_data				(vlan_data),

	.s_axis_tdata			(axis_hdr_tdata[2]),
	.s_axis_tkeep			(axis_hdr_tkeep[2]),
	.s_axis_tvalid			(axis_hdr_tvalid[2]),
	.s_axis_tready			(axis_hdr_tready[2]),
	.s_axis_tlast			(axis_hdr_tlast[2]),
	.s_axis_tid				(axis_hdr_tid[2]),
	.s_axis_tdest			(axis_hdr_tdest[2]),
	.s_axis_tuser			(axis_hdr_tuser[2]),

	.m_axis_tdata			(m_axis_tdata_int),
	.m_axis_tkeep			(m_axis_tkeep_int),
	.m_axis_tvalid			(m_axis_tvalid_int),
	.m_axis_tready			(m_axis_tready_int_reg),
	.m_axis_tlast			(m_axis_tlast_int),
	.m_axis_tid				(m_axis_ini_tid),
	.m_axis_tdest			(m_axis_ini_tdest),
	.m_axis_tuser			(m_axis_ini_tuser)
);

/*
 * 5. Set channel
*/
localparam OP_DEST_OFFSET = ACTN_OFFSET+3, OP_ID_OFFSET = ACTN_OFFSET+2;
localparam ACTN_FWD_OFFSET = ACTN_OFFSET+8, ACTN_FWD_WIDTH = 8;

wire [ACTN_FWD_WIDTH-1:0] channel, set_tid, set_tdest;
wire op_tdest, op_tid;
wire [S_USER_WIDTH-1:0]	m_axis_ini_tuser;

assign op_tid = m_axis_ini_tuser[OP_ID_OFFSET];
assign op_tdest = m_axis_ini_tuser[OP_DEST_OFFSET];
assign channel = m_axis_ini_tuser[ACTN_FWD_OFFSET +: ACTN_FWD_WIDTH];
// assign set_tid = op_tid ? channel : m_axis_ini_tid[M_ID_WIDTH-1-:ACTN_FWD_WIDTH];
assign set_tdest = op_tdest ? channel : m_axis_ini_tdest[M_DEST_WIDTH-1-:ACTN_FWD_WIDTH];
assign m_axis_tuser_int = m_axis_ini_tuser[M_USER_WIDTH-1:0];
assign m_axis_tid_int = m_axis_ini_tid;

set_field_async #(
	.DATA_WIDTH			(M_DEST_WIDTH),
	.SET_DATA_WIDTH		(ACTN_FWD_WIDTH),
	.SET_ADDR_OFFSET	(M_DEST_WIDTH-ACTN_FWD_WIDTH)
) set_tdest_1 (
	.set_data			(set_tdest),
	.data_in			(m_axis_ini_tdest),
	.data_out			(m_axis_tdest_int)
);
/*
set_field_async #(
	.DATA_WIDTH			(M_ID_WIDTH),
	.SET_DATA_WIDTH		(ACTN_FWD_WIDTH),
	.SET_ADDR_OFFSET	(M_ID_WIDTH-ACTN_FWD_WIDTH)
) set_tid_1 (
	.set_data			(set_tid),
	.data_in			(m_axis_ini_tid),
	.data_out			(m_axis_tid_int)
);*/

/*
 * 6. Datapath control
 */
reg store_axis_int_to_output;
reg store_axis_int_to_temp;
reg store_axis_temp_to_output;
reg m_axis_tvalid_reg = 1'b0, m_axis_tvalid_next;
reg temp_m_axis_tvalid_reg = 1'b0, temp_m_axis_tvalid_next;
reg m_axis_tready_int_reg = 1'b0;

wire [M_DATA_WIDTH-1:0]	m_axis_tdata_int;
wire [M_KEEP_WIDTH-1:0]	m_axis_tkeep_int;
wire					m_axis_tvalid_int;
wire					m_axis_tlast_int;
wire [M_ID_WIDTH-1:0] 	m_axis_tid_int, m_axis_ini_tid;
wire [M_DEST_WIDTH-1:0]	m_axis_tdest_int, m_axis_ini_tdest;
wire [M_USER_WIDTH-1:0]	m_axis_tuser_int;

reg  [M_DATA_WIDTH-1:0]	m_axis_tdata_reg = {M_DATA_WIDTH{1'b0}},	temp_m_axis_tdata_reg = {M_DATA_WIDTH{1'b0}};
reg  [M_KEEP_WIDTH-1:0]	m_axis_tkeep_reg = {M_KEEP_WIDTH{1'b0}},	temp_m_axis_tkeep_reg = {M_KEEP_WIDTH{1'b0}};
reg 					m_axis_tlast_reg = 1'b0,					temp_m_axis_tlast_reg = 1'b0;
reg  [M_ID_WIDTH-1:0] 	m_axis_tid_reg = {M_ID_WIDTH{1'b0}}, 		temp_m_axis_tid_reg = {M_ID_WIDTH{1'b0}};
reg  [M_DEST_WIDTH-1:0]	m_axis_tdest_reg = {M_DEST_WIDTH{1'b0}},	temp_m_axis_tdest_reg = {M_DEST_WIDTH{1'b0}};
reg  [M_USER_WIDTH-1:0]	m_axis_tuser_reg = {M_USER_WIDTH{1'b0}},	temp_m_axis_tuser_reg = {M_USER_WIDTH{1'b0}};

assign m_axis_tdata		= m_axis_tdata_reg;
assign m_axis_tkeep		= m_axis_tkeep_reg;
assign m_axis_tvalid	= m_axis_tvalid_reg;
assign m_axis_tlast		= m_axis_tlast_reg;
assign m_axis_tid		= m_axis_tid_reg;
assign m_axis_tdest		= m_axis_tdest_reg;
assign m_axis_tuser		= m_axis_tuser_reg;

/* enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input) */
wire m_axis_tready_int_early = m_axis_tready || (!temp_m_axis_tvalid_reg && (!m_axis_tvalid_reg || !m_axis_tvalid_int));

always @* begin	
	m_axis_tvalid_next = m_axis_tvalid_reg;
	temp_m_axis_tvalid_next = temp_m_axis_tvalid_reg;

	store_axis_int_to_output = 1'b0;
	store_axis_int_to_temp = 1'b0;
	store_axis_temp_to_output = 1'b0;

	if (m_axis_tready_int_reg) begin
		if (m_axis_tready || !m_axis_tvalid_reg) begin
			m_axis_tvalid_next = m_axis_tvalid_int;
			store_axis_int_to_output = 1'b1;
		end else begin
			temp_m_axis_tvalid_next = m_axis_tvalid_int;
			store_axis_int_to_temp = 1'b1;
		end
	end else if (m_axis_tready) begin
		m_axis_tvalid_next = temp_m_axis_tvalid_reg;
		temp_m_axis_tvalid_next = 1'b0;
		store_axis_temp_to_output = 1'b1;
	end
end

always @(posedge clk) begin
	if (rst) begin
		m_axis_tvalid_reg <= 1'b0;
		m_axis_tready_int_reg <= 1'b0;
		temp_m_axis_tvalid_reg <= 1'b0;

		m_axis_tdata_reg <= {M_DATA_WIDTH{1'b0}};
		m_axis_tkeep_reg <= {M_KEEP_WIDTH{1'b0}};
		m_axis_tlast_reg <= 1'b0;
		m_axis_tdest_reg <= {M_DEST_WIDTH{1'b0}};
		m_axis_tid_reg <= {M_ID_WIDTH{1'b0}};
		m_axis_tuser_reg <= {M_USER_WIDTH{1'b0}};
		temp_m_axis_tdata_reg <= {M_DATA_WIDTH{1'b0}};
		temp_m_axis_tkeep_reg <= {M_KEEP_WIDTH{1'b0}};
		temp_m_axis_tlast_reg <= 1'b0;
		temp_m_axis_tdest_reg <= {M_DEST_WIDTH{1'b0}};
		temp_m_axis_tid_reg <= {M_ID_WIDTH{1'b0}};
		temp_m_axis_tuser_reg <= {M_USER_WIDTH{1'b0}};
	end else begin
		m_axis_tvalid_reg <= m_axis_tvalid_next;
		m_axis_tready_int_reg <= m_axis_tready_int_early;
		temp_m_axis_tvalid_reg <= temp_m_axis_tvalid_next;
	end

	if (store_axis_int_to_output) begin
		m_axis_tdata_reg <= m_axis_tdata_int;
		m_axis_tkeep_reg <= m_axis_tkeep_int;
		m_axis_tlast_reg <= m_axis_tlast_int;
		m_axis_tdest_reg <= m_axis_tdest_int;
		m_axis_tid_reg <= m_axis_tid_int;
		m_axis_tuser_reg <= m_axis_tuser_int;
	end else if (store_axis_temp_to_output) begin
		m_axis_tdata_reg <= temp_m_axis_tdata_reg;
		m_axis_tkeep_reg <= temp_m_axis_tkeep_reg;
		m_axis_tlast_reg <= temp_m_axis_tlast_reg;
		m_axis_tdest_reg <= temp_m_axis_tdest_reg;
		m_axis_tid_reg <= temp_m_axis_tid_reg;
		m_axis_tuser_reg <= temp_m_axis_tuser_reg;
	end

	if (store_axis_int_to_temp) begin
		temp_m_axis_tdata_reg <= m_axis_tdata_int;
		temp_m_axis_tkeep_reg <= m_axis_tkeep_int;
		temp_m_axis_tlast_reg <= m_axis_tlast_int;
		temp_m_axis_tdest_reg <= m_axis_tdest_int;
		temp_m_axis_tid_reg <= m_axis_tid_int;
		temp_m_axis_tuser_reg <= m_axis_tuser_int;
	end
end

`endif

endmodule

`resetall