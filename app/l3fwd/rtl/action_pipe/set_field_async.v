/*
 * Created on Sat Mar 12 2022
 *
 * Copyright (c) 2022 IOA UCAS
 *
 * @Filename:	 set_field_async.v
 * @Author:		 Jiawei Lin
 * @Last edit:	 22:13:45
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module set_field_async #(
	parameter DATA_WIDTH = 600,
	parameter SET_DATA_WIDTH = 8,
	parameter SET_ADDR_OFFSET = 0
)(
	input  wire [SET_DATA_WIDTH-1:0]	set_data,
	input  wire [DATA_WIDTH-1:0] 		data_in,
	output wire [DATA_WIDTH-1:0] 		data_out
);

initial begin
	if (SET_ADDR_OFFSET+SET_DATA_WIDTH > DATA_WIDTH) begin
		$error("no, (instance %m)");
		$finish;
	end
end

if (SET_ADDR_OFFSET == 0) begin
	if (SET_DATA_WIDTH == DATA_WIDTH) begin
		assign data_out = set_data;
	end else begin
		assign data_out = {
			data_in[DATA_WIDTH-1:SET_ADDR_OFFSET+SET_DATA_WIDTH],
			set_data
		};
	end
end else if (SET_ADDR_OFFSET+SET_DATA_WIDTH == DATA_WIDTH) begin
	assign data_out = {
		set_data,
		data_in[SET_ADDR_OFFSET-1:0]
	};
end else begin
	assign data_out = {
		data_in[DATA_WIDTH-1:SET_ADDR_OFFSET+SET_DATA_WIDTH],
		set_data,
		data_in[SET_ADDR_OFFSET-1:0]
	};
end

endmodule