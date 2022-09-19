/*

 * Copyright 2019, The Regents of the University of California.
All rights reserved.
 * Created on Sat Feb 19 2022
 *
 * Copyright (c) 2022 IOA UCAS
 *
 * @Filename:	 hdr_chechsum.v
 * @Author:		 Jiawei Lin
 * @Last edit:	 16:47:40
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Header checksum offload module
 */
module hdr_checksum  #(
	parameter CSUM_DATA_WIDTH = 160,
	parameter AVST_DATA_WIDTH = 600,
	parameter AVST_ADDR_WIDTH = 9
)(
	input  wire clk,
	input  wire rst,
	
	input  wire 							csum_enable,
	input  wire [AVST_ADDR_WIDTH-1:0]		csum_start,
	input  wire [AVST_ADDR_WIDTH-1:0]		csum_offset,
	input  wire [AVST_DATA_WIDTH-1:0] 		stream_in_data,
	input  wire 							stream_in_valid,
	output wire 							stream_in_ready,

	output wire [AVST_DATA_WIDTH-1:0] 		stream_out_data,
	output wire 							stream_out_valid,
	input  wire 							stream_out_ready
);

// Compute checksum
localparam LEVELS = $clog2(CSUM_DATA_WIDTH/8);

reg [CSUM_DATA_WIDTH-1:0] sum_reg[LEVELS-2:0];
reg [LEVELS-2:0] sum_valid_reg = 0;
reg [16+LEVELS-1:0] sum_acc_temp = 0;

reg  [AVST_ADDR_WIDTH-1:0] csum_offset_reg = {AVST_ADDR_WIDTH{1'b0}}, csum_offset_next;

reg  stream_out_valid_reg = 1'b0, stream_out_valid_next;
reg  [AVST_DATA_WIDTH-1:0] stream_out_data_reg = {AVST_DATA_WIDTH{1'b0}}, stream_out_data_next;

assign stream_out_data = stream_out_data_reg;
assign stream_out_valid = stream_out_valid_reg;
assign stream_in_ready = (!stream_out_valid_reg) || stream_out_ready;

always @(*) begin
	stream_out_data_next = stream_out_data_reg;
	stream_out_valid_next = stream_out_valid_reg;

	if (stream_in_valid && stream_in_ready) begin
		csum_offset_next = csum_offset;
	end
	if (stream_out_valid_reg && stream_out_ready) begin
		stream_out_valid_next = 1'b0;
	end

	if (sum_valid_reg[LEVELS-2]) begin
		sum_acc_temp = sum_reg[LEVELS-2][16+LEVELS-1-1:0];
		sum_acc_temp = sum_acc_temp[15:0] + (sum_acc_temp >> 16);
		sum_acc_temp = sum_acc_temp[15:0] + sum_acc_temp[16];

		stream_out_data_next[csum_offset_reg*8 +: 8] = sum_acc_temp[15:8];
		stream_out_data_next[(csum_offset_reg+1)*8 +: 8] = sum_acc_temp[7:0];
		stream_out_valid_next = 1'b1;
	end
	if (!csum_enable) begin
		stream_out_data_next = stream_in_data;
		stream_out_valid_next = stream_in_valid;
	end
end

generate
	genvar l;
	for (l = 1; l < LEVELS-1; l = l + 1) begin
		always @(posedge clk) begin
			sum_valid_reg[l] <= sum_valid_reg[l] && !stream_out_ready;
			if (sum_valid_reg[l-1] && stream_out_ready) begin
				for (i = 0; i < CSUM_DATA_WIDTH/8/4/2**l; i = i + 1) begin
					sum_reg[l][i*(17+l) +: (17+l)] <= sum_reg[l-1][(i*2+0)*(17+l-1) +: (17+l-1)] + sum_reg[l-1][(i*2+1)*(17+l-1) +: (17+l-1)];
				end
				sum_valid_reg[l] <= 1'b1;
			end
			if (rst) begin
				sum_valid_reg[l] <= 1'b0;
			end
		end
	end
endgenerate

integer i;
always @(posedge clk) begin
	sum_valid_reg[0] <= 1'b0;
	if (rst) begin
		sum_valid_reg[0] <= 1'b0;
	end else if (csum_enable && stream_in_valid && stream_in_ready) begin
		csum_offset_reg <= csum_offset;
		for (i = 0; i < CSUM_DATA_WIDTH/8/4; i = i + 1) begin
			sum_reg[0][i*17 +: 17] <= {
				stream_in_data[csum_start+(4*i+0)*8 +: 8], 
				stream_in_data[csum_start+(4*i+1)*8 +: 8]
			} + {
				stream_in_data[csum_start+(4*i+2)*8 +: 8], 
				stream_in_data[csum_start+(4*i+3)*8 +: 8]
			};
		end
		sum_valid_reg[0] <= 1'b1;
	end

	stream_out_valid_reg <= stream_out_valid_next;
	stream_out_data_reg <= stream_out_data_next;
end

endmodule

`resetall
