
/*
 * Created on Wed Jun 08 2022
 *
 * Copyright (c) 2022 IOA UCAS
 *
 * @Filename:	 axis_ttl_dec.v
 * @Author:		 Jiawei Lin
 * @Last edit:	 22:50:21
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Time-to-Live decrement
 */
module axis_ttl_dec #(
	parameter DATA_WIDTH = 512,
	parameter KEEP_WIDTH = DATA_WIDTH/8,
	parameter ID_WIDTH = 8,
	parameter DEST_WIDTH = 4,
	parameter USER_WIDTH = 4,

	parameter PT_IPV4 = 4'h1,
	parameter PT_VLV4 = 4'h2,
	parameter PT_IPV6 = 4'h3,
	parameter PT_VLV6 = 4'h4,
	parameter PT_OFFSET = 8,
	parameter PT_WIDTH = 4,
	parameter ENABLE = 1
) (
	input  wire clk,
	input  wire rst,

	input  wire [DATA_WIDTH-1:0]	s_axis_tdata,
	input  wire [KEEP_WIDTH-1:0]	s_axis_tkeep,
	input  wire 					s_axis_tvalid,
	output wire 					s_axis_tready,
	input  wire 					s_axis_tlast,
	input  wire [ID_WIDTH-1:0]		s_axis_tid,	
	input  wire [DEST_WIDTH-1:0]	s_axis_tdest,	
	input  wire [USER_WIDTH-1:0]	s_axis_tuser,

	output wire [DATA_WIDTH-1:0]	m_axis_tdata,
	output wire [KEEP_WIDTH-1:0]	m_axis_tkeep,
	output wire 					m_axis_tvalid,
	input  wire 					m_axis_tready,
	output wire 					m_axis_tlast,
	output wire [ID_WIDTH-1:0]		m_axis_tid,
	output wire [DEST_WIDTH-1:0]	m_axis_tdest,
	output wire [USER_WIDTH-1:0]	m_axis_tuser
);

localparam TTL_WIDTH = 8;
localparam 
	TTL_OFFSET_IPV4 = (14+2+2+2+2)*8,
	TTL_OFFSET_VLV4 = (18+2+2+2+2)*8,
	TTL_OFFSET_IPV6 = (14+4+2+1)*8,		// TODO: not sure
	TTL_OFFSET_VLV6 = (18+4+2+1)*8;

wire [PT_WIDTH-1:0] pkt_type = s_axis_tuser[PT_OFFSET +: PT_WIDTH];
wire [TTL_WIDTH-1:0] ttl_ipv4, ttl_vlv4, ttl_ipv6, ttl_vlv6;

if (ENABLE) begin
	assign ttl_ipv4 = s_axis_tdata[TTL_OFFSET_IPV4 +: TTL_WIDTH]-1;
	assign ttl_vlv4 = s_axis_tdata[TTL_OFFSET_VLV4 +: TTL_WIDTH]-1;
	assign ttl_ipv6 = s_axis_tdata[TTL_OFFSET_IPV6 +: TTL_WIDTH]-1;
	assign ttl_vlv6 = s_axis_tdata[TTL_OFFSET_VLV6 +: TTL_WIDTH]-1;
end else begin
	assign ttl_ipv4 = s_axis_tdata[TTL_OFFSET_IPV4 +: TTL_WIDTH];
	assign ttl_vlv4 = s_axis_tdata[TTL_OFFSET_VLV4 +: TTL_WIDTH];
	assign ttl_ipv6 = s_axis_tdata[TTL_OFFSET_IPV6 +: TTL_WIDTH];
	assign ttl_vlv6 = s_axis_tdata[TTL_OFFSET_VLV6 +: TTL_WIDTH];
end
assign s_axis_tready = m_axis_tready_int_reg;

always @(*) begin
	m_axis_tdata_int	= s_axis_tdata;
	m_axis_tkeep_int	= s_axis_tkeep;
	m_axis_tvalid_int	= 1'b0;
	m_axis_tlast_int	= s_axis_tlast;
	m_axis_tid_int		= s_axis_tid;
	m_axis_tdest_int	= s_axis_tdest;
	m_axis_tuser_int	= s_axis_tuser;

	if (s_axis_tvalid && s_axis_tready) begin
		m_axis_tvalid_int	= 1'b1;
		case (pkt_type)
			PT_IPV4: begin
				m_axis_tdata_int = {
					s_axis_tdata[DATA_WIDTH-1:TTL_OFFSET_IPV4+TTL_WIDTH],
					ttl_ipv4,
					s_axis_tdata[TTL_OFFSET_IPV4-1:0]
				};
			end
			PT_VLV4: begin
				m_axis_tdata_int = {
					s_axis_tdata[DATA_WIDTH-1:TTL_OFFSET_VLV4+TTL_WIDTH],
					ttl_vlv4,
					s_axis_tdata[TTL_OFFSET_VLV4-1:0]
				};
			end
			PT_IPV6: begin
				m_axis_tdata_int = {
					s_axis_tdata[DATA_WIDTH-1:TTL_OFFSET_IPV6+TTL_WIDTH],
					ttl_ipv6,
					s_axis_tdata[TTL_OFFSET_IPV6-1:0]
				};
			end
			PT_VLV6: begin
				m_axis_tdata_int = {
					s_axis_tdata[DATA_WIDTH-1:TTL_OFFSET_VLV6+TTL_WIDTH],
					ttl_vlv6,
					s_axis_tdata[TTL_OFFSET_VLV6-1:0]
				};
			end
			default: ;
		endcase
	end
end

always @(posedge clk) begin
	
end


/*
 * Datapath control
 */
reg store_axis_int_to_output;
reg store_axis_int_to_temp;
reg store_axis_temp_to_output;
reg m_axis_tvalid_reg = 1'b0, m_axis_tvalid_next, m_axis_tvalid_int;
reg temp_m_axis_tvalid_reg = 1'b0, temp_m_axis_tvalid_next;
reg m_axis_tready_int_reg = 1'b0;

reg [DATA_WIDTH-1:0]	m_axis_tdata_int;
reg [KEEP_WIDTH-1:0]	m_axis_tkeep_int;
reg 					m_axis_tlast_int;
reg [DEST_WIDTH-1:0]	m_axis_tdest_int;
reg [ID_WIDTH-1:0]		m_axis_tid_int;
reg [USER_WIDTH-1:0]	m_axis_tuser_int;

reg [DATA_WIDTH-1:0]	m_axis_tdata_reg = {DATA_WIDTH{1'b0}};
reg [KEEP_WIDTH-1:0]	m_axis_tkeep_reg = {KEEP_WIDTH{1'b0}};
reg 					m_axis_tlast_reg = 1'b0;
reg [ID_WIDTH-1:0]		m_axis_tid_reg = {ID_WIDTH{1'b0}};
reg [DEST_WIDTH-1:0]	m_axis_tdest_reg = {DEST_WIDTH{1'b0}};
reg [USER_WIDTH-1:0]	m_axis_tuser_reg = {USER_WIDTH{1'b0}};

reg [DATA_WIDTH-1:0]	temp_m_axis_tdata_reg = {DATA_WIDTH{1'b0}};
reg [KEEP_WIDTH-1:0]	temp_m_axis_tkeep_reg = {KEEP_WIDTH{1'b0}};
reg 					temp_m_axis_tlast_reg = 1'b0;
reg [ID_WIDTH-1:0]		temp_m_axis_tid_reg = {ID_WIDTH{1'b0}};
reg [DEST_WIDTH-1:0]	temp_m_axis_tdest_reg = {DEST_WIDTH{1'b0}};
reg [USER_WIDTH-1:0]	temp_m_axis_tuser_reg = {USER_WIDTH{1'b0}};

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

		m_axis_tdata_reg <= {DATA_WIDTH{1'b0}};
		m_axis_tkeep_reg <= {KEEP_WIDTH{1'b0}};
		m_axis_tlast_reg <= 1'b0;
		m_axis_tdest_reg <= {DEST_WIDTH{1'b0}};
		m_axis_tid_reg <= {ID_WIDTH{1'b0}};
		m_axis_tuser_reg <= {USER_WIDTH{1'b0}};

		temp_m_axis_tdata_reg <= {DATA_WIDTH{1'b0}};
		temp_m_axis_tkeep_reg <= {KEEP_WIDTH{1'b0}};
		temp_m_axis_tlast_reg <= 1'b0;
		temp_m_axis_tdest_reg <= {DEST_WIDTH{1'b0}};
		temp_m_axis_tid_reg <= {ID_WIDTH{1'b0}};
		temp_m_axis_tuser_reg <= {USER_WIDTH{1'b0}};
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

endmodule

`resetall
