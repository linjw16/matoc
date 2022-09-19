/*
 * Created on Sat May 04 2022
 *
 * Copyright (c) 2022 IOA UCAS
 *
 * @Filename:	 axis_deparser.v
 * @Author:		 Jiawei Lin
 * @Last edit:	 23:15:05
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Deparser merge modified header and payload. 
 */
module axis_deparser # (
	parameter S_DATA_WIDTH = 512,
	parameter S_KEEP_WIDTH = S_DATA_WIDTH/8,
	parameter S_ID_WIDTH = 8,
	parameter S_DEST_WIDTH = 4,
	parameter S_USER_WIDTH = 4,
	parameter M_DATA_WIDTH = S_DATA_WIDTH,
	parameter M_KEEP_WIDTH = M_DATA_WIDTH/8,
	parameter M_ID_WIDTH = S_ID_WIDTH,
	parameter M_DEST_WIDTH = S_DEST_WIDTH,
	parameter M_USER_WIDTH = S_USER_WIDTH,

	parameter HDR_DATA_WIDTH = 560,
	parameter HDR_KEEP_WIDTH = HDR_DATA_WIDTH/8,
	parameter HDR_ID_WIDTH = S_ID_WIDTH,
	parameter HDR_DEST_WIDTH = S_DEST_WIDTH,
	parameter HDR_USER_WIDTH = S_USER_WIDTH
) (
	input  wire 						clk,
	input  wire 						rst,

	input  wire [HDR_DATA_WIDTH-1:0] 	s_axis_hdr_tdata,
	input  wire [HDR_KEEP_WIDTH-1:0] 	s_axis_hdr_tkeep,
	input  wire 						s_axis_hdr_tvalid,
	output wire 						s_axis_hdr_tready,
	input  wire 						s_axis_hdr_tlast,
	input  wire [HDR_ID_WIDTH-1:0] 		s_axis_hdr_tid,
	input  wire [HDR_DEST_WIDTH-1:0] 	s_axis_hdr_tdest,
	input  wire [HDR_USER_WIDTH-1:0]	s_axis_hdr_tuser,

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
	if (S_DATA_WIDTH != M_DATA_WIDTH) begin
		$error("S_DATA_WIDTH != M_DATA_WIDTH, Not support yet. (inst %m)");
		$finish;
	end
	if (S_DATA_WIDTH > HDR_DATA_WIDTH) begin
		$error("S_DATA_WIDTH > HDR_DATA_WIDTH, Not support yet. (inst %m)");
		$finish;
	end
end


/*
 * 1. Input ctl and gen
 */
localparam CL_DATA_WIDTH = $clog2(HDR_DATA_WIDTH+1);
localparam CL_KEEP_WIDTH = $clog2(HDR_KEEP_WIDTH+1);

reg [CL_KEEP_WIDTH-1:0] s_axis_tsize_reg = {CL_KEEP_WIDTH{1'b0}}, s_axis_tsize_next;

wire [CL_KEEP_WIDTH-1:0] s_axis_hdr_tsize, s_axis_tsize;
wire [CL_KEEP_WIDTH-1:0] hdr_tkeep_enc, tkeep_enc;

assign s_axis_hdr_tsize = hdr_tkeep_enc+1;
assign s_axis_tsize = tkeep_enc+1;
assign s_axis_tready = (s_axis_hdr_tvalid && s_axis_hdr_tready) || (state_reg == ST_MERGE && m_axis_tready_int_reg);
assign s_axis_hdr_tready = (state_reg == ST_IDLE) && m_axis_tready_int_reg;

priority_encoder # (
	.WIDTH(HDR_KEEP_WIDTH),
	.LSB_HIGH_PRIORITY(0)
) keep2size_hdr (
	.input_unencoded	(s_axis_hdr_tkeep),
	.output_valid		(),
	.output_encoded		(hdr_tkeep_enc),
	.output_unencoded	()
);

priority_encoder # (
	.WIDTH(S_KEEP_WIDTH),
	.LSB_HIGH_PRIORITY(0)
) keep2size_fifo (
	.input_unencoded	(s_axis_tkeep),
	.output_valid		(),
	.output_encoded		(tkeep_enc),
	.output_unencoded	()
);

/*
 * 2. An FSM for transport
 */
localparam ST_WIDTH = 4,
	ST_IDLE		= 0,
	ST_MERGE	= 1,
	ST_LAST		= 2;

// wire [2*M_DATA_WIDTH-1:0] s_axis_hdr_tdata_pad;

// assign s_axis_hdr_tdata_pad = {
// 	{2*M_DATA_WIDTH-HDR_DATA_WIDTH{1'b0}},
// 	s_axis_hdr_tdata
// };
// reg [M_DATA_WIDTH-1:0]	temp_tdata_next_DBG;
reg [M_DATA_WIDTH-1:0]	temp_tdata_reg = {M_DATA_WIDTH{1'b0}}, temp_tdata_next;
reg [M_KEEP_WIDTH-1:0]	temp_tkeep_reg = {M_KEEP_WIDTH{1'b0}}, temp_tkeep_next;
reg [M_USER_WIDTH-1:0]	temp_tuser_reg = {M_USER_WIDTH{1'b0}}, temp_tuser_next;
reg 					temp_tlast_reg = 1'b0, temp_tlast_next;
reg [M_ID_WIDTH-1:0] 	temp_tid_reg = {M_ID_WIDTH{1'b0}}, temp_tid_next;
reg [M_DEST_WIDTH-1:0]	temp_tdest_reg = {M_DEST_WIDTH{1'b0}}, temp_tdest_next;
reg [CL_DATA_WIDTH-1:0]	temp_size_reg = {CL_DATA_WIDTH{1'b0}}, 	temp_size_next;

reg [ST_WIDTH-1:0] state_reg = ST_IDLE, state_next;
reg [CL_MUX_COUNT-1:0] select_reg = {CL_MUX_COUNT{1'b0}}, select_next;

wire [CL_MUX_COUNT-1:0] select;

assign select = (state_reg == ST_IDLE) ? {CL_MUX_COUNT{1'b0}} : select_reg;
// assign select = select_reg;

always @(*) begin
	state_next = state_reg;
	select_next = select_reg;
	s_axis_tsize_next = s_axis_tsize_reg;

	m_axis_tdata_int	= mux_axis_tdata;
	m_axis_tkeep_int	= mux_axis_tkeep;
	m_axis_tvalid_int	= 1'b0;
	m_axis_tlast_int	= temp_tlast_reg;
	m_axis_tid_int		= temp_tid_reg;
	m_axis_tdest_int	= temp_tdest_reg;
	m_axis_tuser_int	= temp_tuser_reg;

	temp_tdata_next 	= temp_tdata_reg;
	temp_tkeep_next 	= temp_tkeep_reg;
	temp_tlast_next 	= temp_tlast_reg;
	temp_tid_next 		= temp_tid_reg;
	temp_tdest_next 	= temp_tdest_reg;
	temp_tuser_next 	= temp_tuser_reg;
	temp_size_next 		= temp_size_reg;

	case (state_reg)
		ST_IDLE: begin
			if (s_axis_hdr_tvalid && s_axis_hdr_tready) begin
				temp_tdata_next = mux_temp_tdata;
				temp_tid_next = s_axis_hdr_tid;
				temp_tdest_next = s_axis_hdr_tdest;
				temp_tuser_next = s_axis_hdr_tuser;
				m_axis_tid_int = s_axis_hdr_tid;
				m_axis_tdest_int = s_axis_hdr_tdest;
				m_axis_tuser_int = s_axis_hdr_tuser;
				if (|s_axis_hdr_tkeep[HDR_KEEP_WIDTH-1:M_KEEP_WIDTH]) begin	/* insert */
					state_next = s_axis_tlast ? ST_LAST : ST_MERGE;
					select_next = MUX_COUNT-1+M_KEEP_WIDTH-s_axis_hdr_tsize;
					// temp_tdata_next_DBG = s_axis_hdr_tdata >> ({4'h0, s_axis_hdr_tsize-M_KEEP_WIDTH} << 3);
					temp_tkeep_next = s_axis_hdr_tkeep >> (s_axis_hdr_tsize-M_KEEP_WIDTH);
					m_axis_tvalid_int = 1'b1;
					m_axis_tlast_int = 1'b0;
					temp_size_next = (s_axis_hdr_tsize - M_KEEP_WIDTH);
				end else if (s_axis_hdr_tkeep[M_KEEP_WIDTH-1]) begin
					state_next = s_axis_tlast ? ST_IDLE : ST_MERGE;
					// select_next = s_axis_tlast ? 0 : MUX_COUNT-1;
					select_next = MUX_COUNT-1;
					// temp_tdata_next_DBG = s_axis_hdr_tdata[M_DATA_WIDTH-1:0];
					temp_tkeep_next = s_axis_hdr_tkeep[M_KEEP_WIDTH-1:0];
					m_axis_tvalid_int = 1'b1;
					m_axis_tlast_int = s_axis_tlast;
					temp_size_next = 0;
				end else begin	/* modify */	/* remove */
					state_next = s_axis_tlast ? ST_IDLE : ST_MERGE;
					// select_next = s_axis_tlast ? 0 : M_KEEP_WIDTH-s_axis_hdr_tsize;
					select_next = M_KEEP_WIDTH-s_axis_hdr_tsize;
					// temp_tdata_next_DBG = s_axis_hdr_tdata << ({4'h0, M_KEEP_WIDTH-s_axis_hdr_tsize} << 3);
					temp_tkeep_next = s_axis_hdr_tkeep << (M_KEEP_WIDTH-s_axis_hdr_tsize);
					m_axis_tvalid_int = s_axis_tlast;
					m_axis_tlast_int = s_axis_tlast;
					temp_size_next = s_axis_hdr_tsize;
				end
			end
		end
		ST_MERGE: begin
			if (s_axis_tvalid && s_axis_tready) begin
				temp_tdata_next = s_axis_tdata;
				temp_tkeep_next = s_axis_tkeep;
				temp_size_next = (s_axis_tsize+temp_size_reg-M_KEEP_WIDTH);
				m_axis_tvalid_int = 1'b1;
				s_axis_tsize_next = s_axis_tsize;

				if (select_reg > RESD_WIDTH) begin
				end else begin
				end
				
				if (s_axis_tlast) begin
					if (M_KEEP_WIDTH >= s_axis_tsize+temp_size_reg) begin
						state_next = ST_IDLE;
						// select_next = 0;
						m_axis_tlast_int = 1'b1;
					end else begin
						state_next = ST_LAST;
					end
				end
			end
		end
		ST_LAST: begin
			m_axis_tkeep_int = {M_KEEP_WIDTH{1'b1}} >> (M_KEEP_WIDTH-temp_size_reg);
			if (m_axis_tready_int_reg) begin
				state_next = ST_IDLE;
				// select_next = 0;
				m_axis_tvalid_int = 1'b1;
				m_axis_tlast_int = 1'b1;
			end
		end
		default: begin
			
		end
	endcase
end

always @(posedge clk) begin
	if (rst) begin
		temp_tdata_reg			<= {M_DATA_WIDTH{1'b0}};
		temp_tkeep_reg			<= {M_KEEP_WIDTH{1'b0}};
		temp_tuser_reg			<= {M_USER_WIDTH{1'b0}};
		temp_tlast_reg			<= 1'b0;
		temp_tdest_reg			<= {M_DEST_WIDTH{1'b0}};
		temp_tid_reg			<= {M_ID_WIDTH{1'b0}};
		temp_size_reg			<= {CL_DATA_WIDTH{1'b0}};
		s_axis_tsize_reg		<= {CL_KEEP_WIDTH{1'b0}};
		state_reg				<= ST_IDLE;
		select_reg				<= {CL_MUX_COUNT{1'b0}};
	end else begin
		temp_tdata_reg			<= temp_tdata_next;
		temp_tkeep_reg			<= temp_tkeep_next;
		temp_tuser_reg			<= temp_tuser_next;
		temp_tlast_reg			<= temp_tlast_next;
		temp_tdest_reg			<= temp_tdest_next;
		temp_tid_reg			<= temp_tid_next;
		temp_size_reg			<= temp_size_next;
		s_axis_tsize_reg		<= s_axis_tsize_next;
		state_reg				<= state_next;
		select_reg				<= select_next;
	end
end


/*
 * Merge logic
 */
localparam RESD_WIDTH = HDR_KEEP_WIDTH-M_KEEP_WIDTH;
localparam MUX_COUNT = (RESD_WIDTH+1)*2;
localparam CL_MUX_COUNT = $clog2(MUX_COUNT);

wire [M_DATA_WIDTH-1:0] mux_temp_tdata;
wire [M_DATA_WIDTH-1:0] mux_axis_tdata;
wire [M_KEEP_WIDTH-1:0] mux_axis_tkeep;
wire [$clog2(MUX_COUNT-1)-1:0] select_temp;

assign select_temp = RESD_WIDTH+s_axis_hdr_tsize-M_KEEP_WIDTH;

genvar i, j;
generate
	for (i=0; i<M_KEEP_WIDTH; i=i+1) begin
		wire [8*(MUX_COUNT-1)-1:0]	temp_tdata_mux;
		wire [8*MUX_COUNT-1:0]	axis_tdata_mux, axis_tdata_mux_1;
		wire [MUX_COUNT-1:0]	axis_tkeep_mux, axis_tkeep_mux_1;

		if (i<RESD_WIDTH) begin
			assign temp_tdata_mux = {
				s_axis_hdr_tdata[8*(i+RESD_WIDTH+1)-1:0],
				{8*(RESD_WIDTH-i){1'b0}}
			};
		end else begin
			assign temp_tdata_mux = s_axis_hdr_tdata[8*(i-RESD_WIDTH)+:8*(MUX_COUNT-1)];
		end
		assign mux_temp_tdata[8*i+:8] = temp_tdata_mux >> ({4'h0, select_temp} << 3);

		if (i<RESD_WIDTH) begin
			assign axis_tdata_mux_1 = {
				s_axis_tdata[0+:8*(i+1)],
				temp_tdata_reg[M_DATA_WIDTH-1-:8*(RESD_WIDTH-i)],
				temp_tdata_reg[8*(i)+:8*(RESD_WIDTH+1)]					/* fix width temp reg */
			};
			assign axis_tkeep_mux_1 = {
				s_axis_tkeep[0+:i+1],
				temp_tkeep_reg[M_KEEP_WIDTH-1-:(RESD_WIDTH-i)],
				temp_tkeep_reg[(i)+:(RESD_WIDTH+1)]
			};
		end else if (i>=M_KEEP_WIDTH-RESD_WIDTH) begin
			assign axis_tdata_mux_1 = {
				s_axis_tdata[8*(i-RESD_WIDTH)+:8*(RESD_WIDTH+1)],	/* fix width input */
				s_axis_tdata[0+:8*(i+1+RESD_WIDTH-M_KEEP_WIDTH)],
				temp_tdata_reg[M_DATA_WIDTH-1:8*(i)]
			};
			assign axis_tkeep_mux_1 = {
				s_axis_tkeep[(i-RESD_WIDTH)+:(RESD_WIDTH+1)],
				s_axis_tkeep[0+:(i+1+RESD_WIDTH-M_KEEP_WIDTH)],
				temp_tkeep_reg[M_KEEP_WIDTH-1:(i)]
			};
		end else begin
			assign axis_tdata_mux_1 = {
				s_axis_tdata[8*(i-RESD_WIDTH)+:8*(RESD_WIDTH+1)],	/* fix width input */
				temp_tdata_reg[8*(i)+:8*(RESD_WIDTH+1)]				/* fix width temp reg */
			};
			assign axis_tkeep_mux_1 = {
				s_axis_tkeep[(i-RESD_WIDTH)+:(RESD_WIDTH+1)],
				temp_tkeep_reg[(i)+:(RESD_WIDTH+1)]
			};
		end
		assign axis_tdata_mux = {axis_tdata_mux_1[8*MUX_COUNT-1:8], s_axis_hdr_tdata[8*i+:8]};
		assign axis_tkeep_mux = {axis_tkeep_mux_1[MUX_COUNT-1:1], s_axis_hdr_tkeep[i]};
		assign mux_axis_tdata[8*i+:8] = axis_tdata_mux >> ({4'h0, select} << 3);
		assign mux_axis_tkeep[i] = axis_tkeep_mux >> select;
	end 
endgenerate


/*
 * 5. Output datapath
 */
reg store_avst_int_to_output;
reg store_avst_int_to_temp;
reg store_avst_temp_tto_output;
reg m_axis_tvalid_reg = 1'b0, m_axis_tvalid_next, m_axis_tvalid_int;
reg temp_m_axis_tvalid_reg = 1'b0, temp_m_axis_tvalid_next;
reg m_axis_tready_int_reg = 1'b0;

reg  [M_DATA_WIDTH-1:0] m_axis_tdata_reg = {M_DATA_WIDTH{1'b0}}, 	temp_m_axis_tdata_reg = {M_DATA_WIDTH{1'b0}}, 	m_axis_tdata_int;
reg  [M_KEEP_WIDTH-1:0] m_axis_tkeep_reg = {M_KEEP_WIDTH{1'b0}}, 	temp_m_axis_tkeep_reg = {M_KEEP_WIDTH{1'b0}}, 	m_axis_tkeep_int;
reg  					m_axis_tlast_reg = 1'b0, 					temp_m_axis_tlast_reg = 1'b0, 					m_axis_tlast_int;
reg  [M_ID_WIDTH-1:0] 	m_axis_tid_reg = {M_ID_WIDTH{1'b0}}, 		temp_m_axis_tid_reg = {M_ID_WIDTH{1'b0}}, 		m_axis_tid_int;
reg  [M_DEST_WIDTH-1:0] m_axis_tdest_reg = {M_DEST_WIDTH{1'b0}}, 	temp_m_axis_tdest_reg = {M_DEST_WIDTH{1'b0}}, 	m_axis_tdest_int;
reg  [M_USER_WIDTH-1:0] m_axis_tuser_reg = {M_USER_WIDTH{1'b0}}, 	temp_m_axis_tuser_reg = {M_USER_WIDTH{1'b0}},	m_axis_tuser_int;

assign m_axis_tdata = m_axis_tdata_reg;
assign m_axis_tkeep = m_axis_tkeep_reg;
assign m_axis_tvalid = m_axis_tvalid_reg;
assign m_axis_tlast = m_axis_tlast_reg;
assign m_axis_tid = m_axis_tid_reg;
assign m_axis_tdest = m_axis_tdest_reg;
assign m_axis_tuser = m_axis_tuser_reg;

/* enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input) */
wire m_axis_tready_int_early = m_axis_tready || (!temp_m_axis_tvalid_reg && (!m_axis_tvalid_reg || !m_axis_tvalid_int));

always @* begin
	m_axis_tvalid_next = m_axis_tvalid_reg;
	temp_m_axis_tvalid_next = temp_m_axis_tvalid_reg;

	store_avst_int_to_output = 1'b0;
	store_avst_int_to_temp = 1'b0;
	store_avst_temp_tto_output = 1'b0;

	if (m_axis_tready_int_reg) begin
		if (m_axis_tready || !m_axis_tvalid_reg) begin
			m_axis_tvalid_next = m_axis_tvalid_int;
			store_avst_int_to_output = 1'b1;
		end else begin
			temp_m_axis_tvalid_next = m_axis_tvalid_int;
			store_avst_int_to_temp = 1'b1;
		end
	end else if (m_axis_tready) begin
		m_axis_tvalid_next = temp_m_axis_tvalid_reg;
		temp_m_axis_tvalid_next = 1'b0;
		store_avst_temp_tto_output = 1'b1;
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
		m_axis_tid_reg <= {M_ID_WIDTH{1'b0}};
		m_axis_tdest_reg <= {M_DEST_WIDTH{1'b0}};
		m_axis_tuser_reg <= {M_USER_WIDTH{1'b0}};
		temp_m_axis_tdata_reg <= {M_DATA_WIDTH{1'b0}};
		temp_m_axis_tkeep_reg <= {M_KEEP_WIDTH{1'b0}};
		temp_m_axis_tlast_reg <= 1'b0;
		temp_m_axis_tid_reg <= {M_ID_WIDTH{1'b0}};
		temp_m_axis_tdest_reg <= {M_DEST_WIDTH{1'b0}};
		temp_m_axis_tuser_reg <= {M_USER_WIDTH{1'b0}};
	end else begin
		m_axis_tvalid_reg <= m_axis_tvalid_next;
		m_axis_tready_int_reg <= m_axis_tready_int_early;
		temp_m_axis_tvalid_reg <= temp_m_axis_tvalid_next;
	end

	if (store_avst_int_to_output) begin
		m_axis_tdata_reg <= m_axis_tdata_int;
		m_axis_tkeep_reg <= m_axis_tkeep_int;
		m_axis_tlast_reg <= m_axis_tlast_int;
		m_axis_tid_reg <= m_axis_tid_int;
		m_axis_tdest_reg <= m_axis_tdest_int;
		m_axis_tuser_reg <= m_axis_tuser_int;
	end else if (store_avst_temp_tto_output) begin
		m_axis_tdata_reg <= temp_m_axis_tdata_reg;
		m_axis_tkeep_reg <= temp_m_axis_tkeep_reg;
		m_axis_tlast_reg <= temp_m_axis_tlast_reg;
		m_axis_tid_reg <= temp_m_axis_tid_reg;
		m_axis_tdest_reg <= temp_m_axis_tdest_reg;
		m_axis_tuser_reg <= temp_m_axis_tuser_reg;
	end

	if (store_avst_int_to_temp) begin
		temp_m_axis_tdata_reg <= m_axis_tdata_int;
		temp_m_axis_tkeep_reg <= m_axis_tkeep_int;
		temp_m_axis_tlast_reg <= m_axis_tlast_int;
		temp_m_axis_tid_reg <= m_axis_tid_int;
		temp_m_axis_tdest_reg <= m_axis_tdest_int;
		temp_m_axis_tuser_reg <= m_axis_tuser_int;
	end
end

endmodule

`resetall