/*
 * Created on Mon Feb 28 2022
 *
 * Copyright (c) 2022 IOA UCAS
 *
 * @Filename:     axis_parser.v
 * @Author:         Jiawei Lin
 * @Last edit:     16:00:08
 */

`resetall
`timescale 1ns/1ps
`default_nettype none

/*
 * Network packet header parser.
 */
module axis_parser #(
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

    parameter HDR_DATA_WIDTH = S_DATA_WIDTH,
    parameter HDR_KEEP_WIDTH = HDR_DATA_WIDTH/8,
    parameter HDR_ID_WIDTH = S_ID_WIDTH,
    parameter HDR_DEST_WIDTH = S_DEST_WIDTH,
    parameter HDR_USER_WIDTH = S_USER_WIDTH,

    parameter PT_NONE = 4'h0,
    parameter PT_IPV4 = 4'h1,
    parameter PT_VLV4 = 4'h2,
    parameter PT_IPV6 = 4'h3,
    parameter PT_VLV6 = 4'h4
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire [S_DATA_WIDTH-1:0]         s_axis_tdata,
    input  wire [S_KEEP_WIDTH-1:0]         s_axis_tkeep,
    input  wire                         s_axis_tvalid,
    output wire                         s_axis_tready,
    input  wire                         s_axis_tlast,
    input  wire [S_ID_WIDTH-1:0]         s_axis_tid,
    input  wire [S_DEST_WIDTH-1:0]         s_axis_tdest,    
    input  wire [S_USER_WIDTH-1:0]        s_axis_tuser,

    output wire [M_DATA_WIDTH-1:0]         m_axis_tdata,
    output wire [M_KEEP_WIDTH-1:0]         m_axis_tkeep,
    output wire                         m_axis_tvalid,
    input  wire                         m_axis_tready,
    output wire                         m_axis_tlast,
    output wire [M_ID_WIDTH-1:0]         m_axis_tid,
    output wire [M_DEST_WIDTH-1:0]         m_axis_tdest,
    output wire [M_USER_WIDTH-1:0]        m_axis_tuser,

    output wire [HDR_DATA_WIDTH-1:0]     m_axis_hdr_tdata,
    output wire [HDR_KEEP_WIDTH-1:0]     m_axis_hdr_tkeep,
    output wire                         m_axis_hdr_tvalid,
    input  wire                         m_axis_hdr_tready,
    output wire                         m_axis_hdr_tlast,
    output wire [HDR_ID_WIDTH-1:0]         m_axis_hdr_tid,
    output wire [HDR_DEST_WIDTH-1:0]     m_axis_hdr_tdest,
    output wire [HDR_USER_WIDTH-1:0]    m_axis_hdr_tuser,

    output wire [47:0]                    des_mac,
    output wire [47:0]                    src_mac,
    output wire [15:0]                    eth_type,
    output wire [31:0]                    des_ipv4,
    output wire [31:0]                    src_ipv4,
    output wire [127:0]                    des_ipv6,
    output wire [127:0]                    src_ipv6,
    output wire [15:0]                    des_port,
    output wire [15:0]                    src_port,

    output wire                         vlan_tag,
    output wire                         qinq_tag,
    output wire                         arp_tag,
    output wire                         lldp_tag,
    output wire                         ipv4_tag,
    output wire                         ipv6_tag,
    output wire                         tcp_tag,
    output wire                         udp_tag,
    output wire                         seadp_tag,

    output wire [3:0]                    pkt_type 
);

localparam CYCLE_COUNT = (68+S_KEEP_WIDTH-1)/S_KEEP_WIDTH;
localparam PTR_WIDTH = $clog2(CYCLE_COUNT+1);
localparam MAC_SIZE = 6;
localparam IPV4_WIDTH = 4;
localparam IPV6_WIDTH = 16;
localparam PORT_WIDTH = 2;

reg  [PTR_WIDTH-1:0] ptr_reg = 0, ptr_next;

reg  [47:0] des_mac_reg = 48'd0, des_mac_next;
reg  [47:0] src_mac_reg = 48'd0, src_mac_next;
reg  [15:0] eth_type_reg = 15'd0, eth_type_next;
reg  [15:0] eth_type_vlan_reg = 15'd0, eth_type_vlan_next;
reg  [31:0] des_ipv4_reg = 32'd0, des_ipv4_next;
reg  [31:0] src_ipv4_reg = 32'd0, src_ipv4_next;
reg  [127:0] des_ipv6_reg = 128'd0, des_ipv6_next;
reg  [127:0] src_ipv6_reg = 128'd0, src_ipv6_next;
reg  [15:0] des_port_reg = 16'd0, des_port_next;
reg  [15:0] src_port_reg = 16'd0, src_port_next;
reg  [3:0] pkt_type_reg = 3'h0, pkt_type_next;

reg  vlan_tag_reg = 1'b0, vlan_tag_next;    //8100
reg  qinq_tag_reg = 1'b0, qinq_tag_next;    //88a8
reg  arp_tag_reg = 1'b0,  arp_tag_next;        //0806
reg  lldp_tag_reg = 1'b0, lldp_tag_next;    //88cc
reg  ipv4_tag_reg = 1'b0, ipv4_tag_next;
reg  ipv6_tag_reg = 1'b0, ipv6_tag_next;
reg  tcp_tag_reg = 1'b0, tcp_tag_next;
reg  udp_tag_reg = 1'b0, udp_tag_next;
reg  seadp_tag_reg = 1'b0, seadp_tag_next;

assign des_mac     = des_mac_reg;
assign src_mac     = src_mac_reg;
assign eth_type     = eth_type_reg;
assign des_ipv4     = des_ipv4_reg;
assign src_ipv4     = src_ipv4_reg;
assign des_ipv6     = des_ipv6_reg;
assign src_ipv6     = src_ipv6_reg;
assign des_port     = des_port_reg;
assign src_port     = src_port_reg;
assign pkt_type = pkt_type_reg;

assign vlan_tag     = vlan_tag_reg;
assign qinq_tag     = qinq_tag_reg;
assign arp_tag     = arp_tag_reg;
assign lldp_tag     = lldp_tag_reg;
assign ipv4_tag     = ipv4_tag_reg;
assign ipv6_tag     = ipv6_tag_reg;
assign tcp_tag     = tcp_tag_reg;
assign udp_tag     = udp_tag_reg;
assign seadp_tag = seadp_tag_reg;

reg transfer_reg = 1'b0, transfer_next;

integer i;

always @(*)  begin
    ptr_next = ptr_reg;
    transfer_next = transfer_reg;

    axis_hdr_tdata_next = axis_hdr_tdata_reg;
    axis_hdr_tkeep_next = axis_hdr_tkeep_reg;
    axis_hdr_tvalid_next = axis_hdr_tvalid_reg;
    axis_hdr_tlast_next = axis_hdr_tlast_reg;
    axis_hdr_tid_next = axis_hdr_tid_reg;
    axis_hdr_tdest_next = axis_hdr_tdest_reg;
    axis_hdr_tuser_next = axis_hdr_tuser_reg;

    m_axis_tdata_next = m_axis_tdata_reg;
    m_axis_tkeep_next = m_axis_tkeep_reg;
    m_axis_tvalid_next = m_axis_tvalid_reg;
    m_axis_tlast_next = m_axis_tlast_reg;
    m_axis_tid_next = m_axis_tid_reg;
    m_axis_tdest_next = m_axis_tdest_reg;
    m_axis_tuser_next = m_axis_tuser_reg;

    if(axis_hdr_tvalid_reg && m_axis_hdr_tready) begin
        axis_hdr_tvalid_next = 1'b0;
    end

    if(m_axis_tvalid_reg && m_axis_tready) begin
        m_axis_tvalid_next = 1'b0;
    end

    vlan_tag_next = vlan_tag_reg;
    qinq_tag_next = qinq_tag_reg;
    arp_tag_next = arp_tag_reg;
    lldp_tag_next = lldp_tag_reg;
    ipv4_tag_next = ipv4_tag_reg;
    ipv6_tag_next = ipv6_tag_reg;
    tcp_tag_next = tcp_tag_reg;
    udp_tag_next = udp_tag_reg;
    seadp_tag_next = seadp_tag_reg;
    des_mac_next = des_mac_reg;
    src_mac_next = src_mac_reg;
    eth_type_next = eth_type_reg;
    eth_type_vlan_next = eth_type_vlan_reg;
    des_ipv4_next = des_ipv4_reg;
    src_ipv4_next = src_ipv4_reg;
    des_ipv6_next = des_ipv6_reg;
    src_ipv6_next = src_ipv6_reg;
    des_port_next = des_port_reg;
    src_port_next = src_port_reg;

    if (s_axis_tvalid && s_axis_tready) begin
        m_axis_tdata_next = s_axis_tdata;
        m_axis_tkeep_next = s_axis_tkeep;
        m_axis_tvalid_next = 1'b1;
        m_axis_tlast_next = s_axis_tlast;
        m_axis_tid_next = s_axis_tid;
        m_axis_tdest_next = s_axis_tdest;
        m_axis_tuser_next = s_axis_tuser;
        
        if (s_axis_tlast) begin
            ptr_next = 0;
        end else if (|(~ptr_reg)) begin
            ptr_next = ptr_reg + 1;
        end

        transfer_next = 1'b1;
        if (s_axis_tlast) begin
            transfer_next = 1'b0;
        end
        if (!transfer_reg) begin
            vlan_tag_next = 0;
            qinq_tag_next = 0;
            arp_tag_next = 0;
            lldp_tag_next = 0;
            ipv4_tag_next = 0;
            ipv6_tag_next = 0;
            tcp_tag_next = 0;
            udp_tag_next = 0;
            seadp_tag_next = 0;
            des_mac_next = 0;
            src_mac_next = 0;
            eth_type_next = 0;
            eth_type_vlan_next = 0;
            des_ipv4_next = 0;
            src_ipv4_next = 0;
            des_ipv6_next = 0;
            src_ipv6_next = 0;
            des_port_next = 0;
            src_port_next = 0;
        end

        for (i = MAC_SIZE; i > 0; i=i-1) begin
            if (ptr_reg == (MAC_SIZE-i)/S_KEEP_WIDTH) begin
                des_mac_next[(i*8-1)-:8] = s_axis_tdata[((MAC_SIZE-i)%S_KEEP_WIDTH)*8 +: 8];
            end
        end

        for (i = MAC_SIZE; i > 0; i=i-1) begin
            if (ptr_reg == (MAC_SIZE-i+6)/S_KEEP_WIDTH) begin
                src_mac_next[(i*8-1)-:8] = s_axis_tdata[((MAC_SIZE-i+6)%S_KEEP_WIDTH)*8 +: 8];
            end
        end

        if (ptr_reg == 12/S_KEEP_WIDTH) begin
            eth_type_next[15:8] = s_axis_tdata[(12%S_KEEP_WIDTH)*8 +: 8];
        end
        if (ptr_reg == 13/S_KEEP_WIDTH) begin
            eth_type_next[7:0] = s_axis_tdata[(13%S_KEEP_WIDTH)*8 +: 8];

            if (eth_type_next == 16'h0800) begin
                ipv4_tag_next = 1'b1;
            end else if (eth_type_next == 16'h86dd) begin
                ipv6_tag_next = 1'b1;
            end else if(eth_type_next == 16'h0806)begin
                arp_tag_next = 1'b1;
            end else if(eth_type_next == 16'h88cc)begin
                lldp_tag_next = 1'b1;
            end else if(eth_type_next == 16'h8100)begin
                vlan_tag_next = 1'b1;
            end else if(eth_type_next == 16'h88a8)begin
                qinq_tag_next = 1'b1;
                vlan_tag_next = 1'b1;
            end
        end
        if(vlan_tag_next||qinq_tag_next)begin
            if (ptr_reg == (16+qinq_tag_next*4)/S_KEEP_WIDTH) begin
                eth_type_vlan_next[15:8] = s_axis_tdata[((16+qinq_tag_next*4)%S_KEEP_WIDTH)*8 +: 8];
            end
            if (ptr_reg == (17+qinq_tag_next*4)/S_KEEP_WIDTH) begin
                eth_type_vlan_next[7:0] = s_axis_tdata[((17+qinq_tag_next*4)%S_KEEP_WIDTH)*8 +: 8];
                if(eth_type_vlan_next == 16'h0800)begin
                    ipv4_tag_next = 1'b1;
                end else if(eth_type_vlan_next == 16'h86dd)begin
                    ipv6_tag_next = 1'b1;
                end  else if(eth_type_vlan_next == 16'h0806)begin
                    arp_tag_next = 1'b1;
                end else if(eth_type_vlan_next == 16'h88cc)begin
                    lldp_tag_next = 1'b1;
                end
            end
        end

        if (ipv4_tag_next) begin
            if (ptr_reg == (23+(vlan_tag_next+qinq_tag_next)*4)/S_KEEP_WIDTH) begin
                // capture protocol
                if (s_axis_tdata[((23+(vlan_tag_next+qinq_tag_next)*4)%S_KEEP_WIDTH)*8 +: 8] == 8'h06) begin
                    // TCP
                    tcp_tag_next = 1'b1;
                end else if (s_axis_tdata[((23+(vlan_tag_next+qinq_tag_next)*4)%S_KEEP_WIDTH)*8 +: 8] == 8'h11) begin
                    // UDP
                    udp_tag_next = 1'b1;
                end
            end
            //parser src IP
            for(i = IPV4_WIDTH; i>0; i=i-1)begin
                if (ptr_reg == (IPV4_WIDTH-i+26+(vlan_tag_next+qinq_tag_next)*4)/S_KEEP_WIDTH) begin
                    src_ipv4_next[(i*8-1)-:8] = s_axis_tdata[((IPV4_WIDTH-i+26+(vlan_tag_next+qinq_tag_next)*4)%S_KEEP_WIDTH)*8 +: 8];
                end
            end
            //parser des IP
            for(i = IPV4_WIDTH; i>0; i=i-1)begin
                if (ptr_reg == (IPV4_WIDTH-i+30+(vlan_tag_next+qinq_tag_next)*4)/S_KEEP_WIDTH) begin
                    des_ipv4_next[(i*8-1)-:8] = s_axis_tdata[((IPV4_WIDTH-i+30+(vlan_tag_next+qinq_tag_next)*4)%S_KEEP_WIDTH)*8 +: 8];
                end
            end
            if (tcp_tag_next || udp_tag_next) begin
                // TODO IHL (skip options)
                // capture source port
                for(i = PORT_WIDTH; i>0; i=i-1)begin
                    if (ptr_reg == (PORT_WIDTH-i+34+(vlan_tag_next+qinq_tag_next)*4)/S_KEEP_WIDTH) begin
                        src_port_next[(i*8-1)-:8] = s_axis_tdata[((PORT_WIDTH-i+34+(vlan_tag_next+qinq_tag_next)*4)%S_KEEP_WIDTH)*8 +: 8];
                    end
                end
                // capture dest port
                for(i = PORT_WIDTH; i>0; i=i-1)begin
                    if (ptr_reg == (PORT_WIDTH-i+36+(vlan_tag_next+qinq_tag_next)*4)/S_KEEP_WIDTH) begin
                        des_port_next[(i*8-1)-:8] = s_axis_tdata[((PORT_WIDTH-i+36+(vlan_tag_next+qinq_tag_next)*4)%S_KEEP_WIDTH)*8 +: 8];
                    end
                end
            end
        end

        if (ipv6_tag_next) begin
            if (ptr_reg == (20+(vlan_tag_next+qinq_tag_next)*4)/S_KEEP_WIDTH) begin
                // capture protocol
                if (s_axis_tdata[((20+(vlan_tag_next+qinq_tag_next)*4)%S_KEEP_WIDTH)*8 +: 8] == 8'h06) begin
                    // TCP
                    tcp_tag_next = 1'b1;
                end else if (s_axis_tdata[((20+(vlan_tag_next+qinq_tag_next)*4)%S_KEEP_WIDTH)*8 +: 8] == 8'h11) begin
                    // UDP
                    udp_tag_next = 1'b1;
                end else if (s_axis_tdata[((20+(vlan_tag_next+qinq_tag_next)*4)%S_KEEP_WIDTH)*8 +: 8] == 8'h99) begin
                    //SEADP
                    seadp_tag_next = 1'b1;
                end

            end
            //parser src IP
            for(i = IPV6_WIDTH; i>0; i=i-1)begin
                if (ptr_reg == (IPV6_WIDTH-i+22+(vlan_tag_next+qinq_tag_next)*4)/S_KEEP_WIDTH) begin
                    src_ipv6_next[(i*8-1)-:8] = s_axis_tdata[((IPV6_WIDTH-i+22+(vlan_tag_next+qinq_tag_next)*4)%S_KEEP_WIDTH)*8 +: 8];
                end
            end
            //parser des IP
            for(i = IPV6_WIDTH; i>0; i=i-1)begin
                if (ptr_reg == (IPV6_WIDTH-i+38+(vlan_tag_next+qinq_tag_next)*4)/S_KEEP_WIDTH) begin
                    des_ipv6_next[(i*8-1)-:8] = s_axis_tdata[((IPV6_WIDTH-i+38+(vlan_tag_next+qinq_tag_next)*4)%S_KEEP_WIDTH)*8 +: 8];
                end
            end
            if (tcp_tag_next || udp_tag_next) begin
                // TODO IHL (skip options)        æ¥çæ¯å¦æå¡«åå­æ®µ
                // capture source port
                for(i = PORT_WIDTH; i>0; i=i-1)begin
                    if (ptr_reg == (PORT_WIDTH-i+54+(vlan_tag_next+qinq_tag_next)*4)/S_KEEP_WIDTH) begin
                        src_port_next[(i*8-1)-:8] = s_axis_tdata[((PORT_WIDTH-i+54+(vlan_tag_next+qinq_tag_next)*4)%S_KEEP_WIDTH)*8 +: 8];
                    end
                end
                // capture dest port
                for(i = PORT_WIDTH; i>0; i=i-1)begin
                    if (ptr_reg == (PORT_WIDTH-i+56+(vlan_tag_next+qinq_tag_next)*4)/S_KEEP_WIDTH) begin
                        des_port_next[(i*8-1)-:8] = s_axis_tdata[((PORT_WIDTH-i+56+(vlan_tag_next+qinq_tag_next)*4)%S_KEEP_WIDTH)*8 +: 8];
                    end
                end
            end
        end

        if (!transfer_reg) begin
            axis_hdr_tdata_next = s_axis_tdata;
            axis_hdr_tkeep_next = s_axis_tkeep;
            axis_hdr_tvalid_next = 1'b1;
            axis_hdr_tlast_next = 1'b1;
            axis_hdr_tid_next = s_axis_tid;
            axis_hdr_tdest_next = s_axis_tdest;
            axis_hdr_tuser_next = s_axis_tuser;
        end
    end

    pkt_type_next = PT_NONE;
    if (tcp_tag_next || udp_tag_next) begin
        if (vlan_tag_next) begin
            if (ipv4_tag_next) begin
                pkt_type_next = PT_VLV4;
            end else if (ipv6_tag_next) begin
                pkt_type_next = PT_VLV6;
            end
        end else begin
            if (ipv4_tag_next) begin
                pkt_type_next = PT_IPV4;
            end else if (ipv6_tag_next) begin
                pkt_type_next = PT_IPV6;
            end
        end
    end



end

/*
 * Output path.
 */
reg  [HDR_DATA_WIDTH-1:0]     axis_hdr_tdata_reg = {HDR_DATA_WIDTH{1'b0}}, axis_hdr_tdata_next;
reg  [HDR_KEEP_WIDTH-1:0]     axis_hdr_tkeep_reg = {HDR_KEEP_WIDTH{1'b0}}, axis_hdr_tkeep_next;
reg                          axis_hdr_tvalid_reg = 1'b0, axis_hdr_tvalid_next;
reg                          axis_hdr_tlast_reg = 1'b0, axis_hdr_tlast_next;
reg  [HDR_ID_WIDTH-1:0]     axis_hdr_tid_reg = {HDR_ID_WIDTH{1'b0}}, axis_hdr_tid_next;
reg  [HDR_DEST_WIDTH-1:0]     axis_hdr_tdest_reg = {HDR_DEST_WIDTH{1'b0}}, axis_hdr_tdest_next;
reg  [HDR_USER_WIDTH-1:0]    axis_hdr_tuser_reg = {M_USER_WIDTH{1'b0}}, axis_hdr_tuser_next;

reg  [M_DATA_WIDTH-1:0]     m_axis_tdata_reg = {M_DATA_WIDTH{1'b0}}, m_axis_tdata_next;
reg  [M_KEEP_WIDTH-1:0]     m_axis_tkeep_reg = {M_KEEP_WIDTH{1'b0}}, m_axis_tkeep_next;
reg                          m_axis_tvalid_reg = 1'b0, m_axis_tvalid_next;
reg                          m_axis_tlast_reg = 1'b0, m_axis_tlast_next;
reg  [M_ID_WIDTH-1:0]         m_axis_tid_reg = {M_ID_WIDTH{1'b0}}, m_axis_tid_next;
reg  [M_DEST_WIDTH-1:0]     m_axis_tdest_reg = {M_DEST_WIDTH{1'b0}}, m_axis_tdest_next;
reg  [M_USER_WIDTH-1:0]        m_axis_tuser_reg = {M_USER_WIDTH{1'b0}}, m_axis_tuser_next;

assign s_axis_tready = (transfer_reg || !axis_hdr_tvalid_reg) && (!m_axis_tvalid_reg || m_axis_tready);

assign m_axis_hdr_tdata = axis_hdr_tdata_reg;
assign m_axis_hdr_tkeep = axis_hdr_tkeep_reg;
assign m_axis_hdr_tvalid = axis_hdr_tvalid_reg;
assign m_axis_hdr_tlast = axis_hdr_tlast_reg;
assign m_axis_hdr_tid = axis_hdr_tid_reg;
assign m_axis_hdr_tdest = axis_hdr_tdest_reg;
assign m_axis_hdr_tuser = axis_hdr_tuser_reg;

assign m_axis_tdata = m_axis_tdata_reg;
assign m_axis_tkeep = m_axis_tkeep_reg;
assign m_axis_tvalid = m_axis_tvalid_reg;
assign m_axis_tlast = m_axis_tlast_reg;
assign m_axis_tid = m_axis_tid_reg;
assign m_axis_tdest = m_axis_tdest_reg;
assign m_axis_tuser = m_axis_tuser_reg;

always @(posedge clk) begin
    if (rst) begin
        ptr_reg <= 0;
        transfer_reg = 1'b0;

        axis_hdr_tdata_reg = {HDR_DATA_WIDTH{1'b0}};
        axis_hdr_tkeep_reg = {HDR_KEEP_WIDTH{1'b0}};
        axis_hdr_tvalid_reg = 1'b0;
        axis_hdr_tlast_reg = 1'b0;
        axis_hdr_tid_reg = {HDR_ID_WIDTH{1'b0}};
        axis_hdr_tdest_reg = {HDR_DEST_WIDTH{1'b0}};
        axis_hdr_tuser_reg = {HDR_USER_WIDTH{1'b0}};

        m_axis_tdata_reg = {M_DATA_WIDTH{1'b0}};
        m_axis_tkeep_reg = {M_KEEP_WIDTH{1'b0}};
        m_axis_tvalid_reg = 1'b0;
        m_axis_tlast_reg = 1'b0;
        m_axis_tid_reg = {M_ID_WIDTH{1'b0}};
        m_axis_tdest_reg = {M_DEST_WIDTH{1'b0}};
        m_axis_tuser_reg = {M_USER_WIDTH{1'b0}};

        vlan_tag_reg <= 0;
        qinq_tag_reg <= 0;
        arp_tag_reg <= 0;
        lldp_tag_reg <= 0;
        ipv4_tag_reg <= 0;
        ipv6_tag_reg <= 0;
        tcp_tag_reg <= 0;
        udp_tag_reg <= 0;
        seadp_tag_reg <= 0;
        des_mac_reg <= 0;
        src_mac_reg <= 0;
        eth_type_reg <= 0;
        eth_type_vlan_reg <= 0;
        des_ipv4_reg <= 0;
        src_ipv4_reg <= 0;
        des_ipv6_reg <= 0;
        src_ipv6_reg <= 0;
        des_port_reg <= 0;
        src_port_reg <= 0;
        pkt_type_reg <= 0;
    end else begin
        ptr_reg <= ptr_next;
        transfer_reg <= transfer_next;

        axis_hdr_tdata_reg <= axis_hdr_tdata_next;
        axis_hdr_tkeep_reg <= axis_hdr_tkeep_next;
        axis_hdr_tvalid_reg <= axis_hdr_tvalid_next;
        axis_hdr_tlast_reg <= axis_hdr_tlast_next;
        axis_hdr_tid_reg <= axis_hdr_tid_next;
        axis_hdr_tdest_reg <= axis_hdr_tdest_next;
        axis_hdr_tuser_reg <= axis_hdr_tuser_next;

        m_axis_tdata_reg <= m_axis_tdata_next;
        m_axis_tkeep_reg <= m_axis_tkeep_next;
        m_axis_tvalid_reg <= m_axis_tvalid_next;
        m_axis_tlast_reg <= m_axis_tlast_next;
        m_axis_tid_reg <= m_axis_tid_next;
        m_axis_tdest_reg <= m_axis_tdest_next;
        m_axis_tuser_reg <= m_axis_tuser_next;

        vlan_tag_reg <= vlan_tag_next;
        qinq_tag_reg <= qinq_tag_next;
        arp_tag_reg <= arp_tag_next;
        lldp_tag_reg <= lldp_tag_next;
        ipv4_tag_reg <= ipv4_tag_next;
        ipv6_tag_reg <= ipv6_tag_next;
        tcp_tag_reg <= tcp_tag_next;
        udp_tag_reg <= udp_tag_next;
        seadp_tag_reg <= seadp_tag_next;
        des_mac_reg <= des_mac_next;
        src_mac_reg <= src_mac_next;
        eth_type_reg <= eth_type_next;
        eth_type_vlan_reg <= eth_type_vlan_next;
        des_ipv4_reg <= des_ipv4_next;
        src_ipv4_reg <= src_ipv4_next;
        des_ipv6_reg <= des_ipv6_next;
        src_ipv6_reg <= src_ipv6_next;
        des_port_reg <= des_port_next;
        src_port_reg <= src_port_next;
        pkt_type_reg <= pkt_type_next;
    end
end

endmodule

`resetall

/*
TCP/UDP Frame (IPv4)

 Field                        Length
 Destination MAC address    6 octets
 Source MAC address            6 octets
 Ethertype (0x0800)            2 octets
 Version (4)                4 bits
 IHL (5-15)                    4 bits    Check whether there are filled fields according to the head length
 DSCP (0)                    6 bits
 ECN (0)                    2 bits
 length                        2 octets
 identification (0?)        2 octets
 flags (010)                3 bits
 fragment offset (0)        13 bits
 time to live (64?)            1 octet
 protocol (6 or 17)            1 octet
 header checksum            2 octets
 source IP                    4 octets
 destination IP                4 octets
 options                    (IHL-5)*4 octets

 source port                2 octets
 desination port            2 octets
 other fields + payload

TCP/UDP Frame (IPv6)

 Field                        Length
 Destination MAC address    6 octets
 Source MAC address            6 octets
 Ethertype (0x86dd)            2 octets
 Version (4)                4 bits
 Traffic class                8 bits
 Flow label                    20 bits
 length                        2 octets
 next header (6 or 17)        1 octet
 hop limit                    1 octet
 source IP                    16 octets
 destination IP                16 octets

 source port                2 octets
 desination port            2 octets
 other fields + payload

*/