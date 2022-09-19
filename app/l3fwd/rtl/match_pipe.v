/*
 * Created on Wed Jan 05 2022
 *
 * Copyright (c) 2022 IOA UCAS
 *
 * @Filename:	 match_pipe.v
 * @Author:		 Jiawei Lin
 * @Last edit:	 09:45:41
 */
/* verilator lint_off PINMISSING */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Match Table
 */
module match_pipe #(
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

	parameter FRACTCAM_ENABLE = 1,
	parameter TCAM_ADDR_WIDTH = 10,
	parameter TCAM_DATA_WIDTH = FRACTCAM_ENABLE ? 130 : 128,
	parameter TCAM_WR_WIDTH = 128,
	parameter TCAM_DEPTH = 2**TCAM_ADDR_WIDTH,
	parameter ACTN_ADDR_WIDTH = TCAM_ADDR_WIDTH,
	parameter ACTN_DATA_WIDTH = 48,
	parameter ACTN_STRB_WIDTH = ACTN_DATA_WIDTH/8
) (
	input  wire							clk,
	input  wire							rst,

	input  wire [S_DATA_WIDTH-1:0]		s_axis_tdata,
	input  wire [S_KEEP_WIDTH-1:0]		s_axis_tkeep,
	input  wire							s_axis_tvalid,
	output wire							s_axis_tready,
	input  wire							s_axis_tlast,
	input  wire [S_ID_WIDTH-1:0]		s_axis_tid,
	input  wire [S_DEST_WIDTH-1:0]		s_axis_tdest,
	input  wire [S_USER_WIDTH-1:0]		s_axis_tuser,

	output wire [M_DATA_WIDTH-1:0]		m_axis_tdata,
	output wire [M_KEEP_WIDTH-1:0]		m_axis_tkeep,
	output wire							m_axis_tvalid,
	input  wire							m_axis_tready,
	output wire							m_axis_tlast,
	output wire [M_ID_WIDTH-1:0]		m_axis_tid,
	output wire [M_DEST_WIDTH-1:0]		m_axis_tdest,
	output wire [M_USER_WIDTH-1:0]		m_axis_tuser,

	input  wire [TCAM_ADDR_WIDTH-1:0]	tcam_wr_addr,
	input  wire [8*TCAM_WR_WIDTH-1:0]	tcam_wr_data,
	input  wire [8*TCAM_WR_WIDTH-1:0]	tcam_wr_keep,
	input  wire							tcam_wr_valid,
	output wire							tcam_wr_ready,

	input  wire [TCAM_ADDR_WIDTH-1:0]	tcam_rd_cmd_addr,
	input  wire							tcam_rd_cmd_valid,
	output wire							tcam_rd_cmd_ready,
	output wire [TCAM_WR_WIDTH-1:0]		tcam_rd_rsp_data,
	output wire [TCAM_WR_WIDTH-1:0]		tcam_rd_rsp_keep,
	output wire							tcam_rd_rsp_valid,
	input  wire							tcam_rd_rsp_ready,

	input  wire [ACTN_ADDR_WIDTH-1:0]	actn_wr_cmd_addr,
	input  wire [ACTN_DATA_WIDTH-1:0]	actn_wr_cmd_data,
	input  wire [ACTN_STRB_WIDTH-1:0]	actn_wr_cmd_strb,
	input  wire							actn_wr_cmd_valid,
	output wire							actn_wr_cmd_ready,
	output wire							actn_wr_cmd_done,

	input  wire [ACTN_ADDR_WIDTH-1:0] 	actn_rd_cmd_addr,
	input  wire 						actn_rd_cmd_valid,
	output wire 						actn_rd_cmd_ready,
	output wire [ACTN_DATA_WIDTH-1:0] 	actn_rd_rsp_data,
	output wire							actn_rd_rsp_valid,
	input  wire							actn_rd_rsp_ready
);
localparam PT_WIDTH = 4;

initial begin
	if(S_USER_WIDTH < PT_WIDTH) begin
		$error("Error: Self-defined type width should be 4 (instance %m)");
		$finish;
	end
	if (TCAM_DEPTH > 2**TCAM_ADDR_WIDTH) begin
		$error("Error: TCAM_DEPTH > 2**TCAM_ADDR_WIDTH (instance %m)");
		$finish;
	end
	if(M_USER_WIDTH != S_USER_WIDTH+ACTN_DATA_WIDTH) begin
		$error("Error: M_USER_WIDTH != S_USER_WIDTH + ACTN_DATA_WIDTH (instance %m)");
		$finish;
	end
end

function [15:0] byte_rvs_2 (input [15:0] in_1);
	byte_rvs_2 = {in_1[7:0], in_1[15:8]};
endfunction

function [31:0] byte_rvs_4(input [31:0] in_1);
	byte_rvs_4 = {byte_rvs_2(in_1[15:0]), byte_rvs_2(in_1[31:16])};
endfunction

function [63:0] byte_rvs_8(input [63:0] in_1);
	byte_rvs_8 = {byte_rvs_4(in_1[31:0]), byte_rvs_2(in_1[63:32])};
endfunction

function [127:0] byte_rvs_16(input [127:0] in_1);
	byte_rvs_16 = {byte_rvs_8(in_1[63:0]), byte_rvs_8(in_1[127:64])};
endfunction

// `define BYPASS_MP
`ifdef BYPASS_MP

assign m_axis_tdata = s_axis_tdata;
assign m_axis_tkeep = s_axis_tkeep;
assign m_axis_tvalid = s_axis_tvalid;
assign s_axis_tready = m_axis_tready;
assign m_axis_tlast = s_axis_tlast;
assign m_axis_tid = s_axis_tid;
assign m_axis_tdest = s_axis_tdest;
assign m_axis_tuser = {action_code, s_axis_tuser};

wire [ACTN_DATA_WIDTH-1:0] action_code = {
	48'hDAD1D2D3D4D5,
	48'h5A5152535455,
	16'hFFFF,
	8'h0,
	8'b1111_1100
};

assign tcam_wr_ready = 1'b1;
assign actn_wr_cmd_ready = 1'b1;
assign actn_wr_cmd_done = 1'b1;

`else

/*
 * 1. Input prepare. 
 */
localparam IPv4_WIDTH = 32;
localparam IPv6_WIDTH = 128;
localparam DIP_OFFSET_IPV4 = (14+16)*8;
localparam DIP_OFFSET_VLV4 = (18+16)*8;
localparam DIP_OFFSET_IPV6 = (14+24)*8;
localparam DIP_OFFSET_VLV6 = (18+24)*8;

localparam 
	PT_IPV4 = 4'h1,
	PT_VLV4 = 4'h2,
	PT_IPV6 = 4'h3,
	PT_VLV6 = 4'h4;
localparam CL_TCAM_DEPTH = $clog2(TCAM_DEPTH);

wire [IPv4_WIDTH-1:0] vlv4_dst, ipv4_dst; 
wire [IPv6_WIDTH-1:0] vlv6_dst, ipv6_dst;
wire [TCAM_DATA_WIDTH-1:0] search_key;

wire [PT_WIDTH-1:0] pkt_type = s_axis_tuser[S_USER_WIDTH-IPv4_WIDTH-1 -: PT_WIDTH];
assign ipv4_dst = s_axis_tdata[DIP_OFFSET_IPV4 +: IPv4_WIDTH];
assign vlv4_dst = s_axis_tdata[DIP_OFFSET_VLV4 +: IPv4_WIDTH];
assign ipv6_dst = s_axis_tdata[DIP_OFFSET_IPV6 +:IPv6_WIDTH];			// TODO: error
assign vlv6_dst = s_axis_tdata[DIP_OFFSET_VLV6 +:IPv6_WIDTH];		// TODO: error
/*assign search_key = (
	pkt_type == PT_IPV4 ? {98'b0, byte_rvs_4(ipv4_dst)} : (
		pkt_type == PT_VLV4 ? {98'b0, byte_rvs_4(vlv4_dst)} : (
			pkt_type == PT_IPV6 ? {2'b0, byte_rvs_16(ipv6_dst)} : (
				pkt_type == PT_VLV6 ? {2'b0, byte_rvs_16(vlv6_dst)} : {TCAM_DATA_WIDTH{1'b0}}
			)
		)
	)
);*/
/*
assign search_key = (
	pkt_type == PT_IPV4 ? {98'b0, byte_rvs_4(ipv4_dst)} : (
		pkt_type == PT_VLV4 ? {98'b0, byte_rvs_4(vlv4_dst)} : {TCAM_DATA_WIDTH{1'b0}}
	)
);*/
wire [IPv4_WIDTH-1:0] dst_ipv4 = s_axis_tuser[S_USER_WIDTH-1 -: IPv4_WIDTH];
assign search_key = {3'b000, dst_ipv4};
/* 
Packet Type:
	0x0:		default
	0x1:		ipv4
	0x2:		vlan+ipv4
	0x3:		ipv6
	0x4:		vlan+ipv6
*/

/*
 * 2. Pipeline registers assignment
 */

reg  [S_DATA_WIDTH-1:0]	axis_mch_tdata_reg = {S_DATA_WIDTH{1'b0}},	axis_mch_tdata_next;
reg  [S_KEEP_WIDTH-1:0]	axis_mch_tkeep_reg = {S_KEEP_WIDTH{1'b0}},	axis_mch_tkeep_next;
reg  					axis_mch_tvalid_reg = 1'b0,					axis_mch_tvalid_next;
wire 					axis_mch_tready;
reg  					axis_mch_tlast_reg = 1'b0,					axis_mch_tlast_next;
reg  [S_DEST_WIDTH-1:0]	axis_mch_tdest_reg = {S_DEST_WIDTH{1'b0}},	axis_mch_tdest_next;
reg  [S_ID_WIDTH-1:0] 	axis_mch_tid_reg = {S_ID_WIDTH{1'b0}},		axis_mch_tid_next;
reg  [S_USER_WIDTH-1:0]	axis_mch_tuser_reg = {S_USER_WIDTH{1'b0}},	axis_mch_tuser_next;

reg  [S_DATA_WIDTH-1:0]	axis_act_tdata_reg = {S_DATA_WIDTH{1'b0}},	axis_act_tdata_next;
reg  [S_KEEP_WIDTH-1:0]	axis_act_tkeep_reg = {S_KEEP_WIDTH{1'b0}},	axis_act_tkeep_next;
reg  					axis_act_tvalid_reg = 1'b0,					axis_act_tvalid_next;
wire 					axis_act_tready;
reg  					axis_act_tlast_reg = 1'b0,					axis_act_tlast_next;
reg  [S_DEST_WIDTH-1:0]	axis_act_tdest_reg = {S_DEST_WIDTH{1'b0}},	axis_act_tdest_next;
reg  [S_ID_WIDTH-1:0]	axis_act_tid_reg = {S_ID_WIDTH{1'b0}},		axis_act_tid_next;
reg  [S_USER_WIDTH-1:0]	axis_act_tuser_reg = {S_USER_WIDTH{1'b0}},	axis_act_tuser_next;

reg actn_rd_flag_reg = 1'b0, actn_rd_flag_next;

wire  tcam_wr_flag;
wire  actn_rd_flag;

assign tcam_wr_flag = tcam_wr_valid || !tcam_wr_ready;
assign actn_rd_flag = actn_rd_cmd_valid || actn_rd_flag_reg;
assign actn_rd_rsp_valid = actn_rd_flag_reg && actn_rd_rsp_valid_int;
assign s_axis_tready = search_ready;
assign axis_mch_tready = actn_rd_cmd_ready_int && !actn_rd_flag;
assign axis_act_tready = m_axis_tready_int_reg && !actn_rd_flag_reg;

integer i;
always @(*) begin
	actn_rd_flag_next = actn_rd_flag_reg;

	if (actn_rd_flag_reg && actn_rd_rsp_valid_int && actn_rd_rsp_ready) begin
		actn_rd_flag_next = 1'b0;
	end
	
	if (actn_rd_cmd_valid && !axis_act_tvalid_reg) begin
		actn_rd_flag_next = 1'b1;
	end

	tcam_mch_valid_next		= tcam_mch_valid_reg;
	tcam_act_valid_next		= tcam_act_valid_reg;
	tcam_act_addr_next		= tcam_act_addr_reg;

	axis_mch_tdata_next		= axis_mch_tdata_reg;
	axis_mch_tkeep_next		= axis_mch_tkeep_reg;
	axis_mch_tvalid_next	= axis_mch_tvalid_reg;
	axis_mch_tlast_next		= axis_mch_tlast_reg;
	axis_mch_tdest_next		= axis_mch_tdest_reg;
	axis_mch_tid_next		= axis_mch_tid_reg;
	axis_mch_tuser_next		= axis_mch_tuser_reg;

	axis_act_tdata_next		= axis_act_tdata_reg;
	axis_act_tkeep_next		= axis_act_tkeep_reg;
	axis_act_tvalid_next	= axis_act_tvalid_reg;
	axis_act_tlast_next		= axis_act_tlast_reg;
	axis_act_tdest_next		= axis_act_tdest_reg;
	axis_act_tid_next		= axis_act_tid_reg;
	axis_act_tuser_next		= axis_act_tuser_reg;

	if (match_valid && match_ready) begin
	end

	if (axis_act_tvalid_reg && axis_act_tready) begin
		axis_act_tvalid_next = 1'b0;
	end

	if (axis_mch_tvalid_reg && axis_mch_tready) begin
		axis_mch_tvalid_next = 1'b0;
		tcam_mch_valid_next = tcam_mch_valid;
		tcam_act_addr_next = tcam_mch_addr;

		axis_act_tdata_next		= axis_mch_tdata_reg;
		axis_act_tkeep_next		= axis_mch_tkeep_reg;
		axis_act_tvalid_next	= 1'b1;
		axis_act_tlast_next		= axis_mch_tlast_reg;
		axis_act_tdest_next		= axis_mch_tdest_reg;
		axis_act_tid_next		= axis_mch_tid_reg;
		axis_act_tuser_next		= axis_mch_tuser_reg;
	end

	if (s_axis_tvalid && s_axis_tready) begin
		axis_mch_tdata_next		= s_axis_tdata;
		axis_mch_tkeep_next		= s_axis_tkeep;
		axis_mch_tvalid_next	= 1'b1;
		axis_mch_tlast_next		= s_axis_tlast;
		axis_mch_tdest_next		= s_axis_tdest;
		axis_mch_tid_next		= s_axis_tid;
		axis_mch_tuser_next		= s_axis_tuser;
	end

end

always @ (posedge clk) begin
	if (rst) begin
		actn_rd_flag_reg	<= 1'b0;
		tcam_mch_valid_reg	<= 1'b0;
		tcam_act_valid_reg	<= 1'b0;
		tcam_act_addr_reg	<= {CL_TCAM_DEPTH{1'b0}};

		axis_mch_tdata_reg	<= {S_DATA_WIDTH{1'b0}};
		axis_mch_tkeep_reg	<= {S_KEEP_WIDTH{1'b0}};
		axis_mch_tvalid_reg	<= 1'b0;
		axis_mch_tlast_reg	<= 1'b0;
		axis_mch_tdest_reg	<= {S_DEST_WIDTH{1'b0}};
		axis_mch_tid_reg	<= {S_ID_WIDTH{1'b0}};
		axis_mch_tuser_reg	<= {S_USER_WIDTH{1'b0}};

		axis_act_tdata_reg	<= {S_DATA_WIDTH{1'b0}};
		axis_act_tkeep_reg	<= {S_KEEP_WIDTH{1'b0}};
		axis_act_tvalid_reg	<= 1'b0;
		axis_act_tlast_reg	<= 1'b0;
		axis_act_tdest_reg	<= {S_DEST_WIDTH{1'b0}};
		axis_act_tid_reg	<= {S_ID_WIDTH{1'b0}};
		axis_act_tuser_reg	<= {S_USER_WIDTH{1'b0}};

	end else begin
		actn_rd_flag_reg	<= actn_rd_flag_next;
		tcam_mch_valid_reg	<= tcam_mch_valid_next;
		tcam_act_valid_reg	<= tcam_act_valid_next;
		tcam_act_addr_reg	<= tcam_act_addr_next;

		axis_mch_tdata_reg	<= axis_mch_tdata_next;
		axis_mch_tkeep_reg	<= axis_mch_tkeep_next;
		axis_mch_tvalid_reg	<= axis_mch_tvalid_next;
		axis_mch_tlast_reg	<= axis_mch_tlast_next;
		axis_mch_tdest_reg	<= axis_mch_tdest_next;
		axis_mch_tid_reg	<= axis_mch_tid_next;
		axis_mch_tuser_reg	<= axis_mch_tuser_next;

		axis_act_tdata_reg	<= axis_act_tdata_next;
		axis_act_tkeep_reg	<= axis_act_tkeep_next;
		axis_act_tvalid_reg	<= axis_act_tvalid_next;
		axis_act_tlast_reg	<= axis_act_tlast_next;
		axis_act_tdest_reg	<= axis_act_tdest_next;
		axis_act_tid_reg	<= axis_act_tid_next;
		axis_act_tuser_reg	<= axis_act_tuser_next;
	end
end

/*
 * 3. Match table using TCAM.  
 */
reg tcam_mch_valid_reg = 1'b0, tcam_mch_valid_next;
reg tcam_act_valid_reg = 1'b0, tcam_act_valid_next;

wire [CL_TCAM_DEPTH-1:0] tcam_mch_addr;
wire [TCAM_DEPTH-1:0] match_line;
wire tcam_en, tcam_mch_valid;
wire tcam_mt_mch, tcam_sg_mch, tcam_rd_wrn;	// TODO: Not yet used. 
wire match_valid;
wire match_ready;
wire search_valid;
wire search_ready;

assign tcam_en = !rst;
assign search_valid = s_axis_tvalid;
assign match_ready = axis_mch_tready;

if (FRACTCAM_ENABLE) begin
	fractcam #(
		.ADDR_WIDTH	(TCAM_ADDR_WIDTH),
		.DATA_WIDTH	(TCAM_WR_WIDTH),
		.DATA_DEPTH	(TCAM_DEPTH)
	) tcam_inst (
		.clk(clk),
		.rst(rst),

		.wr_addr		(tcam_wr_addr),	/* align to 8 */
		.wr_data		(tcam_wr_data),
		.wr_keep		(tcam_wr_keep),
		.wr_valid		(tcam_wr_valid),
		.wr_ready		(tcam_wr_ready),

		.rd_cmd_addr	(tcam_rd_cmd_addr),
		.rd_cmd_valid	(tcam_rd_cmd_valid),
		.rd_cmd_ready	(tcam_rd_cmd_ready),

		.rd_rsp_data	(tcam_rd_rsp_data),
		.rd_rsp_keep	(tcam_rd_rsp_keep),
		.rd_rsp_valid	(tcam_rd_rsp_valid),
		.rd_rsp_ready	(tcam_rd_rsp_ready),

		.search_key		(search_key),
		.search_valid	(search_valid),
		.search_ready	(search_ready),
		.match_line		(match_line),
		.match_valid	(match_valid),
		.match_ready	(match_ready)
	);
	
	priority_encoder #(
		.WIDTH(TCAM_DEPTH),
		.LSB_HIGH_PRIORITY(1)
	) priority_encoder_inst (
		.input_unencoded	(match_line),
		.output_valid		(tcam_mch_valid),
		.output_encoded		(tcam_mch_addr),
		.output_unencoded	()
	);
/*
else
	cam_wrapper cam_wrapper_inst(
		.CLK				(clk),
		.EN					(tcam_en),

		.WE					(tcam_wr_valid_reg),
		.WR_ADDR			(tcam_wr_addr_reg),
		.DIN				(tcam_wr_data_reg),
		.DATA_MASK			(tcam_wr_keep_reg),
		
		.CMP_DIN			(search_key),
		.CMP_DATA_MASK		(tcam_cmp_mask),
		.BUSY				(tcam_wr_ready),
		.MATCH				(tcam_mch_valid),
		.MATCH_ADDR			(tcam_mch_addr),
		.MULTIPLE_MATCH		(tcam_mt_mch),
		.SINGLE_MATCH		(tcam_sg_mch),
		.READ_WARNING		(tcam_rd_wrn)
	);
*/
end

/*
 * 4. Action table. 
 */
localparam CHANNEL_ENABLE = 1;

reg [CL_TCAM_DEPTH-1:0] tcam_act_addr_reg = {CL_TCAM_DEPTH{1'b0}}, tcam_act_addr_next;

wire actn_rd_cmd_valid_int, actn_rd_cmd_ready_int;
wire actn_rd_rsp_valid_int, actn_rd_rsp_ready_int;
wire [ACTN_ADDR_WIDTH-1:0] actn_rd_cmd_addr_int;

assign actn_rd_cmd_addr_int = actn_rd_flag_reg ? actn_rd_cmd_addr : tcam_mch_addr;
assign actn_rd_cmd_valid_int = actn_rd_flag_reg ? actn_rd_cmd_valid : (match_valid && match_ready);
assign actn_rd_cmd_ready = actn_rd_flag_reg && actn_rd_cmd_ready_int;
assign actn_rd_rsp_ready_int = actn_rd_flag_reg ? actn_rd_rsp_ready : axis_act_tready;

dma_psdpram # (
	.SIZE					(TCAM_DEPTH*ACTN_STRB_WIDTH),
	.SEG_COUNT				(1),
	.SEG_DATA_WIDTH			(ACTN_DATA_WIDTH),
	.SEG_ADDR_WIDTH			(ACTN_ADDR_WIDTH),
	.SEG_BE_WIDTH			(ACTN_STRB_WIDTH),
	.PIPELINE				(1)
) actn_tbl_inst (
	.clk					(clk),
	.rst					(rst),

	.wr_cmd_addr			(actn_wr_cmd_addr),
	.wr_cmd_data			(actn_wr_cmd_data),
	.wr_cmd_be				(actn_wr_cmd_strb),
	.wr_cmd_valid			(actn_wr_cmd_valid),
	.wr_cmd_ready			(actn_wr_cmd_ready),
	.wr_done				(actn_wr_cmd_done),

	.rd_cmd_addr			(actn_rd_cmd_addr_int),
	.rd_cmd_valid			(actn_rd_cmd_valid_int),
	.rd_cmd_ready			(actn_rd_cmd_ready_int),
	.rd_resp_data			(actn_rd_rsp_data),
	.rd_resp_valid			(actn_rd_rsp_valid_int),
	.rd_resp_ready			(actn_rd_rsp_ready_int)
);

wire [ACTN_DATA_WIDTH-1:0] action_code;

assign action_code = tcam_mch_valid_reg ? actn_rd_rsp_data : {ACTN_DATA_WIDTH{1'b0}};

/*
 * 5. Datapath control
 */
reg store_axis_int_to_output;
reg store_axis_int_to_temp;
reg store_axis_temp_to_output;
reg m_axis_tvalid_reg = 1'b0, m_axis_tvalid_next, m_axis_tvalid_int;
reg temp_m_axis_tvalid_reg = 1'b0, temp_m_axis_tvalid_next;
reg m_axis_tready_int_reg = 1'b0;

reg  [M_DATA_WIDTH-1:0]	m_axis_tdata_int;
reg  [M_KEEP_WIDTH-1:0]	m_axis_tkeep_int;
reg 					m_axis_tlast_int;
reg  [M_DEST_WIDTH-1:0]	m_axis_tdest_int;
reg  [M_ID_WIDTH-1:0] 	m_axis_tid_int;
reg  [M_USER_WIDTH-1:0]	m_axis_tuser_int;

reg  [M_DATA_WIDTH-1:0]	m_axis_tdata_reg = {M_DATA_WIDTH{1'b0}},	temp_m_axis_tdata_reg = {M_DATA_WIDTH{1'b0}};
reg  [M_KEEP_WIDTH-1:0]	m_axis_tkeep_reg = {M_KEEP_WIDTH{1'b0}},	temp_m_axis_tkeep_reg = {M_KEEP_WIDTH{1'b0}};
reg 					m_axis_tlast_reg = 1'b0,					temp_m_axis_tlast_reg = 1'b0;
reg  [M_DEST_WIDTH-1:0]	m_axis_tdest_reg = {M_DEST_WIDTH{1'b0}},	temp_m_axis_tdest_reg = {M_DEST_WIDTH{1'b0}};
reg  [M_ID_WIDTH-1:0] 	m_axis_tid_reg = {M_ID_WIDTH{1'b0}}, 		temp_m_axis_tid_reg = {M_ID_WIDTH{1'b0}};
reg  [M_USER_WIDTH-1:0]	m_axis_tuser_reg = {M_USER_WIDTH{1'b0}},	temp_m_axis_tuser_reg = {M_USER_WIDTH{1'b0}};

assign m_axis_tdata		= m_axis_tdata_reg;
assign m_axis_tkeep		= m_axis_tkeep_reg;
assign m_axis_tvalid	= m_axis_tvalid_reg;
assign m_axis_tlast		= m_axis_tlast_reg;
assign m_axis_tdest		= m_axis_tdest_reg;
assign m_axis_tid		= m_axis_tid_reg;
assign m_axis_tuser		= m_axis_tuser_reg;

/* enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input) */
wire m_axis_tready_int_early = m_axis_tready || (!temp_m_axis_tvalid_reg && (!m_axis_tvalid_reg || !m_axis_tvalid_int));

always @* begin
	m_axis_tdata_int	= {{M_DATA_WIDTH-S_DATA_WIDTH{1'b0}}, axis_act_tdata_reg};
	m_axis_tkeep_int	= {{M_KEEP_WIDTH-S_KEEP_WIDTH{1'b0}}, axis_act_tkeep_reg};
	m_axis_tvalid_int	= actn_rd_rsp_valid_int && !actn_rd_flag_reg;
	m_axis_tlast_int	= axis_act_tlast_reg;
	m_axis_tid_int		= axis_act_tid_reg;
	m_axis_tdest_int	= axis_act_tdest_reg;
	m_axis_tuser_int	= {action_code, axis_act_tuser_reg};
	
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

wire [TCAM_DATA_WIDTH-1:0] dbg_ipv4_reg = byte_rvs_4(m_axis_tdata[DIP_OFFSET_IPV4 +: IPv4_WIDTH]);
wire [TCAM_DATA_WIDTH-1:0] dbg_ipv4_int = byte_rvs_4(m_axis_tdata_int[DIP_OFFSET_IPV4 +: IPv4_WIDTH]);
wire [TCAM_DATA_WIDTH-1:0] dbg_ipv4_temp = byte_rvs_4(temp_m_axis_tdata_reg[DIP_OFFSET_IPV4 +: IPv4_WIDTH]);
wire [TCAM_DATA_WIDTH-1:0] dbg_ipv4_tcam = byte_rvs_4(axis_mch_tdata_reg[240 +: 32]);
wire [TCAM_DATA_WIDTH-1:0] dbg_ipv4_actn = byte_rvs_4(axis_act_tdata_reg[240 +: 32]);

`endif

endmodule

`resetall

/*

TCP/UDP Frame (IPv4)

			Field						Length
[47:0]		Destination MAC address	 	6 octets
[95:48]		Source MAC address			6 octets
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

*/