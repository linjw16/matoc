/*
 * Created on Thu May 26 2022
 *
 * Copyright (c) 2022 IOA UCAS
 *
 * @Filename:     app_top.v
 * @Author:         Jiawei Lin
 * @Last edit:     10:22:18
 */

// Language: Verilog 2001

/* // TODO list: 
 * 1. ipv4 hdr csum error
 * 2. parser error
 */
 
/* verilator lint_off PINMISSING */
/* verilator lint_off LITENDIAN */
`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Application top interface
 */
module app_top #(
    parameter COUNT = 8,

    parameter AXIS_DATA_WIDTH           = 128,
    parameter AXIS_KEEP_WIDTH           = AXIS_DATA_WIDTH/8,
    parameter AXIS_RX_ID_WIDTH          = 8,
    parameter AXIS_RX_DEST_WIDTH        = 4,
    parameter AXIS_RX_USER_WIDTH        = 1,
    parameter AXIS_TX_ID_WIDTH          = 8,
    parameter AXIS_TX_DEST_WIDTH        = 4,
    parameter AXIS_TX_USER_WIDTH        = 1,
    parameter AXIL_ADDR_WIDTH           = 16,
    parameter AXIL_DATA_WIDTH           = 32,
    parameter AXIL_STRB_WIDTH           = AXIL_DATA_WIDTH/8,

    parameter APP_MAT_TYPE = 32'h0102_0304,    /* Vendor, Type */
    parameter APP_MAT_VER = 32'h0000_0100,    /* Major, Minor, Patch, Meta */
    parameter APP_MAT_NP = 32'h0000_0000
) (
    input  wire clk,
    input  wire rst,

    input  wire [COUNT*AXIS_DATA_WIDTH-1:0]         s_axis_rx_tdata,
    input  wire [COUNT*AXIS_KEEP_WIDTH-1:0]         s_axis_rx_tkeep,
    input  wire [COUNT-1:0]                         s_axis_rx_tvalid,
    output wire [COUNT-1:0]                         s_axis_rx_tready,
    input  wire [COUNT-1:0]                         s_axis_rx_tlast,
    input  wire [COUNT*AXIS_RX_ID_WIDTH-1:0]        s_axis_rx_tid,
    input  wire [COUNT*AXIS_RX_DEST_WIDTH-1:0]      s_axis_rx_tdest,
    input  wire [COUNT*AXIS_RX_USER_WIDTH-1:0]      s_axis_rx_tuser,

    output wire [COUNT*AXIS_DATA_WIDTH-1:0]         m_axis_rx_tdata,
    output wire [COUNT*AXIS_KEEP_WIDTH-1:0]         m_axis_rx_tkeep,
    output wire [COUNT-1:0]                         m_axis_rx_tvalid,
    input  wire [COUNT-1:0]                         m_axis_rx_tready,
    output wire [COUNT-1:0]                         m_axis_rx_tlast,
    output wire [COUNT*AXIS_RX_ID_WIDTH-1:0]        m_axis_rx_tid,
    output wire [COUNT*AXIS_RX_DEST_WIDTH-1:0]      m_axis_rx_tdest,
    output wire [COUNT*AXIS_RX_USER_WIDTH-1:0]      m_axis_rx_tuser,

    input  wire [COUNT*AXIS_DATA_WIDTH-1:0]         s_axis_tx_tdata,
    input  wire [COUNT*AXIS_KEEP_WIDTH-1:0]         s_axis_tx_tkeep,
    input  wire [COUNT-1:0]                         s_axis_tx_tvalid,
    output wire [COUNT-1:0]                         s_axis_tx_tready,
    input  wire [COUNT-1:0]                         s_axis_tx_tlast,
    input  wire [COUNT*AXIS_TX_ID_WIDTH-1:0]        s_axis_tx_tid,
    input  wire [COUNT*AXIS_TX_DEST_WIDTH-1:0]      s_axis_tx_tdest,
    input  wire [COUNT*AXIS_TX_USER_WIDTH-1:0]      s_axis_tx_tuser,

    output wire [COUNT*AXIS_DATA_WIDTH-1:0]         m_axis_tx_tdata,
    output wire [COUNT*AXIS_KEEP_WIDTH-1:0]         m_axis_tx_tkeep,
    output wire [COUNT-1:0]                         m_axis_tx_tvalid,
    input  wire [COUNT-1:0]                         m_axis_tx_tready,
    output wire [COUNT-1:0]                         m_axis_tx_tlast,
    output wire [COUNT*AXIS_TX_ID_WIDTH-1:0]        m_axis_tx_tid,
    output wire [COUNT*AXIS_TX_DEST_WIDTH-1:0]      m_axis_tx_tdest,
    output wire [COUNT*AXIS_TX_USER_WIDTH-1:0]      m_axis_tx_tuser,

    input  wire [AXIL_ADDR_WIDTH-1:0]               s_axil_awaddr,
    input  wire [2:0]                               s_axil_awprot,
    input  wire                                     s_axil_awvalid,
    output wire                                     s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]               s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0]               s_axil_wstrb,
    input  wire                                     s_axil_wvalid,
    output wire                                     s_axil_wready,
    output wire [1:0]                               s_axil_bresp,
    output wire                                     s_axil_bvalid,
    input  wire                                     s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]               s_axil_araddr,
    input  wire [2:0]                               s_axil_arprot,
    input  wire                                     s_axil_arvalid,
    output wire                                     s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]               s_axil_rdata,
    output wire [1:0]                               s_axil_rresp,
    output wire                                     s_axil_rvalid,
    input  wire                                     s_axil_rready
);

function [15:0] byte_rvs_2 (input [15:0] in_1);
    byte_rvs_2 = {in_1[7:0], in_1[15:8]};
endfunction

function [31:0] byte_rvs_4(input [31:0] in_1);
    byte_rvs_4 = {byte_rvs_2(in_1[15:0]), byte_rvs_2(in_1[31:16])};
endfunction

localparam IPv4_WIDTH = 32;
localparam CL_COUNT = COUNT>1 ? $clog2(COUNT) : 1;
localparam CL_PORT = $clog2(2*COUNT+PS_ENABLE);
localparam APP_CHNL_WIDTH = 8;
localparam DEMUX_COUNT = COUNT;
localparam CL_DEMUX_COUNT = $clog2(DEMUX_COUNT);

initial begin
    if (AXIL_DATA_WIDTH != 32) begin
        $error("ERROR: CSR data width is restricted to 32.  (instance %m)");
        $finish;
    end
    if (CL_PORT>APP_CHNL_WIDTH) begin
        $error("ERROR: CL_PORT>APP_CHNL_WIDTH.  (instance %m)");
        $finish;
    end
    if (CL_DEMUX_COUNT>APP_CHNL_WIDTH) begin
        $error("ERROR: CL_DEMUX_COUNT>APP_CHNL_WIDTH.  (instance %m)");
        $finish;
    end
end

// `define BYPASS_AT
`ifdef BYPASS_AT

assign m_axis_rx_tdata  = s_axis_rx_tdata;
assign m_axis_rx_tkeep  = s_axis_rx_tkeep;
assign m_axis_rx_tvalid = s_axis_rx_tvalid;
assign s_axis_rx_tready = m_axis_rx_tready;
assign m_axis_rx_tlast  = s_axis_rx_tlast;
assign m_axis_rx_tid    = s_axis_rx_tid;
assign m_axis_rx_tdest  = s_axis_rx_tdest;
assign m_axis_rx_tuser  = s_axis_rx_tuser;

assign m_axis_tx_tdata  = s_axis_tx_tdata;
assign m_axis_tx_tkeep  = s_axis_tx_tkeep;
assign m_axis_tx_tvalid = s_axis_tx_tvalid;
assign s_axis_tx_tready = m_axis_tx_tready;
assign m_axis_tx_tlast  = s_axis_tx_tlast;
assign m_axis_tx_tid    = s_axis_tx_tid;
assign m_axis_tx_tdest  = s_axis_tx_tdest;
assign m_axis_tx_tuser  = s_axis_tx_tuser;

assign s_axil_awready   = 1'b0;
assign s_axil_wready    = 1'b0;
assign s_axil_bresp     = 2'b00;
assign s_axil_bvalid    = 1'b0;
assign s_axil_arready   = 1'b0;
assign s_axil_rdata     = {AXIL_DATA_WIDTH{1'b0}};
assign s_axil_rresp     = 2'b00;
assign s_axil_rvalid    = 1'b0;

`else

/*
 * 2. Data width adapter
 */
localparam PT_WIDTH = 4;
localparam APP_DATA_WIDTH = 512;
localparam APP_KEEP_WIDTH = APP_DATA_WIDTH/8;
localparam KEEP_ENABLE = 1;
localparam LAST_ENABLE = 1;
localparam ID_ENABLE = 1;
localparam DEST_ENABLE = 1;
localparam USER_ENABLE = 1;

localparam DEPTH = 16384;
localparam PIPELINE_OUTPUT = 1;
localparam FRAME_FIFO = 0;
localparam USER_BAD_FRAME_VALUE = 1'b1;
localparam USER_BAD_FRAME_MASK = 1'b1;
localparam DROP_OVERSIZE_FRAME = 0;
localparam DROP_BAD_FRAME = 0;
localparam DROP_WHEN_FULL = 0;

localparam APP_ID_WIDTH = AXIS_RX_ID_WIDTH+CL_COUNT;
localparam APP_DEST_WIDTH = AXIS_RX_DEST_WIDTH+APP_CHNL_WIDTH;    /* include PKTOUT */
localparam APP_USER_WIDTH = AXIS_RX_USER_WIDTH+PT_WIDTH+IPv4_WIDTH;

wire [COUNT*AXIS_DATA_WIDTH-1:0]        axis_app_adp_tdata;
wire [COUNT*AXIS_KEEP_WIDTH-1:0]        axis_app_adp_tkeep;
wire [COUNT-1:0]                        axis_app_adp_tvalid;
wire [COUNT-1:0]                        axis_app_adp_tready;
wire [COUNT-1:0]                        axis_app_adp_tlast;
wire [COUNT*AXIS_RX_ID_WIDTH-1:0]       axis_app_adp_tid;
wire [COUNT*APP_DEST_WIDTH-1:0]         axis_app_adp_tdest;
wire [COUNT*AXIS_RX_USER_WIDTH-1:0]     axis_app_adp_tuser;

wire [COUNT*APP_DATA_WIDTH-1:0]         axis_hdr_psr_tdata;
wire [COUNT*APP_KEEP_WIDTH-1:0]         axis_hdr_psr_tkeep;
wire [COUNT-1:0]                        axis_hdr_psr_tvalid;
wire [COUNT-1:0]                        axis_hdr_psr_tready;
wire [COUNT-1:0]                        axis_hdr_psr_tlast;
wire [COUNT*AXIS_RX_ID_WIDTH-1:0]       axis_hdr_psr_tid;
wire [COUNT*AXIS_RX_DEST_WIDTH-1:0]     axis_hdr_psr_tdest;
wire [COUNT*APP_USER_WIDTH-1:0]         axis_hdr_psr_tuser;

genvar i;
generate
    for (i=0; i<COUNT; i=i+1) begin: adp_i
        wire [APP_DATA_WIDTH-1:0]       axis_rx_adp_tdata;
        wire [APP_KEEP_WIDTH-1:0]       axis_rx_adp_tkeep;
        wire                            axis_rx_adp_tvalid;
        wire                            axis_rx_adp_tready;
        wire                            axis_rx_adp_tlast;
        wire [AXIS_RX_ID_WIDTH-1:0]     axis_rx_adp_tid;
        wire [AXIS_RX_DEST_WIDTH-1:0]   axis_rx_adp_tdest;
        wire [AXIS_RX_USER_WIDTH-1:0]   axis_rx_adp_tuser;

        axis_adapter # (
            .S_DATA_WIDTH               (AXIS_DATA_WIDTH),
            .S_KEEP_ENABLE              (KEEP_ENABLE),
            .S_KEEP_WIDTH               (AXIS_KEEP_WIDTH),
            .M_DATA_WIDTH               (APP_DATA_WIDTH),
            .M_KEEP_WIDTH               (APP_KEEP_WIDTH),
            .ID_ENABLE                  (ID_ENABLE),
            .ID_WIDTH                   (AXIS_RX_ID_WIDTH),
            .DEST_ENABLE                (DEST_ENABLE),
            .DEST_WIDTH                 (AXIS_RX_DEST_WIDTH),
            .USER_ENABLE                (USER_ENABLE),
            .USER_WIDTH                 (AXIS_RX_USER_WIDTH)
        ) adapter_in (
            .clk(clk),
            .rst(rst),

            .s_axis_tdata               (s_axis_rx_tdata[i*AXIS_DATA_WIDTH+:AXIS_DATA_WIDTH]),
            .s_axis_tkeep               (s_axis_rx_tkeep[i*AXIS_KEEP_WIDTH+:AXIS_KEEP_WIDTH]),
            .s_axis_tvalid              (s_axis_rx_tvalid[i]),
            .s_axis_tready              (s_axis_rx_tready[i]),
            .s_axis_tlast               (s_axis_rx_tlast[i]),
            .s_axis_tid                 (s_axis_rx_tid[i*AXIS_RX_ID_WIDTH+:AXIS_RX_ID_WIDTH]),
            .s_axis_tdest               (s_axis_rx_tdest[i*AXIS_RX_DEST_WIDTH+:AXIS_RX_DEST_WIDTH]),
            .s_axis_tuser               (s_axis_rx_tuser[i*AXIS_RX_USER_WIDTH+:AXIS_RX_USER_WIDTH]),

            .m_axis_tdata               (axis_rx_adp_tdata),
            .m_axis_tkeep               (axis_rx_adp_tkeep),
            .m_axis_tvalid              (axis_rx_adp_tvalid),
            .m_axis_tready              (axis_rx_adp_tready),
            .m_axis_tlast               (axis_rx_adp_tlast),
            .m_axis_tid                 (axis_rx_adp_tid),
            .m_axis_tdest               (axis_rx_adp_tdest),
            .m_axis_tuser               (axis_rx_adp_tuser)
        );

        /*
        * 1. parser
        */
        localparam 
            PT_NONE = 4'h0,
            PT_IPV4 = 4'h1,
            PT_VLV4 = 4'h2,
            PT_IPV6 = 4'h3,
            PT_VLV6 = 4'h4;

        wire [APP_DATA_WIDTH-1:0]       axis_psr_tdata;
        wire [APP_KEEP_WIDTH-1:0]       axis_psr_tkeep;
        wire                            axis_psr_tvalid;
        wire                            axis_psr_tready;
        wire                            axis_psr_tlast;
        wire [AXIS_RX_ID_WIDTH-1:0]     axis_psr_tid;
        wire [AXIS_RX_DEST_WIDTH-1:0]   axis_psr_tdest;
        wire [AXIS_RX_USER_WIDTH-1:0]   axis_psr_tuser;

        wire vlan_tag, ipv4_tag, ipv6_tag, tcp_tag, udp_tag;
        wire [PT_WIDTH-1:0] pkt_type, pkt_type_dbg;
        wire [IPv4_WIDTH-1:0] des_ipv4;

        assign pkt_type_dbg = vlan_tag ? (
                (tcp_tag || udp_tag) ? (
                    ipv4_tag ? PT_VLV4 : (ipv6_tag ? PT_VLV6 :PT_NONE)
                ) : PT_NONE
            ) : (tcp_tag || udp_tag) ? (
                ipv4_tag ? PT_IPV4 : (ipv6_tag ? PT_IPV6 :PT_NONE)
            ) : PT_NONE;

        axis_parser #(
            .S_DATA_WIDTH           (APP_DATA_WIDTH),
            .S_KEEP_WIDTH           (APP_KEEP_WIDTH),
            .S_ID_WIDTH             (AXIS_RX_ID_WIDTH),
            .S_DEST_WIDTH           (AXIS_RX_DEST_WIDTH),
            .S_USER_WIDTH           (AXIS_RX_USER_WIDTH),
            .PT_NONE                (PT_NONE),
            .PT_IPV4                (PT_IPV4),
            .PT_VLV4                (PT_VLV4),
            .PT_IPV6                (PT_IPV6),
            .PT_VLV6                (PT_VLV6)
        ) axis_parser_inst (
            .clk(clk),
            .rst(rst),

            .s_axis_tdata           (axis_rx_adp_tdata),
            .s_axis_tkeep           (axis_rx_adp_tkeep),
            .s_axis_tvalid          (axis_rx_adp_tvalid),
            .s_axis_tready          (axis_rx_adp_tready),
            .s_axis_tlast           (axis_rx_adp_tlast),
            .s_axis_tid             (axis_rx_adp_tid),
            .s_axis_tdest           (axis_rx_adp_tdest),    
            .s_axis_tuser           (axis_rx_adp_tuser),

            .m_axis_tdata           (axis_psr_tdata),
            .m_axis_tkeep           (axis_psr_tkeep),
            .m_axis_tvalid          (axis_psr_tvalid),
            .m_axis_tready          (axis_psr_tready),
            .m_axis_tlast           (axis_psr_tlast),
            .m_axis_tid             (axis_psr_tid),
            .m_axis_tdest           (axis_psr_tdest),
            .m_axis_tuser           (axis_psr_tuser),

            .m_axis_hdr_tdata       (axis_hdr_psr_tdata[i*APP_DATA_WIDTH+:APP_DATA_WIDTH]),
            .m_axis_hdr_tkeep       (axis_hdr_psr_tkeep[i*APP_KEEP_WIDTH+:APP_KEEP_WIDTH]),
            .m_axis_hdr_tvalid      (axis_hdr_psr_tvalid[i]),
            .m_axis_hdr_tready      (axis_hdr_psr_tready[i]),
            .m_axis_hdr_tlast       (axis_hdr_psr_tlast[i]),
            .m_axis_hdr_tid         (axis_hdr_psr_tid[i*AXIS_RX_ID_WIDTH+:AXIS_RX_ID_WIDTH]),
            .m_axis_hdr_tdest       (axis_hdr_psr_tdest[i*AXIS_RX_DEST_WIDTH+:AXIS_RX_DEST_WIDTH]),
            .m_axis_hdr_tuser       (axis_hdr_psr_tuser[i*APP_USER_WIDTH+:AXIS_RX_USER_WIDTH]),

            .vlan_tag               (vlan_tag),
            .ipv4_tag               (ipv4_tag),
            .ipv6_tag               (ipv6_tag),
            .tcp_tag                (tcp_tag),
            .udp_tag                (udp_tag),
            .pkt_type               (pkt_type),
            .des_ipv4               (des_ipv4)
        );

        assign axis_hdr_psr_tuser[i*APP_USER_WIDTH+AXIS_RX_USER_WIDTH+:PT_WIDTH+IPv4_WIDTH] = {des_ipv4, pkt_type};

        /*
        * 3. Pkt FIFO
        */
        wire status_overflow;
        wire status_bad_frame;
        wire status_good_frame;

        wire [APP_DATA_WIDTH-1:0]       axis_fifo_tdata;
        wire [APP_KEEP_WIDTH-1:0]       axis_fifo_tkeep;
        wire                            axis_fifo_tvalid;
        wire                            axis_fifo_tready;
        wire                            axis_fifo_tlast;
        wire [AXIS_RX_ID_WIDTH-1:0]     axis_fifo_tid;
        wire [AXIS_RX_DEST_WIDTH-1:0]   axis_fifo_tdest;
        wire [AXIS_RX_USER_WIDTH-1:0]   axis_fifo_tuser;

        axis_fifo # (
            .DEPTH                      (DEPTH),
            .DATA_WIDTH                 (APP_DATA_WIDTH),
            .KEEP_WIDTH                 (APP_KEEP_WIDTH),
            .ID_WIDTH                   (AXIS_RX_ID_WIDTH),
            .DEST_WIDTH                 (AXIS_RX_DEST_WIDTH),
            .USER_WIDTH                 (AXIS_RX_USER_WIDTH),
            .KEEP_ENABLE                (1),
            .LAST_ENABLE                (1),
            .ID_ENABLE                  (1),
            .DEST_ENABLE                (1),
            .USER_ENABLE                (1), 
            .PIPELINE_OUTPUT            (2),
            .FRAME_FIFO                 (0),
            .DROP_OVERSIZE_FRAME        (0)
        ) pkt_fifo_inst (
            .clk                        (clk),
            .rst                        (rst),
            
            .s_axis_tdata               (axis_psr_tdata),
            .s_axis_tkeep               (axis_psr_tkeep),
            .s_axis_tvalid              (axis_psr_tvalid),
            .s_axis_tready              (axis_psr_tready),
            .s_axis_tlast               (axis_psr_tlast),
            .s_axis_tid                 (axis_psr_tid),
            .s_axis_tdest               (axis_psr_tdest),
            .s_axis_tuser               (axis_psr_tuser),

            .m_axis_tdata               (axis_fifo_tdata),
            .m_axis_tkeep               (axis_fifo_tkeep),
            .m_axis_tvalid              (axis_fifo_tvalid),
            .m_axis_tready              (axis_fifo_tready),
            .m_axis_tlast               (axis_fifo_tlast),
            .m_axis_tid                 (axis_fifo_tid),
            .m_axis_tdest               (axis_fifo_tdest),
            .m_axis_tuser               (axis_fifo_tuser),

            .status_overflow            (),
            .status_bad_frame           (),
            .status_good_frame          ()
        );


        /*
        * 4. Deparser
        */

        wire [APP_DATA_WIDTH-1:0]       axis_dps_tdata;
        wire [APP_KEEP_WIDTH-1:0]       axis_dps_tkeep;
        wire                            axis_dps_tvalid;
        wire                            axis_dps_tready;
        wire                            axis_dps_tlast;
        wire [APP_ID_WIDTH-1:0]         axis_dps_tid;
        wire [APP_DEST_WIDTH-1:0]       axis_dps_tdest;
        wire [AXIS_RX_USER_WIDTH-1:0]   axis_dps_tuser;

        axis_deparser # (
            .S_DATA_WIDTH           (APP_DATA_WIDTH),
            .S_KEEP_WIDTH           (APP_KEEP_WIDTH),
            .S_ID_WIDTH             (AXIS_RX_ID_WIDTH),
            .S_DEST_WIDTH           (AXIS_RX_DEST_WIDTH),
            .S_USER_WIDTH           (AXIS_RX_USER_WIDTH),
            .M_DATA_WIDTH           (APP_DATA_WIDTH),
            .M_KEEP_WIDTH           (APP_KEEP_WIDTH),
            .M_ID_WIDTH             (APP_ID_WIDTH),
            .M_DEST_WIDTH           (APP_DEST_WIDTH),
            .M_USER_WIDTH           (AXIS_RX_USER_WIDTH),

            .HDR_DATA_WIDTH         (HDR_DATA_WIDTH),
            .HDR_KEEP_WIDTH         (HDR_KEEP_WIDTH),
            .HDR_ID_WIDTH           (HDR_ID_WIDTH),
            .HDR_DEST_WIDTH         (HDR_DEST_WIDTH),
            .HDR_USER_WIDTH         (HDR_USER_WIDTH)
        ) axis_deparser_inst (
            .clk(clk),
            .rst(rst),

            .s_axis_hdr_tdata       (axis_hdr_dmx_tdata[i*HDR_DATA_WIDTH+:HDR_DATA_WIDTH]),
            .s_axis_hdr_tkeep       (axis_hdr_dmx_tkeep[i*HDR_KEEP_WIDTH+:HDR_KEEP_WIDTH]),
            .s_axis_hdr_tvalid      (axis_hdr_dmx_tvalid[i]),
            .s_axis_hdr_tready      (axis_hdr_dmx_tready[i]),
            .s_axis_hdr_tlast       (axis_hdr_dmx_tlast[i]),
            .s_axis_hdr_tid         (axis_hdr_dmx_tid[i*HDR_ID_WIDTH+:HDR_ID_WIDTH]),
            .s_axis_hdr_tdest       (axis_hdr_dmx_tdest[i*HDR_DEST_WIDTH+:HDR_DEST_WIDTH]),
            .s_axis_hdr_tuser       (axis_hdr_dmx_tuser[i*HDR_USER_WIDTH+:HDR_USER_WIDTH]),

            .s_axis_tdata           (axis_fifo_tdata),
            .s_axis_tkeep           (axis_fifo_tkeep),
            .s_axis_tvalid          (axis_fifo_tvalid),
            .s_axis_tready          (axis_fifo_tready),
            .s_axis_tlast           (axis_fifo_tlast),
            .s_axis_tid             (axis_fifo_tid),
            .s_axis_tdest           (axis_fifo_tdest),    
            .s_axis_tuser           (axis_fifo_tuser),

            .m_axis_tdata           (axis_dps_tdata),
            .m_axis_tkeep           (axis_dps_tkeep),
            .m_axis_tvalid          (axis_dps_tvalid),
            .m_axis_tready          (axis_dps_tready),
            .m_axis_tlast           (axis_dps_tlast),
            .m_axis_tid             (axis_dps_tid),
            .m_axis_tdest           (axis_dps_tdest),
            .m_axis_tuser           (axis_dps_tuser)
        );
        wire [32-1:0] dbg_ipv4_dps = byte_rvs_4(axis_dps_tdata[240 +: 32]);

        axis_adapter # (
        // axis_fifo_adapter # (
            .S_DATA_WIDTH           (APP_DATA_WIDTH),
            .S_KEEP_WIDTH           (APP_KEEP_WIDTH),
            .M_DATA_WIDTH           (AXIS_DATA_WIDTH),
            .M_KEEP_WIDTH           (AXIS_KEEP_WIDTH),
            .ID_WIDTH               (AXIS_RX_ID_WIDTH),
            .DEST_WIDTH             (APP_DEST_WIDTH),
            .USER_WIDTH             (AXIS_RX_USER_WIDTH),
            .S_KEEP_ENABLE          (KEEP_ENABLE),
            .M_KEEP_ENABLE          (KEEP_ENABLE),
            .ID_ENABLE              (ID_ENABLE),
            .DEST_ENABLE            (DEST_ENABLE),
            .USER_ENABLE            (USER_ENABLE)/*,

            .DEPTH                  (DEPTH),
            .PIPELINE_OUTPUT        (PIPELINE_OUTPUT),
            .FRAME_FIFO             (FRAME_FIFO),
            .USER_BAD_FRAME_VALUE   (USER_BAD_FRAME_VALUE),
            .USER_BAD_FRAME_MASK    (USER_BAD_FRAME_MASK),
            .DROP_OVERSIZE_FRAME    (DROP_OVERSIZE_FRAME),
            .DROP_BAD_FRAME         (DROP_BAD_FRAME),
            .DROP_WHEN_FULL         (DROP_WHEN_FULL)*/
        ) adp_out_inst (
            .clk(clk),
            .rst(rst),

            .s_axis_tdata           (axis_dps_tdata),
            .s_axis_tkeep           (axis_dps_tkeep),
            .s_axis_tvalid          (axis_dps_tvalid),
            .s_axis_tready          (axis_dps_tready),
            .s_axis_tlast           (axis_dps_tlast),
            .s_axis_tid             (axis_dps_tid),
            .s_axis_tdest           (axis_dps_tdest),
            .s_axis_tuser           (axis_dps_tuser),

            .m_axis_tdata           (axis_app_adp_tdata[i*AXIS_DATA_WIDTH+:AXIS_DATA_WIDTH]),
            .m_axis_tkeep           (axis_app_adp_tkeep[i*AXIS_KEEP_WIDTH+:AXIS_KEEP_WIDTH]),
            .m_axis_tvalid          (axis_app_adp_tvalid[i]),
            .m_axis_tready          (axis_app_adp_tready[i]),
            .m_axis_tlast           (axis_app_adp_tlast[i]),
            .m_axis_tid             (axis_app_adp_tid[i*AXIS_RX_ID_WIDTH+:AXIS_RX_ID_WIDTH]),
            .m_axis_tdest           (axis_app_adp_tdest[i*APP_DEST_WIDTH+:APP_DEST_WIDTH]),
            .m_axis_tuser           (axis_app_adp_tuser[i*AXIS_RX_USER_WIDTH+:AXIS_RX_USER_WIDTH])/*,

            .status_overflow        (status_overflow),
            .status_bad_frame       (status_bad_frame),
            .status_good_frame      (status_good_frame)*/
        );

    end
endgenerate


/*
 * 2. Rx input mux. 
 */
localparam UPDATE_TID = 1;

wire [APP_DATA_WIDTH-1:0]   axis_hdr_mux_tdata;
wire [APP_KEEP_WIDTH-1:0]   axis_hdr_mux_tkeep;
wire                        axis_hdr_mux_tvalid;
wire                        axis_hdr_mux_tready;
wire                        axis_hdr_mux_tlast;
wire [APP_ID_WIDTH-1:0]     axis_hdr_mux_tid;
wire [APP_DEST_WIDTH-1:0]   axis_hdr_mux_tdest;
wire [APP_USER_WIDTH-1:0]   axis_hdr_mux_tuser;

axis_pred_mux #(
    .S_COUNT                (COUNT),
    .DATA_WIDTH             (APP_DATA_WIDTH),
    .KEEP_ENABLE            (KEEP_ENABLE),
    .KEEP_WIDTH             (APP_KEEP_WIDTH),
    .ID_ENABLE              (ID_ENABLE),
    .S_ID_WIDTH             (AXIS_RX_ID_WIDTH),
    .M_ID_WIDTH             (APP_ID_WIDTH),    // AXIS_RX_ID_WIDTH+CL_COUNT
    .DEST_ENABLE            (DEST_ENABLE),
    .DEST_WIDTH             (AXIS_RX_DEST_WIDTH),
    .USER_ENABLE            (USER_ENABLE),
    .USER_WIDTH             (APP_USER_WIDTH),
    .LAST_ENABLE            (LAST_ENABLE),
    .UPDATE_TID             (UPDATE_TID),
    .ARB_TYPE_ROUND_ROBIN   (1),
    .ARB_LSB_HIGH_PRIORITY  (1)
) mux_inst (
    .clk                    (clk),
    .rst                    (rst),

    .s_axis_tdata           (axis_hdr_psr_tdata),
    .s_axis_tkeep           (axis_hdr_psr_tkeep),
    .s_axis_tvalid          (axis_hdr_psr_tvalid),
    .s_axis_tready          (axis_hdr_psr_tready),
    .s_axis_tlast           (axis_hdr_psr_tlast),
    .s_axis_tid             (axis_hdr_psr_tid),
    .s_axis_tdest           (axis_hdr_psr_tdest),
    .s_axis_tuser           (axis_hdr_psr_tuser),

    .m_axis_tdata           (axis_hdr_mux_tdata),
    .m_axis_tkeep           (axis_hdr_mux_tkeep),
    .m_axis_tvalid          (axis_hdr_mux_tvalid),
    .m_axis_tready          (axis_hdr_mux_tready),
    .m_axis_tlast           (axis_hdr_mux_tlast),
    .m_axis_tid             (axis_hdr_mux_tid),
    .m_axis_tdest           (axis_hdr_mux_tdest[AXIS_RX_DEST_WIDTH-1:0]),
    .m_axis_tuser           (axis_hdr_mux_tuser)
);

wire [APP_CHNL_WIDTH-1:0] tdest_out = {{APP_CHNL_WIDTH{1'b0}}, axis_hdr_mux_tid[AXIS_RX_ID_WIDTH+:CL_COUNT]}+COUNT;
assign axis_hdr_mux_tdest[AXIS_RX_DEST_WIDTH+:APP_CHNL_WIDTH] = tdest_out;

/*
 * 3. Application logic. 
 */
localparam HDR_DATA_WIDTH = 512+32;
localparam HDR_KEEP_WIDTH = HDR_DATA_WIDTH/8;
localparam HDR_ID_WIDTH = APP_ID_WIDTH;
localparam HDR_DEST_WIDTH = AXIS_RX_DEST_WIDTH+APP_CHNL_WIDTH;
localparam HDR_USER_WIDTH = AXIS_RX_USER_WIDTH;

wire [HDR_DATA_WIDTH-1:0]   axis_hdr_mat_tdata;
wire [HDR_KEEP_WIDTH-1:0]   axis_hdr_mat_tkeep;
wire                        axis_hdr_mat_tvalid;
wire                        axis_hdr_mat_tready;
wire                        axis_hdr_mat_tlast;
wire [HDR_ID_WIDTH-1:0]     axis_hdr_mat_tid;
wire [HDR_DEST_WIDTH-1:0]   axis_hdr_mat_tdest;
wire [HDR_USER_WIDTH-1:0]   axis_hdr_mat_tuser;

app_core #(
    .TCAM_DEPTH             (1024),    // TODO: debug    /* 1024 Depth TCAM Table */
    .S_DATA_WIDTH           (APP_DATA_WIDTH),
    .S_KEEP_WIDTH           (APP_KEEP_WIDTH),
    .S_ID_WIDTH             (APP_ID_WIDTH),
    .S_DEST_WIDTH           (APP_DEST_WIDTH),
    .S_USER_WIDTH           (APP_USER_WIDTH),
    .M_DATA_WIDTH           (HDR_DATA_WIDTH),
    .M_KEEP_WIDTH           (HDR_KEEP_WIDTH),
    .M_ID_WIDTH             (HDR_ID_WIDTH),
    .M_DEST_WIDTH           (HDR_DEST_WIDTH),
    .M_USER_WIDTH           (HDR_USER_WIDTH),
    .AXIL_DATA_WIDTH        (AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH        (AXIL_ADDR_WIDTH),
    .AXIL_STRB_WIDTH        (AXIL_STRB_WIDTH)
) app_core_1 (
    .clk                    (clk),
    .rst                    (rst),
    
    .s_axis_tdata           (axis_hdr_mux_tdata),
    .s_axis_tkeep           (axis_hdr_mux_tkeep),
    .s_axis_tvalid          (axis_hdr_mux_tvalid),
    .s_axis_tready          (axis_hdr_mux_tready),
    .s_axis_tlast           (axis_hdr_mux_tlast),
    .s_axis_tid             (axis_hdr_mux_tid),
    .s_axis_tdest           (axis_hdr_mux_tdest),
    .s_axis_tuser           (axis_hdr_mux_tuser),

    .m_axis_tdata           (axis_hdr_mat_tdata),
    .m_axis_tkeep           (axis_hdr_mat_tkeep),
    .m_axis_tvalid          (axis_hdr_mat_tvalid),
    .m_axis_tready          (axis_hdr_mat_tready),
    .m_axis_tlast           (axis_hdr_mat_tlast),
    .m_axis_tid             (axis_hdr_mat_tid),
    .m_axis_tdest           (axis_hdr_mat_tdest),
    .m_axis_tuser           (axis_hdr_mat_tuser),
    
    .s_axil_awaddr          (s_axil_awaddr),
    .s_axil_awprot          (s_axil_awprot),
    .s_axil_awvalid         (s_axil_awvalid),
    .s_axil_awready         (s_axil_awready),
    .s_axil_wdata           (s_axil_wdata),
    .s_axil_wstrb           (s_axil_wstrb),
    .s_axil_wvalid          (s_axil_wvalid),
    .s_axil_wready          (s_axil_wready),
    .s_axil_bresp           (s_axil_bresp),
    .s_axil_bvalid          (s_axil_bvalid),
    .s_axil_bready          (s_axil_bready),
    .s_axil_araddr          (s_axil_araddr),
    .s_axil_arprot          (s_axil_arprot),
    .s_axil_arvalid         (s_axil_arvalid),
    .s_axil_arready         (s_axil_arready),
    .s_axil_rdata           (s_axil_rdata),
    .s_axil_rresp           (s_axil_rresp),
    .s_axil_rvalid          (s_axil_rvalid),
    .s_axil_rready          (s_axil_rready)
);

/*
 * 3. Application logic. 
 */
localparam PS_ENABLE = 0;
localparam TDEST_ROUTE = 0;

wire [COUNT*HDR_DATA_WIDTH-1:0] axis_hdr_dmx_tdata;
wire [COUNT*HDR_KEEP_WIDTH-1:0] axis_hdr_dmx_tkeep;
wire [COUNT-1:0]                axis_hdr_dmx_tvalid;
wire [COUNT-1:0]                axis_hdr_dmx_tready;
wire [COUNT-1:0]                axis_hdr_dmx_tlast;
wire [COUNT*HDR_ID_WIDTH-1:0]   axis_hdr_dmx_tid;
wire [COUNT*HDR_DEST_WIDTH-1:0] axis_hdr_dmx_tdest;
wire [COUNT*HDR_USER_WIDTH-1:0] axis_hdr_dmx_tuser;

wire enable = 1'b1;
wire drop = 1'b0;
wire [CL_DEMUX_COUNT-1:0] select;

assign select = axis_hdr_mat_tid[AXIS_RX_ID_WIDTH+:CL_DEMUX_COUNT];

axis_demux # (
    .M_COUNT            (DEMUX_COUNT),
    .DATA_WIDTH         (HDR_DATA_WIDTH),
    .KEEP_ENABLE        (KEEP_ENABLE),
    .KEEP_WIDTH         (HDR_KEEP_WIDTH),
    .ID_ENABLE          (ID_ENABLE),
    .ID_WIDTH           (HDR_ID_WIDTH),
    .DEST_ENABLE        (DEST_ENABLE),
    .M_DEST_WIDTH       (HDR_DEST_WIDTH),
    .S_DEST_WIDTH       (HDR_DEST_WIDTH),
    .USER_ENABLE        (USER_ENABLE),
    .USER_WIDTH         (HDR_USER_WIDTH),
    .TDEST_ROUTE        (TDEST_ROUTE)
) dmx_inst (
    .clk(clk),
    .rst(rst),

    .s_axis_tdata       (axis_hdr_mat_tdata),
    .s_axis_tkeep       (axis_hdr_mat_tkeep),
    .s_axis_tvalid      (axis_hdr_mat_tvalid),
    .s_axis_tready      (axis_hdr_mat_tready),
    .s_axis_tlast       (axis_hdr_mat_tlast),
    .s_axis_tid         (axis_hdr_mat_tid),
    .s_axis_tdest       (axis_hdr_mat_tdest),
    .s_axis_tuser       (axis_hdr_mat_tuser),

    .m_axis_tdata       (axis_hdr_dmx_tdata),
    .m_axis_tkeep       (axis_hdr_dmx_tkeep),
    .m_axis_tvalid      (axis_hdr_dmx_tvalid),
    .m_axis_tready      (axis_hdr_dmx_tready),
    .m_axis_tlast       (axis_hdr_dmx_tlast),
    .m_axis_tid         (axis_hdr_dmx_tid),
    .m_axis_tdest       (axis_hdr_dmx_tdest),
    .m_axis_tuser       (axis_hdr_dmx_tuser),

    .enable             (enable),
    .drop               (drop),
    .select             (select)
);

/*
 * 4.1. Padding of tid, tdest, tuser. 
 */
localparam S_ID_WIDTH = AXIS_RX_ID_WIDTH>AXIS_TX_ID_WIDTH ? AXIS_RX_ID_WIDTH : AXIS_TX_ID_WIDTH;
localparam M_ID_WIDTH = S_ID_WIDTH+CL_PORT;
localparam M_DEST_WIDTH = AXIS_RX_DEST_WIDTH>AXIS_TX_DEST_WIDTH ? AXIS_RX_DEST_WIDTH : AXIS_TX_DEST_WIDTH;
localparam S_DEST_WIDTH = M_DEST_WIDTH+CL_PORT;
localparam USER_WIDTH = AXIS_RX_USER_WIDTH>AXIS_TX_USER_WIDTH ? AXIS_RX_USER_WIDTH : AXIS_TX_USER_WIDTH;

wire [COUNT*S_ID_WIDTH-1:0] axis_app_adp_tid_pad, s_axis_tx_tid_pad;
wire [COUNT*S_DEST_WIDTH-1:0] axis_app_adp_tdest_pad, s_axis_tx_tdest_pad;
wire [COUNT*USER_WIDTH-1:0] axis_app_adp_tuser_pad, s_axis_tx_tuser_pad;

wire [COUNT*M_ID_WIDTH-1:0] m_axis_tx_tid_pad, m_axis_rx_tid_pad;
wire [COUNT*M_DEST_WIDTH-1:0] m_axis_tx_tdest_pad, m_axis_rx_tdest_pad;
wire [COUNT*USER_WIDTH-1:0] m_axis_tx_tuser_pad, m_axis_rx_tuser_pad;

generate
    for (i=0; i<COUNT; i=i+1) begin: gen_pad
        wire [CL_PORT-1:0] index_tx = i;
        assign s_axis_tx_tid_pad[i*S_ID_WIDTH +: S_ID_WIDTH] = s_axis_tx_tid[i*AXIS_TX_ID_WIDTH +: AXIS_TX_ID_WIDTH];
        assign s_axis_tx_tdest_pad[i*S_DEST_WIDTH +: S_DEST_WIDTH] = {
            index_tx,
            {M_DEST_WIDTH-AXIS_TX_DEST_WIDTH{1'b0}},
            s_axis_tx_tdest[i*AXIS_TX_DEST_WIDTH +: AXIS_TX_DEST_WIDTH]
        };
        assign s_axis_tx_tuser_pad[i*USER_WIDTH +: USER_WIDTH] = s_axis_tx_tuser[i*AXIS_TX_USER_WIDTH +: AXIS_TX_USER_WIDTH];

        assign axis_app_adp_tid_pad[i*S_ID_WIDTH +: S_ID_WIDTH] = axis_app_adp_tid[i*AXIS_RX_ID_WIDTH +: AXIS_RX_ID_WIDTH];
        assign axis_app_adp_tdest_pad[i*S_DEST_WIDTH+:S_DEST_WIDTH] = {
            axis_app_adp_tdest[i*APP_DEST_WIDTH+AXIS_RX_DEST_WIDTH +: CL_PORT],
            {M_DEST_WIDTH-AXIS_RX_DEST_WIDTH{1'b0}},
            axis_app_adp_tdest[i*APP_DEST_WIDTH +: AXIS_RX_DEST_WIDTH]
        };
        assign axis_app_adp_tuser_pad[i*USER_WIDTH+:USER_WIDTH] = axis_app_adp_tuser[i*AXIS_RX_USER_WIDTH +: AXIS_RX_USER_WIDTH];

        assign m_axis_rx_tid[i*AXIS_RX_ID_WIDTH +: AXIS_RX_ID_WIDTH] = m_axis_rx_tid_pad[i*M_ID_WIDTH +: AXIS_RX_ID_WIDTH];
        assign m_axis_rx_tdest[i*AXIS_RX_DEST_WIDTH +: AXIS_RX_DEST_WIDTH] = m_axis_rx_tdest_pad[i*M_DEST_WIDTH +: AXIS_RX_DEST_WIDTH];
        assign m_axis_rx_tuser[i*AXIS_RX_USER_WIDTH +: AXIS_RX_USER_WIDTH] = m_axis_rx_tuser_pad[i*USER_WIDTH +: AXIS_RX_USER_WIDTH];

        assign m_axis_tx_tid[i*AXIS_TX_ID_WIDTH +: AXIS_TX_ID_WIDTH] = m_axis_tx_tid_pad[i*M_ID_WIDTH +: AXIS_TX_ID_WIDTH];
        assign m_axis_tx_tdest[i*AXIS_TX_DEST_WIDTH +: AXIS_TX_DEST_WIDTH] = m_axis_tx_tdest_pad[i*M_DEST_WIDTH +: AXIS_TX_DEST_WIDTH];
        assign m_axis_tx_tuser[i*AXIS_TX_USER_WIDTH +: AXIS_TX_USER_WIDTH] = m_axis_tx_tuser_pad[i*USER_WIDTH +: AXIS_TX_USER_WIDTH];
    end
endgenerate

/*
 * 4.2 Output crossbar. 
 */

localparam M_CONNECT = PS_ENABLE ? {
    {1'b0, 8'b1111_1111, 8'b0000_0000},

    {1'b1, 8'b1000_0000, 8'b0000_0000},
    {1'b1, 8'b0100_0000, 8'b0000_0000},
    {1'b1, 8'b0010_0000, 8'b0000_0000},
    {1'b1, 8'b0001_0000, 8'b0000_0000},
    {1'b1, 8'b0000_1000, 8'b0000_0000},
    {1'b1, 8'b0000_0100, 8'b0000_0000},
    {1'b1, 8'b0000_0010, 8'b0000_0000},
    {1'b1, 8'b0000_0001, 8'b0000_0000},

    {1'b1, 8'b1111_1111, 8'b1000_0000},
    {1'b1, 8'b1111_1111, 8'b0100_0000},
    {1'b1, 8'b1111_1111, 8'b0010_0000},
    {1'b1, 8'b1111_1111, 8'b0001_0000},
    {1'b1, 8'b1111_1111, 8'b0000_1000},
    {1'b1, 8'b1111_1111, 8'b0000_0100},
    {1'b1, 8'b1111_1111, 8'b0000_0010},
    {1'b1, 8'b1111_1111, 8'b0000_0001}
} : {
    {8'b1000_0000, 8'b0000_0000},
    {8'b0100_0000, 8'b0000_0000},
    {8'b0010_0000, 8'b0000_0000},
    {8'b0001_0000, 8'b0000_0000},
    {8'b0000_1000, 8'b0000_0000},
    {8'b0000_0100, 8'b0000_0000},
    {8'b0000_0010, 8'b0000_0000},
    {8'b0000_0001, 8'b0000_0000},

    {8'b1111_1111, 8'b1000_0000},
    {8'b1111_1111, 8'b0100_0000},
    {8'b1111_1111, 8'b0010_0000},
    {8'b1111_1111, 8'b0001_0000},
    {8'b1111_1111, 8'b0000_1000},
    {8'b1111_1111, 8'b0000_0100},
    {8'b1111_1111, 8'b0000_0010},
    {8'b1111_1111, 8'b0000_0001}
};
localparam REG_TYPE = 2;

axis_switch # (
    .S_COUNT                (COUNT*2+PS_ENABLE),
    .M_COUNT                (COUNT*2+PS_ENABLE),
    .DATA_WIDTH             (AXIS_DATA_WIDTH),
    .KEEP_ENABLE            (1),
    .KEEP_WIDTH             (AXIS_KEEP_WIDTH),
    .ID_ENABLE              (1),
    .S_ID_WIDTH             (S_ID_WIDTH),
    .M_ID_WIDTH             (M_ID_WIDTH),
    .S_DEST_WIDTH           (S_DEST_WIDTH),
    .M_DEST_WIDTH           (M_DEST_WIDTH),
    .USER_ENABLE            (1),
    .USER_WIDTH             (USER_WIDTH),
    .M_BASE                 (0),
    .M_TOP                  (0),
    .M_CONNECT              (M_CONNECT),
    .UPDATE_TID             (1),
    .S_REG_TYPE             (REG_TYPE),
    .M_REG_TYPE             (REG_TYPE),
    .ARB_TYPE_ROUND_ROBIN   (1),
    .ARB_LSB_HIGH_PRIORITY  (1)
) axis_switch_inst (
    .clk(clk),
    .rst(rst),

    .s_axis_tdata           ({m_axis_ps_tdata,  axis_app_adp_tdata,     s_axis_tx_tdata}),
    .s_axis_tkeep           ({m_axis_ps_tkeep,  axis_app_adp_tkeep,     s_axis_tx_tkeep}),
    .s_axis_tvalid          ({m_axis_ps_tvalid, axis_app_adp_tvalid,    s_axis_tx_tvalid}),
    .s_axis_tready          ({m_axis_ps_tready, axis_app_adp_tready,    s_axis_tx_tready}),
    .s_axis_tlast           ({m_axis_ps_tlast,  axis_app_adp_tlast,     s_axis_tx_tlast}),
    .s_axis_tid             ({m_axis_ps_tid,    axis_app_adp_tid_pad,   s_axis_tx_tid_pad}),
    .s_axis_tdest           ({m_axis_ps_tdest,  axis_app_adp_tdest_pad, s_axis_tx_tdest_pad}),
    .s_axis_tuser           ({m_axis_ps_tuser,  axis_app_adp_tuser_pad, s_axis_tx_tuser_pad}),

    .m_axis_tdata           ({s_axis_ps_tdata,  m_axis_rx_tdata,        m_axis_tx_tdata}),
    .m_axis_tkeep           ({s_axis_ps_tkeep,  m_axis_rx_tkeep,        m_axis_tx_tkeep}),
    .m_axis_tvalid          ({s_axis_ps_tvalid, m_axis_rx_tvalid,       m_axis_tx_tvalid}),
    .m_axis_tready          ({s_axis_ps_tready, m_axis_rx_tready,       m_axis_tx_tready}),
    .m_axis_tlast           ({s_axis_ps_tlast,  m_axis_rx_tlast,        m_axis_tx_tlast}),
    .m_axis_tid             ({s_axis_ps_tid,    m_axis_rx_tid_pad,      m_axis_tx_tid_pad}),
    .m_axis_tdest           ({s_axis_ps_tdest,  m_axis_rx_tdest_pad,    m_axis_tx_tdest_pad}),
    .m_axis_tuser           ({s_axis_ps_tuser,  m_axis_rx_tuser_pad,    m_axis_tx_tuser_pad})
);

/*
 * 5. PS APP
 */
wire [AXIS_DATA_WIDTH-1:0]  s_axis_ps_tdata;
wire [AXIS_KEEP_WIDTH-1:0]  s_axis_ps_tkeep;
wire                        s_axis_ps_tvalid;
wire                        s_axis_ps_tready;
wire                        s_axis_ps_tlast;
wire [S_ID_WIDTH-1:0]       s_axis_ps_tid;
wire [S_DEST_WIDTH-1:0]     s_axis_ps_tdest;
wire [USER_WIDTH-1:0]       s_axis_ps_tuser;

wire [AXIS_DATA_WIDTH-1:0]  m_axis_ps_tdata;
wire [AXIS_KEEP_WIDTH-1:0]  m_axis_ps_tkeep;
wire                        m_axis_ps_tvalid;
wire                        m_axis_ps_tready;
wire                        m_axis_ps_tlast;
wire [M_ID_WIDTH-1:0]       m_axis_ps_tid;
wire [M_DEST_WIDTH-1:0]     m_axis_ps_tdest;
wire [USER_WIDTH-1:0]       m_axis_ps_tuser;

wire [AXIL_ADDR_WIDTH-1:0]  axil_ps_awaddr;
wire [2:0]                  axil_ps_awprot;
wire                        axil_ps_awvalid;
wire                        axil_ps_awready;
wire [AXIL_DATA_WIDTH-1:0]  axil_ps_wdata;
wire [AXIL_STRB_WIDTH-1:0]  axil_ps_wstrb;
wire                        axil_ps_wvalid;
wire                        axil_ps_wready;
wire [1:0]                  axil_ps_bresp;
wire                        axil_ps_bvalid;
wire                        axil_ps_bready;
wire [AXIL_ADDR_WIDTH-1:0]  axil_ps_araddr;
wire [2:0]                  axil_ps_arprot;
wire                        axil_ps_arvalid;
wire                        axil_ps_arready;
wire [AXIL_DATA_WIDTH-1:0]  axil_ps_rdata;
wire [1:0]                  axil_ps_rresp;
wire                        axil_ps_rvalid;
wire                        axil_ps_rready;

assign axil_ps_awready = 0;
assign axil_ps_wready = 0;
assign axil_ps_bresp = 0;
assign axil_ps_bvalid = 0;
assign axil_ps_arready = 0;
assign axil_ps_rdata = 0;
assign axil_ps_rresp = 0;
assign axil_ps_rvalid = 0;

app_ps #(
    .AXIS_DATA_WIDTH        (AXIS_DATA_WIDTH),
    .AXIS_KEEP_WIDTH        (AXIS_KEEP_WIDTH),
    .AXIS_ID_WIDTH          (M_ID_WIDTH),
    .AXIS_DEST_WIDTH        (S_DEST_WIDTH),
    .AXIS_USER_WIDTH        (USER_WIDTH),

    .AXIS_KEEP_ENABLE       (KEEP_ENABLE),
    .AXIS_LAST_ENABLE       (LAST_ENABLE),
    .AXIS_ID_ENABLE         (ID_ENABLE),
    .AXIS_DEST_ENABLE       (DEST_ENABLE),
    .AXIS_USER_ENABLE       (USER_ENABLE),

    .AXIL_ADDR_WIDTH        (AXIL_ADDR_WIDTH),
    .AXIL_DATA_WIDTH        (AXIL_DATA_WIDTH),
    .AXIL_STRB_WIDTH        (AXIL_STRB_WIDTH),

    .ENABLE                 (PS_ENABLE)
) app_ps_inst (
    .clk(clk),
    .rst(rst),

    .s_axis_tdata           (s_axis_ps_tdata),
    .s_axis_tkeep           (s_axis_ps_tkeep),
    .s_axis_tvalid          (s_axis_ps_tvalid),
    .s_axis_tready          (s_axis_ps_tready),
    .s_axis_tlast           (s_axis_ps_tlast),
    .s_axis_tid             (s_axis_ps_tid),
    .s_axis_tdest           (s_axis_ps_tdest),
    .s_axis_tuser           (s_axis_ps_tuser),

    .m_axis_tdata           (m_axis_ps_tdata),
    .m_axis_tkeep           (m_axis_ps_tkeep),
    .m_axis_tvalid          (m_axis_ps_tvalid),
    .m_axis_tready          (m_axis_ps_tready),
    .m_axis_tlast           (m_axis_ps_tlast),
    .m_axis_tid             (m_axis_ps_tid),
    .m_axis_tdest           (m_axis_ps_tdest),
    .m_axis_tuser           (m_axis_ps_tuser),

    .s_axil_awaddr          (axil_ps_awaddr),
    .s_axil_awprot          (axil_ps_awprot),
    .s_axil_awvalid         (axil_ps_awvalid),
    .s_axil_awready         (axil_ps_awready),
    .s_axil_wdata           (axil_ps_wdata),
    .s_axil_wstrb           (axil_ps_wstrb),
    .s_axil_wvalid          (axil_ps_wvalid),
    .s_axil_wready          (axil_ps_wready),
    .s_axil_bresp           (axil_ps_bresp),
    .s_axil_bvalid          (axil_ps_bvalid),
    .s_axil_bready          (axil_ps_bready),
    .s_axil_araddr          (axil_ps_araddr),
    .s_axil_arprot          (axil_ps_arprot),
    .s_axil_arvalid         (axil_ps_arvalid),
    .s_axil_arready         (axil_ps_arready),
    .s_axil_rdata           (axil_ps_rdata),
    .s_axil_rresp           (axil_ps_rresp),
    .s_axil_rvalid          (axil_ps_rvalid),
    .s_axil_rready          (axil_ps_rready)
);

wire [32-1:0] dbg_ipv4_adp = byte_rvs_4({axis_app_adp_tdata[112 +: 16],axis_app_adp_tdata[0+:16]});
wire [32-1:0] dbg_ipv4_mat = byte_rvs_4(axis_hdr_mat_tdata[240 +: 32]);

`endif

endmodule

`resetall