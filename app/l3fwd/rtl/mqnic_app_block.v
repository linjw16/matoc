/*

Copyright 2021, The Regents of the University of California.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

	1. Redistributions of source code must retain the above copyright notice,
	  this list of conditions and the following disclaimer.

	2. Redistributions in binary form must reproduce the above copyright notice,
	  this list of conditions and the following disclaimer in the documentation
	  and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of The Regents of the University of California.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Application block
 */
module mqnic_app_block #
(
	// Structural configuration
	parameter IF_COUNT = 1,
	parameter PORTS_PER_IF = 1,
	parameter SCHED_PER_IF = PORTS_PER_IF,

	parameter PORT_COUNT = IF_COUNT*PORTS_PER_IF,

	// PTP configuration
	parameter PTP_CLK_PERIOD_NS_NUM = 4,
	parameter PTP_CLK_PERIOD_NS_DENOM = 1,
	parameter PTP_TS_WIDTH = 96,
	parameter PTP_USE_SAMPLE_CLOCK = 0,
	parameter PTP_PORT_CDC_PIPELINE = 0,
	parameter PTP_PEROUT_ENABLE = 0,
	parameter PTP_PEROUT_COUNT = 1,

	// Interface configuration
	parameter PTP_TS_ENABLE = 1,
	parameter TX_TAG_WIDTH = 16,
	parameter MAX_TX_SIZE = 9214,
	parameter MAX_RX_SIZE = 9214,

	// Application configuration
	parameter APP_ID = 32'h12340001,
	parameter APP_CTRL_ENABLE = 1,
	parameter APP_DMA_ENABLE = 1,
	parameter APP_AXIS_DIRECT_ENABLE = 1,
	parameter APP_AXIS_SYNC_ENABLE = 1,
	parameter APP_AXIS_IF_ENABLE = 1,
	parameter APP_STAT_ENABLE = 1,
	parameter APP_GPIO_IN_WIDTH = 32,
	parameter APP_GPIO_OUT_WIDTH = 32,

	// DMA interface configuration
	parameter DMA_ADDR_WIDTH = 64,
	parameter DMA_IMM_ENABLE = 0,
	parameter DMA_IMM_WIDTH = 32,
	parameter DMA_LEN_WIDTH = 16,
	parameter DMA_TAG_WIDTH = 16,
	parameter RAM_SEL_WIDTH = 4,
	parameter RAM_ADDR_WIDTH = 16,
	parameter RAM_SEG_COUNT = 2,
	parameter RAM_SEG_DATA_WIDTH = 256*2/RAM_SEG_COUNT,
	parameter RAM_SEG_BE_WIDTH = RAM_SEG_DATA_WIDTH/8,
	parameter RAM_SEG_ADDR_WIDTH = RAM_ADDR_WIDTH-$clog2(RAM_SEG_COUNT*RAM_SEG_BE_WIDTH),
	parameter RAM_PIPELINE = 2,

	// AXI lite interface (application control from host)
	parameter AXIL_APP_CTRL_DATA_WIDTH = 32,
	parameter AXIL_APP_CTRL_ADDR_WIDTH = 16,
	parameter AXIL_APP_CTRL_STRB_WIDTH = (AXIL_APP_CTRL_DATA_WIDTH/8),

	// AXI lite interface (control to NIC)
	parameter AXIL_CTRL_DATA_WIDTH = 32,
	parameter AXIL_CTRL_ADDR_WIDTH = 16,
	parameter AXIL_CTRL_STRB_WIDTH = (AXIL_CTRL_DATA_WIDTH/8),

	// Ethernet interface configuration (direct, async)
	parameter AXIS_DATA_WIDTH = 512,
	parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
	parameter AXIS_TX_USER_WIDTH = TX_TAG_WIDTH + 1,
	parameter AXIS_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1,
	parameter AXIS_RX_USE_READY = 0,

	// Ethernet interface configuration (direct, sync)
	parameter AXIS_SYNC_DATA_WIDTH = AXIS_DATA_WIDTH,
	parameter AXIS_SYNC_KEEP_WIDTH = AXIS_SYNC_DATA_WIDTH/8,
	parameter AXIS_SYNC_TX_USER_WIDTH = AXIS_TX_USER_WIDTH,
	parameter AXIS_SYNC_RX_USER_WIDTH = AXIS_RX_USER_WIDTH,

	// Ethernet interface configuration (interface)
	parameter AXIS_IF_DATA_WIDTH = AXIS_SYNC_DATA_WIDTH*2**$clog2(PORTS_PER_IF),
	parameter AXIS_IF_KEEP_WIDTH = AXIS_IF_DATA_WIDTH/8,
	parameter AXIS_IF_TX_ID_WIDTH = 12,
	parameter AXIS_IF_RX_ID_WIDTH = PORTS_PER_IF > 1 ? $clog2(PORTS_PER_IF) : 1,
	parameter AXIS_IF_TX_DEST_WIDTH = $clog2(PORTS_PER_IF)+4,
	parameter AXIS_IF_RX_DEST_WIDTH = 8,
	parameter AXIS_IF_TX_USER_WIDTH = AXIS_SYNC_TX_USER_WIDTH,
	parameter AXIS_IF_RX_USER_WIDTH = AXIS_SYNC_RX_USER_WIDTH,

	// Statistics counter subsystem
	parameter STAT_ENABLE = 1,
	parameter STAT_INC_WIDTH = 24,
	parameter STAT_ID_WIDTH = 12
)
(
	input  wire											clk,
	input  wire											rst,

	/*
	 * AXI-Lite slave interface (control from host)
	 */
	input  wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]			s_axil_app_ctrl_awaddr,
	input  wire [2:0]									s_axil_app_ctrl_awprot,
	input  wire											s_axil_app_ctrl_awvalid,
	output wire											s_axil_app_ctrl_awready,
	input  wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]			s_axil_app_ctrl_wdata,
	input  wire [AXIL_APP_CTRL_STRB_WIDTH-1:0]			s_axil_app_ctrl_wstrb,
	input  wire											s_axil_app_ctrl_wvalid,
	output wire											s_axil_app_ctrl_wready,
	output wire [1:0]									s_axil_app_ctrl_bresp,
	output wire											s_axil_app_ctrl_bvalid,
	input  wire											s_axil_app_ctrl_bready,
	input  wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]			s_axil_app_ctrl_araddr,
	input  wire [2:0]									s_axil_app_ctrl_arprot,
	input  wire											s_axil_app_ctrl_arvalid,
	output wire											s_axil_app_ctrl_arready,
	output wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]			s_axil_app_ctrl_rdata,
	output wire [1:0]									s_axil_app_ctrl_rresp,
	output wire											s_axil_app_ctrl_rvalid,
	input  wire											s_axil_app_ctrl_rready,

	/*
	 * AXI-Lite master interface (control to NIC)
	 */
	output wire [AXIL_CTRL_ADDR_WIDTH-1:0]				m_axil_ctrl_awaddr,
	output wire [2:0]									m_axil_ctrl_awprot,
	output wire											m_axil_ctrl_awvalid,
	input  wire											m_axil_ctrl_awready,
	output wire [AXIL_CTRL_DATA_WIDTH-1:0]				m_axil_ctrl_wdata,
	output wire [AXIL_CTRL_STRB_WIDTH-1:0]				m_axil_ctrl_wstrb,
	output wire											m_axil_ctrl_wvalid,
	input  wire											m_axil_ctrl_wready,
	input  wire [1:0]									m_axil_ctrl_bresp,
	input  wire											m_axil_ctrl_bvalid,
	output wire											m_axil_ctrl_bready,
	output wire [AXIL_CTRL_ADDR_WIDTH-1:0]				m_axil_ctrl_araddr,
	output wire [2:0]									m_axil_ctrl_arprot,
	output wire											m_axil_ctrl_arvalid,
	input  wire											m_axil_ctrl_arready,
	input  wire [AXIL_CTRL_DATA_WIDTH-1:0]				m_axil_ctrl_rdata,
	input  wire [1:0]									m_axil_ctrl_rresp,
	input  wire											m_axil_ctrl_rvalid,
	output wire											m_axil_ctrl_rready,

	/*
	 * DMA read descriptor output (control)
	 */
	output wire [DMA_ADDR_WIDTH-1:0]					m_axis_ctrl_dma_read_desc_dma_addr,
	output wire [RAM_SEL_WIDTH-1:0]						m_axis_ctrl_dma_read_desc_ram_sel,
	output wire [RAM_ADDR_WIDTH-1:0]					m_axis_ctrl_dma_read_desc_ram_addr,
	output wire [DMA_LEN_WIDTH-1:0]						m_axis_ctrl_dma_read_desc_len,
	output wire [DMA_TAG_WIDTH-1:0]						m_axis_ctrl_dma_read_desc_tag,
	output wire											m_axis_ctrl_dma_read_desc_valid,
	input  wire											m_axis_ctrl_dma_read_desc_ready,

	/*
	 * DMA read descriptor status input (control)
	 */
	input  wire [DMA_TAG_WIDTH-1:0]						s_axis_ctrl_dma_read_desc_status_tag,
	input  wire [3:0]									s_axis_ctrl_dma_read_desc_status_error,
	input  wire											s_axis_ctrl_dma_read_desc_status_valid,

	/*
	 * DMA write descriptor output (control)
	 */
	output wire [DMA_ADDR_WIDTH-1:0]					m_axis_ctrl_dma_write_desc_dma_addr,
	output wire [RAM_SEL_WIDTH-1:0]						m_axis_ctrl_dma_write_desc_ram_sel,
	output wire [RAM_ADDR_WIDTH-1:0]					m_axis_ctrl_dma_write_desc_ram_addr,
	output wire [DMA_IMM_WIDTH-1:0]						m_axis_ctrl_dma_write_desc_imm,
	output wire											m_axis_ctrl_dma_write_desc_imm_en,
	output wire [DMA_LEN_WIDTH-1:0]						m_axis_ctrl_dma_write_desc_len,
	output wire [DMA_TAG_WIDTH-1:0]						m_axis_ctrl_dma_write_desc_tag,
	output wire											m_axis_ctrl_dma_write_desc_valid,
	input  wire											m_axis_ctrl_dma_write_desc_ready,

	/*
	 * DMA write descriptor status input (control)
	 */
	input  wire [DMA_TAG_WIDTH-1:0]						s_axis_ctrl_dma_write_desc_status_tag,
	input  wire [3:0]									s_axis_ctrl_dma_write_desc_status_error,
	input  wire											s_axis_ctrl_dma_write_desc_status_valid,

	/*
	 * DMA read descriptor output (data)
	 */
	output wire [DMA_ADDR_WIDTH-1:0]					m_axis_data_dma_read_desc_dma_addr,
	output wire [RAM_SEL_WIDTH-1:0]						m_axis_data_dma_read_desc_ram_sel,
	output wire [RAM_ADDR_WIDTH-1:0]					m_axis_data_dma_read_desc_ram_addr,
	output wire [DMA_LEN_WIDTH-1:0]						m_axis_data_dma_read_desc_len,
	output wire [DMA_TAG_WIDTH-1:0]						m_axis_data_dma_read_desc_tag,
	output wire											m_axis_data_dma_read_desc_valid,
	input  wire											m_axis_data_dma_read_desc_ready,

	/*
	 * DMA read descriptor status input (data)
	 */
	input  wire [DMA_TAG_WIDTH-1:0]						s_axis_data_dma_read_desc_status_tag,
	input  wire [3:0]									s_axis_data_dma_read_desc_status_error,
	input  wire											s_axis_data_dma_read_desc_status_valid,

	/*
	 * DMA write descriptor output (data)
	 */
	output wire [DMA_ADDR_WIDTH-1:0]					m_axis_data_dma_write_desc_dma_addr,
	output wire [RAM_SEL_WIDTH-1:0]						m_axis_data_dma_write_desc_ram_sel,
	output wire [RAM_ADDR_WIDTH-1:0]					m_axis_data_dma_write_desc_ram_addr,
	output wire [DMA_IMM_WIDTH-1:0]						m_axis_data_dma_write_desc_imm,
	output wire											m_axis_data_dma_write_desc_imm_en,
	output wire [DMA_LEN_WIDTH-1:0]						m_axis_data_dma_write_desc_len,
	output wire [DMA_TAG_WIDTH-1:0]						m_axis_data_dma_write_desc_tag,
	output wire											m_axis_data_dma_write_desc_valid,
	input  wire											m_axis_data_dma_write_desc_ready,

	/*
	 * DMA write descriptor status input (data)
	 */
	input  wire [DMA_TAG_WIDTH-1:0]						s_axis_data_dma_write_desc_status_tag,
	input  wire [3:0]									s_axis_data_dma_write_desc_status_error,
	input  wire											s_axis_data_dma_write_desc_status_valid,

	/*
	 * DMA RAM interface (control)
	 */
	input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]		ctrl_dma_ram_wr_cmd_sel,
	input  wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]	ctrl_dma_ram_wr_cmd_be,
	input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]	ctrl_dma_ram_wr_cmd_addr,
	input  wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]	ctrl_dma_ram_wr_cmd_data,
	input  wire [RAM_SEG_COUNT-1:0]						ctrl_dma_ram_wr_cmd_valid,
	output wire [RAM_SEG_COUNT-1:0]						ctrl_dma_ram_wr_cmd_ready,
	output wire [RAM_SEG_COUNT-1:0]						ctrl_dma_ram_wr_done,
	input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]		ctrl_dma_ram_rd_cmd_sel,
	input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]	ctrl_dma_ram_rd_cmd_addr,
	input  wire [RAM_SEG_COUNT-1:0]						ctrl_dma_ram_rd_cmd_valid,
	output wire [RAM_SEG_COUNT-1:0]						ctrl_dma_ram_rd_cmd_ready,
	output wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]	ctrl_dma_ram_rd_resp_data,
	output wire [RAM_SEG_COUNT-1:0]						ctrl_dma_ram_rd_resp_valid,
	input  wire [RAM_SEG_COUNT-1:0]						ctrl_dma_ram_rd_resp_ready,

	/*
	 * DMA RAM interface (data)
	 */
	input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]		data_dma_ram_wr_cmd_sel,
	input  wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]	data_dma_ram_wr_cmd_be,
	input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]	data_dma_ram_wr_cmd_addr,
	input  wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]	data_dma_ram_wr_cmd_data,
	input  wire [RAM_SEG_COUNT-1:0]						data_dma_ram_wr_cmd_valid,
	output wire [RAM_SEG_COUNT-1:0]						data_dma_ram_wr_cmd_ready,
	output wire [RAM_SEG_COUNT-1:0]						data_dma_ram_wr_done,
	input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]		data_dma_ram_rd_cmd_sel,
	input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]	data_dma_ram_rd_cmd_addr,
	input  wire [RAM_SEG_COUNT-1:0]						data_dma_ram_rd_cmd_valid,
	output wire [RAM_SEG_COUNT-1:0]						data_dma_ram_rd_cmd_ready,
	output wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]	data_dma_ram_rd_resp_data,
	output wire [RAM_SEG_COUNT-1:0]						data_dma_ram_rd_resp_valid,
	input  wire [RAM_SEG_COUNT-1:0]						data_dma_ram_rd_resp_ready,

	/*
	 * PTP clock
	 */
	input  wire											ptp_clk,
	input  wire											ptp_rst,
	input  wire											ptp_sample_clk,
	input  wire											ptp_pps,
	input  wire [PTP_TS_WIDTH-1:0]						ptp_ts_96,
	input  wire											ptp_ts_step,
	input  wire											ptp_sync_pps,
	input  wire [PTP_TS_WIDTH-1:0]						ptp_sync_ts_96,
	input  wire											ptp_sync_ts_step,
	input  wire [PTP_PEROUT_COUNT-1:0]					ptp_perout_locked,
	input  wire [PTP_PEROUT_COUNT-1:0]					ptp_perout_error,
	input  wire [PTP_PEROUT_COUNT-1:0]					ptp_perout_pulse,

	/*
	 * Ethernet (direct MAC interface - lowest latency raw traffic)
	 */
	input  wire [PORT_COUNT-1:0]						direct_tx_clk,
	input  wire [PORT_COUNT-1:0]						direct_tx_rst,

	input  wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]		s_axis_direct_tx_tdata,
	input  wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]		s_axis_direct_tx_tkeep,
	input  wire [PORT_COUNT-1:0]						s_axis_direct_tx_tvalid,
	output wire [PORT_COUNT-1:0]						s_axis_direct_tx_tready,
	input  wire [PORT_COUNT-1:0]						s_axis_direct_tx_tlast,
	input  wire [PORT_COUNT*AXIS_TX_USER_WIDTH-1:0]		s_axis_direct_tx_tuser,

	output wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]		m_axis_direct_tx_tdata,
	output wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]		m_axis_direct_tx_tkeep,
	output wire [PORT_COUNT-1:0]						m_axis_direct_tx_tvalid,
	input  wire [PORT_COUNT-1:0]						m_axis_direct_tx_tready,
	output wire [PORT_COUNT-1:0]						m_axis_direct_tx_tlast,
	output wire [PORT_COUNT*AXIS_TX_USER_WIDTH-1:0]		m_axis_direct_tx_tuser,

	input  wire [PORT_COUNT*PTP_TS_WIDTH-1:0]			s_axis_direct_tx_cpl_ts,
	input  wire [PORT_COUNT*TX_TAG_WIDTH-1:0]			s_axis_direct_tx_cpl_tag,
	input  wire [PORT_COUNT-1:0]						s_axis_direct_tx_cpl_valid,
	output wire [PORT_COUNT-1:0]						s_axis_direct_tx_cpl_ready,

	output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]			m_axis_direct_tx_cpl_ts,
	output wire [PORT_COUNT*TX_TAG_WIDTH-1:0]			m_axis_direct_tx_cpl_tag,
	output wire [PORT_COUNT-1:0]						m_axis_direct_tx_cpl_valid,
	input  wire [PORT_COUNT-1:0]						m_axis_direct_tx_cpl_ready,

	input  wire [PORT_COUNT-1:0]						direct_rx_clk,
	input  wire [PORT_COUNT-1:0]						direct_rx_rst,

	input  wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]		s_axis_direct_rx_tdata,
	input  wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]		s_axis_direct_rx_tkeep,
	input  wire [PORT_COUNT-1:0]						s_axis_direct_rx_tvalid,
	output wire [PORT_COUNT-1:0]						s_axis_direct_rx_tready,
	input  wire [PORT_COUNT-1:0]						s_axis_direct_rx_tlast,
	input  wire [PORT_COUNT*AXIS_RX_USER_WIDTH-1:0]		s_axis_direct_rx_tuser,

	output wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]		m_axis_direct_rx_tdata,
	output wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]		m_axis_direct_rx_tkeep,
	output wire [PORT_COUNT-1:0]						m_axis_direct_rx_tvalid,
	input  wire [PORT_COUNT-1:0]						m_axis_direct_rx_tready,
	output wire [PORT_COUNT-1:0]						m_axis_direct_rx_tlast,
	output wire [PORT_COUNT*AXIS_RX_USER_WIDTH-1:0]		m_axis_direct_rx_tuser,

	/*
	 * Ethernet (synchronous MAC interface - low latency raw traffic)
	 */
	input  wire [PORT_COUNT*AXIS_SYNC_DATA_WIDTH-1:0]		s_axis_sync_tx_tdata,
	input  wire [PORT_COUNT*AXIS_SYNC_KEEP_WIDTH-1:0]		s_axis_sync_tx_tkeep,
	input  wire [PORT_COUNT-1:0]							s_axis_sync_tx_tvalid,
	output wire [PORT_COUNT-1:0]							s_axis_sync_tx_tready,
	input  wire [PORT_COUNT-1:0]							s_axis_sync_tx_tlast,
	input  wire [PORT_COUNT*AXIS_SYNC_TX_USER_WIDTH-1:0]	s_axis_sync_tx_tuser,

	output wire [PORT_COUNT*AXIS_SYNC_DATA_WIDTH-1:0]		m_axis_sync_tx_tdata,
	output wire [PORT_COUNT*AXIS_SYNC_KEEP_WIDTH-1:0]		m_axis_sync_tx_tkeep,
	output wire [PORT_COUNT-1:0]							m_axis_sync_tx_tvalid,
	input  wire [PORT_COUNT-1:0]							m_axis_sync_tx_tready,
	output wire [PORT_COUNT-1:0]							m_axis_sync_tx_tlast,
	output wire [PORT_COUNT*AXIS_SYNC_TX_USER_WIDTH-1:0]	m_axis_sync_tx_tuser,

	input  wire [PORT_COUNT*PTP_TS_WIDTH-1:0]				s_axis_sync_tx_cpl_ts,
	input  wire [PORT_COUNT*TX_TAG_WIDTH-1:0]				s_axis_sync_tx_cpl_tag,
	input  wire [PORT_COUNT-1:0]							s_axis_sync_tx_cpl_valid,
	output wire [PORT_COUNT-1:0]							s_axis_sync_tx_cpl_ready,

	output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]				m_axis_sync_tx_cpl_ts,
	output wire [PORT_COUNT*TX_TAG_WIDTH-1:0]				m_axis_sync_tx_cpl_tag,
	output wire [PORT_COUNT-1:0]							m_axis_sync_tx_cpl_valid,
	input  wire [PORT_COUNT-1:0]							m_axis_sync_tx_cpl_ready,

	input  wire [PORT_COUNT*AXIS_SYNC_DATA_WIDTH-1:0]		s_axis_sync_rx_tdata,
	input  wire [PORT_COUNT*AXIS_SYNC_KEEP_WIDTH-1:0]		s_axis_sync_rx_tkeep,
	input  wire [PORT_COUNT-1:0]							s_axis_sync_rx_tvalid,
	output wire [PORT_COUNT-1:0]							s_axis_sync_rx_tready,
	input  wire [PORT_COUNT-1:0]							s_axis_sync_rx_tlast,
	input  wire [PORT_COUNT*AXIS_SYNC_RX_USER_WIDTH-1:0]	s_axis_sync_rx_tuser,

	output wire [PORT_COUNT*AXIS_SYNC_DATA_WIDTH-1:0]		m_axis_sync_rx_tdata,
	output wire [PORT_COUNT*AXIS_SYNC_KEEP_WIDTH-1:0]		m_axis_sync_rx_tkeep,
	output wire [PORT_COUNT-1:0]							m_axis_sync_rx_tvalid,
	input  wire [PORT_COUNT-1:0]							m_axis_sync_rx_tready,
	output wire [PORT_COUNT-1:0]							m_axis_sync_rx_tlast,
	output wire [PORT_COUNT*AXIS_SYNC_RX_USER_WIDTH-1:0]	m_axis_sync_rx_tuser,

	/*
	 * Ethernet (internal at interface module)
	 */
	input  wire [IF_COUNT*AXIS_IF_DATA_WIDTH-1:0]		s_axis_if_tx_tdata,
	input  wire [IF_COUNT*AXIS_IF_KEEP_WIDTH-1:0]		s_axis_if_tx_tkeep,
	input  wire [IF_COUNT-1:0]							s_axis_if_tx_tvalid,
	output wire [IF_COUNT-1:0]							s_axis_if_tx_tready,
	input  wire [IF_COUNT-1:0]							s_axis_if_tx_tlast,
	input  wire [IF_COUNT*AXIS_IF_TX_ID_WIDTH-1:0]		s_axis_if_tx_tid,
	input  wire [IF_COUNT*AXIS_IF_TX_DEST_WIDTH-1:0]	s_axis_if_tx_tdest,
	input  wire [IF_COUNT*AXIS_IF_TX_USER_WIDTH-1:0]	s_axis_if_tx_tuser,

	output wire [IF_COUNT*AXIS_IF_DATA_WIDTH-1:0]		m_axis_if_tx_tdata,
	output wire [IF_COUNT*AXIS_IF_KEEP_WIDTH-1:0]		m_axis_if_tx_tkeep,
	output wire [IF_COUNT-1:0]							m_axis_if_tx_tvalid,
	input  wire [IF_COUNT-1:0]							m_axis_if_tx_tready,
	output wire [IF_COUNT-1:0]							m_axis_if_tx_tlast,
	output wire [IF_COUNT*AXIS_IF_TX_ID_WIDTH-1:0]		m_axis_if_tx_tid,
	output wire [IF_COUNT*AXIS_IF_TX_DEST_WIDTH-1:0]	m_axis_if_tx_tdest,
	output wire [IF_COUNT*AXIS_IF_TX_USER_WIDTH-1:0]	m_axis_if_tx_tuser,

	input  wire [IF_COUNT*PTP_TS_WIDTH-1:0]				s_axis_if_tx_cpl_ts,
	input  wire [IF_COUNT*TX_TAG_WIDTH-1:0]				s_axis_if_tx_cpl_tag,
	input  wire [IF_COUNT-1:0]							s_axis_if_tx_cpl_valid,
	output wire [IF_COUNT-1:0]							s_axis_if_tx_cpl_ready,

	output wire [IF_COUNT*PTP_TS_WIDTH-1:0]				m_axis_if_tx_cpl_ts,
	output wire [IF_COUNT*TX_TAG_WIDTH-1:0]				m_axis_if_tx_cpl_tag,
	output wire [IF_COUNT-1:0]							m_axis_if_tx_cpl_valid,
	input  wire [IF_COUNT-1:0]							m_axis_if_tx_cpl_ready,

	input  wire [IF_COUNT*AXIS_IF_DATA_WIDTH-1:0]		s_axis_if_rx_tdata,
	input  wire [IF_COUNT*AXIS_IF_KEEP_WIDTH-1:0]		s_axis_if_rx_tkeep,
	input  wire [IF_COUNT-1:0]							s_axis_if_rx_tvalid,
	output wire [IF_COUNT-1:0]							s_axis_if_rx_tready,
	input  wire [IF_COUNT-1:0]							s_axis_if_rx_tlast,
	input  wire [IF_COUNT*AXIS_IF_RX_ID_WIDTH-1:0]		s_axis_if_rx_tid,
	input  wire [IF_COUNT*AXIS_IF_RX_DEST_WIDTH-1:0]	s_axis_if_rx_tdest,
	input  wire [IF_COUNT*AXIS_IF_RX_USER_WIDTH-1:0]	s_axis_if_rx_tuser,

	output wire [IF_COUNT*AXIS_IF_DATA_WIDTH-1:0]		m_axis_if_rx_tdata,
	output wire [IF_COUNT*AXIS_IF_KEEP_WIDTH-1:0]		m_axis_if_rx_tkeep,
	output wire [IF_COUNT-1:0]							m_axis_if_rx_tvalid,
	input  wire [IF_COUNT-1:0]							m_axis_if_rx_tready,
	output wire [IF_COUNT-1:0]							m_axis_if_rx_tlast,
	output wire [IF_COUNT*AXIS_IF_RX_ID_WIDTH-1:0]		m_axis_if_rx_tid,
	output wire [IF_COUNT*AXIS_IF_RX_DEST_WIDTH-1:0]	m_axis_if_rx_tdest,
	output wire [IF_COUNT*AXIS_IF_RX_USER_WIDTH-1:0]	m_axis_if_rx_tuser,

	/*
	 * Statistics increment output
	 */
	output wire [STAT_INC_WIDTH-1:0]					m_axis_stat_tdata,
	output wire [STAT_ID_WIDTH-1:0]						m_axis_stat_tid,
	output wire											m_axis_stat_tvalid,
	input  wire											m_axis_stat_tready,

	/*
	 * GPIO
	 */
	input  wire [APP_GPIO_IN_WIDTH-1:0]					gpio_in,
	output wire [APP_GPIO_OUT_WIDTH-1:0]				gpio_out,

	/*
	 * JTAG
	 */
	input  wire											jtag_tdi,
	output wire											jtag_tdo,
	input  wire											jtag_tms,
	input  wire											jtag_tck
);

// check configuration
initial begin
	if (APP_ID != 32'h01020304) begin
		$error("Error: Invalid APP_ID (expected 32'h01020304, got 32'h%x) (instance %m)", APP_ID);
		$finish;
	end
end
/*
 * AXI-Lite master interface (control to NIC)
 */
assign m_axil_ctrl_awaddr = 0;
assign m_axil_ctrl_awprot = 0;
assign m_axil_ctrl_awvalid = 1'b0;
assign m_axil_ctrl_wdata = 0;
assign m_axil_ctrl_wstrb = 0;
assign m_axil_ctrl_wvalid = 1'b0;
assign m_axil_ctrl_bready = 1'b1;
assign m_axil_ctrl_araddr = 0;
assign m_axil_ctrl_arprot = 0;
assign m_axil_ctrl_arvalid = 1'b0;
assign m_axil_ctrl_rready = 1'b1;

/*
 * Ethernet (direct MAC interface - lowest latency raw traffic)
 */
assign m_axis_direct_tx_tdata = s_axis_direct_tx_tdata;
assign m_axis_direct_tx_tkeep = s_axis_direct_tx_tkeep;
assign m_axis_direct_tx_tvalid = s_axis_direct_tx_tvalid;
assign s_axis_direct_tx_tready = m_axis_direct_tx_tready;
assign m_axis_direct_tx_tlast = s_axis_direct_tx_tlast;
assign m_axis_direct_tx_tuser = s_axis_direct_tx_tuser;

assign m_axis_direct_tx_cpl_ts = s_axis_direct_tx_cpl_ts;
assign m_axis_direct_tx_cpl_tag = s_axis_direct_tx_cpl_tag;
assign m_axis_direct_tx_cpl_valid = s_axis_direct_tx_cpl_valid;
assign s_axis_direct_tx_cpl_ready = m_axis_direct_tx_cpl_ready;

assign m_axis_direct_rx_tdata = s_axis_direct_rx_tdata;
assign m_axis_direct_rx_tkeep = s_axis_direct_rx_tkeep;
assign m_axis_direct_rx_tvalid = s_axis_direct_rx_tvalid;
assign s_axis_direct_rx_tready = m_axis_direct_rx_tready;
assign m_axis_direct_rx_tlast = s_axis_direct_rx_tlast;
assign m_axis_direct_rx_tuser = s_axis_direct_rx_tuser;

/*
 * Ethernet (synchronous MAC interface - low latency raw traffic)
 */

localparam 	AXIS_SYNC_TX_ID_WIDTH = 4,
			AXIS_SYNC_RX_ID_WIDTH = 4,
			AXIS_SYNC_TX_DEST_WIDTH = 4,
			AXIS_SYNC_RX_DEST_WIDTH = 4;
wire [PORT_COUNT*AXIS_SYNC_RX_ID_WIDTH-1:0] s_axis_sync_rx_tid, m_axis_sync_rx_tid;
wire [PORT_COUNT*AXIS_SYNC_RX_DEST_WIDTH-1:0] s_axis_sync_rx_tdest, m_axis_sync_rx_tdest;
wire [PORT_COUNT*AXIS_SYNC_TX_ID_WIDTH-1:0] s_axis_sync_tx_tid, m_axis_sync_tx_tid;
wire [PORT_COUNT*AXIS_SYNC_TX_DEST_WIDTH-1:0] s_axis_sync_tx_tdest, m_axis_sync_tx_tdest;

assign s_axis_sync_rx_tid = 0;
assign s_axis_sync_rx_tdest = 0;
assign s_axis_sync_tx_tid = 0;
assign s_axis_sync_tx_tdest = 0;

// `define BYPASS_AB
`ifdef BYPASS_AB

assign m_axis_sync_tx_tdata = s_axis_sync_tx_tdata;
assign m_axis_sync_tx_tkeep = s_axis_sync_tx_tkeep;
assign m_axis_sync_tx_tvalid = s_axis_sync_tx_tvalid;
assign s_axis_sync_tx_tready = m_axis_sync_tx_tready;
assign m_axis_sync_tx_tlast = s_axis_sync_tx_tlast;
assign m_axis_sync_tx_tuser = s_axis_sync_tx_tuser;

assign m_axis_sync_tx_cpl_ts = s_axis_sync_tx_cpl_ts;
assign m_axis_sync_tx_cpl_tag = s_axis_sync_tx_cpl_tag;
assign m_axis_sync_tx_cpl_valid = s_axis_sync_tx_cpl_valid;
assign s_axis_sync_tx_cpl_ready = m_axis_sync_tx_cpl_ready;

assign m_axis_sync_rx_tdata = s_axis_sync_rx_tdata;
assign m_axis_sync_rx_tkeep = s_axis_sync_rx_tkeep;
assign m_axis_sync_rx_tvalid = s_axis_sync_rx_tvalid;
assign s_axis_sync_rx_tready = m_axis_sync_rx_tready;
assign m_axis_sync_rx_tlast = s_axis_sync_rx_tlast;
assign m_axis_sync_rx_tuser = s_axis_sync_rx_tuser;

`else

assign m_axis_sync_tx_cpl_ts = s_axis_sync_tx_cpl_ts;
assign m_axis_sync_tx_cpl_tag = s_axis_sync_tx_cpl_tag;
assign m_axis_sync_tx_cpl_valid = s_axis_sync_tx_cpl_valid;
assign s_axis_sync_tx_cpl_ready = m_axis_sync_tx_cpl_ready;

app_top #(
	.COUNT					(PORT_COUNT),
	.AXIS_DATA_WIDTH		(AXIS_SYNC_DATA_WIDTH),
	.AXIS_KEEP_WIDTH		(AXIS_SYNC_KEEP_WIDTH),
	.AXIS_TX_ID_WIDTH		(AXIS_SYNC_TX_ID_WIDTH),
	.AXIS_RX_ID_WIDTH		(AXIS_SYNC_RX_ID_WIDTH),
	.AXIS_TX_DEST_WIDTH		(AXIS_SYNC_TX_DEST_WIDTH),
	.AXIS_RX_DEST_WIDTH		(AXIS_SYNC_RX_DEST_WIDTH),
	.AXIS_TX_USER_WIDTH		(AXIS_SYNC_TX_USER_WIDTH),
	.AXIS_RX_USER_WIDTH		(AXIS_SYNC_RX_USER_WIDTH),
	.AXIL_ADDR_WIDTH		(AXIL_APP_CTRL_ADDR_WIDTH),
	.AXIL_DATA_WIDTH		(AXIL_APP_CTRL_DATA_WIDTH),
	.AXIL_STRB_WIDTH		(AXIL_APP_CTRL_STRB_WIDTH)
) app_top_inst (
	.clk					(clk),
	.rst					(rst),
	
	.s_axis_rx_tdata		(s_axis_sync_rx_tdata),
	.s_axis_rx_tkeep		(s_axis_sync_rx_tkeep),
	.s_axis_rx_tvalid		(s_axis_sync_rx_tvalid),
	.s_axis_rx_tready		(s_axis_sync_rx_tready),
	.s_axis_rx_tlast		(s_axis_sync_rx_tlast),
	.s_axis_rx_tid			(s_axis_sync_rx_tid),
	.s_axis_rx_tdest		(s_axis_sync_rx_tdest),
	.s_axis_rx_tuser		(s_axis_sync_rx_tuser),

	.m_axis_rx_tdata		(m_axis_sync_rx_tdata),
	.m_axis_rx_tkeep		(m_axis_sync_rx_tkeep),
	.m_axis_rx_tvalid		(m_axis_sync_rx_tvalid),
	.m_axis_rx_tready		(m_axis_sync_rx_tready),
	.m_axis_rx_tlast		(m_axis_sync_rx_tlast),
	.m_axis_rx_tid			(m_axis_sync_rx_tid),
	.m_axis_rx_tdest		(m_axis_sync_rx_tdest),
	.m_axis_rx_tuser		(m_axis_sync_rx_tuser),

	.s_axis_tx_tdata		(s_axis_sync_tx_tdata),
	.s_axis_tx_tkeep		(s_axis_sync_tx_tkeep),
	.s_axis_tx_tvalid		(s_axis_sync_tx_tvalid),
	.s_axis_tx_tready		(s_axis_sync_tx_tready),
	.s_axis_tx_tlast		(s_axis_sync_tx_tlast),
	.s_axis_tx_tid			(s_axis_sync_tx_tid),
	.s_axis_tx_tdest		(s_axis_sync_tx_tdest),
	.s_axis_tx_tuser		(s_axis_sync_tx_tuser),

	.m_axis_tx_tdata		(m_axis_sync_tx_tdata),
	.m_axis_tx_tkeep		(m_axis_sync_tx_tkeep),
	.m_axis_tx_tvalid		(m_axis_sync_tx_tvalid),
	.m_axis_tx_tready		(m_axis_sync_tx_tready),
	.m_axis_tx_tlast		(m_axis_sync_tx_tlast),
	.m_axis_tx_tid			(m_axis_sync_tx_tid),
	.m_axis_tx_tdest		(m_axis_sync_tx_tdest),
	.m_axis_tx_tuser		(m_axis_sync_tx_tuser),

	.s_axil_awaddr			(s_axil_app_ctrl_awaddr	),
	.s_axil_awprot			(s_axil_app_ctrl_awprot	),
	.s_axil_awvalid			(s_axil_app_ctrl_awvalid),
	.s_axil_awready			(s_axil_app_ctrl_awready),
	.s_axil_wdata			(s_axil_app_ctrl_wdata	),
	.s_axil_wstrb			(s_axil_app_ctrl_wstrb	),
	.s_axil_wvalid			(s_axil_app_ctrl_wvalid	),
	.s_axil_wready			(s_axil_app_ctrl_wready	),
	.s_axil_bresp			(s_axil_app_ctrl_bresp	),
	.s_axil_bvalid			(s_axil_app_ctrl_bvalid	),
	.s_axil_bready			(s_axil_app_ctrl_bready	),
	.s_axil_araddr			(s_axil_app_ctrl_araddr	),
	.s_axil_arprot			(s_axil_app_ctrl_arprot	),
	.s_axil_arvalid			(s_axil_app_ctrl_arvalid),
	.s_axil_arready			(s_axil_app_ctrl_arready),
	.s_axil_rdata			(s_axil_app_ctrl_rdata	),
	.s_axil_rresp			(s_axil_app_ctrl_rresp	),
	.s_axil_rvalid			(s_axil_app_ctrl_rvalid	),
	.s_axil_rready			(s_axil_app_ctrl_rready	)
);

`endif
/*
 * Ethernet (internal at interface module)
 */
assign m_axis_if_tx_tdata = s_axis_if_tx_tdata;
assign m_axis_if_tx_tkeep = s_axis_if_tx_tkeep;
assign m_axis_if_tx_tvalid = s_axis_if_tx_tvalid;
assign s_axis_if_tx_tready = m_axis_if_tx_tready;
assign m_axis_if_tx_tlast = s_axis_if_tx_tlast;
assign m_axis_if_tx_tid = s_axis_if_tx_tid;
assign m_axis_if_tx_tdest = s_axis_if_tx_tdest;
assign m_axis_if_tx_tuser = s_axis_if_tx_tuser;

assign m_axis_if_tx_cpl_ts = s_axis_if_tx_cpl_ts;
assign m_axis_if_tx_cpl_tag = s_axis_if_tx_cpl_tag;
assign m_axis_if_tx_cpl_valid = s_axis_if_tx_cpl_valid;
assign s_axis_if_tx_cpl_ready = m_axis_if_tx_cpl_ready;

assign m_axis_if_rx_tdata = s_axis_if_rx_tdata;
assign m_axis_if_rx_tkeep = s_axis_if_rx_tkeep;
assign m_axis_if_rx_tvalid = s_axis_if_rx_tvalid;
assign s_axis_if_rx_tready = m_axis_if_rx_tready;
assign m_axis_if_rx_tlast = s_axis_if_rx_tlast;
assign m_axis_if_rx_tid = s_axis_if_rx_tid;
assign m_axis_if_rx_tdest = s_axis_if_rx_tdest;
assign m_axis_if_rx_tuser = s_axis_if_rx_tuser;

/*
 * DMA interface (control)
 */
assign m_axis_ctrl_dma_read_desc_dma_addr = 0;
assign m_axis_ctrl_dma_read_desc_ram_sel = 0;
assign m_axis_ctrl_dma_read_desc_ram_addr = 0;
assign m_axis_ctrl_dma_read_desc_len = 0;
assign m_axis_ctrl_dma_read_desc_tag = 0;
assign m_axis_ctrl_dma_read_desc_valid = 1'b0;
assign m_axis_ctrl_dma_write_desc_dma_addr = 0;
assign m_axis_ctrl_dma_write_desc_ram_sel = 0;
assign m_axis_ctrl_dma_write_desc_ram_addr = 0;
assign m_axis_ctrl_dma_write_desc_imm = 0;
assign m_axis_ctrl_dma_write_desc_imm_en = 0;
assign m_axis_ctrl_dma_write_desc_len = 0;
assign m_axis_ctrl_dma_write_desc_tag = 0;
assign m_axis_ctrl_dma_write_desc_valid = 1'b0;

assign ctrl_dma_ram_wr_cmd_ready = 1'b1;
assign ctrl_dma_ram_wr_done = ctrl_dma_ram_wr_cmd_valid;
assign ctrl_dma_ram_rd_cmd_ready = ctrl_dma_ram_rd_resp_ready;
assign ctrl_dma_ram_rd_resp_data = 0;
assign ctrl_dma_ram_rd_resp_valid = ctrl_dma_ram_rd_cmd_valid;

/*
 * DMA interface (data)
 */
assign m_axis_data_dma_read_desc_dma_addr = 0;
assign m_axis_data_dma_read_desc_ram_sel = 0;
assign m_axis_data_dma_read_desc_ram_addr = 0;
assign m_axis_data_dma_read_desc_len = 0;
assign m_axis_data_dma_read_desc_tag = 0;
assign m_axis_data_dma_read_desc_valid = 1'b0;
assign m_axis_data_dma_write_desc_dma_addr = 0;
assign m_axis_data_dma_write_desc_ram_sel = 0;
assign m_axis_data_dma_write_desc_ram_addr = 0;
assign m_axis_data_dma_write_desc_imm = 0;
assign m_axis_data_dma_write_desc_imm_en = 0;
assign m_axis_data_dma_write_desc_len = 0;
assign m_axis_data_dma_write_desc_tag = 0;
assign m_axis_data_dma_write_desc_valid = 1'b0;

assign data_dma_ram_wr_cmd_ready = 1'b1;
assign data_dma_ram_wr_done = data_dma_ram_wr_cmd_valid;
assign data_dma_ram_rd_cmd_ready = data_dma_ram_rd_resp_ready;
assign data_dma_ram_rd_resp_data = 0;
assign data_dma_ram_rd_resp_valid = data_dma_ram_rd_cmd_valid;

/*
 * Statistics increment output
 */
assign m_axis_stat_tdata = 0;
assign m_axis_stat_tid = 0;
assign m_axis_stat_tvalid = 1'b0;

/*
 * GPIO
 */
assign gpio_out = 0;

/*
 * JTAG
 */
assign jtag_tdo = jtag_tdi;

endmodule

`resetall
