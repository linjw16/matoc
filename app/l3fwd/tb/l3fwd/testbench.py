"""

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

"""

import logging
import os
import sys

import scapy.utils
from scapy.layers.l2 import Ether
from scapy.layers.inet import IP, UDP

import cocotb_test.simulator
import pytest

import cocotb
from cocotb.log import SimLog
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

from cocotbext.axi import AxiStreamBus
from cocotbext.eth import EthMac
from cocotbext.pcie.core import RootComplex
from cocotbext.pcie.xilinx.us import UltraScalePlusPcieDevice

try:
	import libmat
except ImportError:
	# attempt import from current directory
	sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
	try:
		import libmat
	finally:
		del sys.path[0]
try:
	import mqnic
except ImportError:
	# attempt import from current directory
	sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
	try:
		import mqnic
	finally:
		del sys.path[0]


class TB(object):
	def __init__(self, dut):
		self.dut = dut

		self.log = SimLog("cocotb.tb")
		self.log.setLevel(logging.DEBUG)

		# app_mat
		mat = dut.core_pcie_inst.core_inst.app.app_block_inst.app_top_inst.app_core_1.app_mat_1
		self.mat = mat
		self.TCAM_DEPTH			= mat.TCAM_DEPTH.value
		self.TCAM_WR_WIDTH		= mat.TCAM_WR_WIDTH.value
		self.BAR_TCAM_WR_DATA	= mat.BAR_TCAM_WR_DATA.value
		self.BAR_TCAM_WR_KEEP	= mat.BAR_TCAM_WR_KEEP.value
		self.BAR_ACTN_WR_DATA	= mat.BAR_ACTN_WR_DATA.value
		self.BAR_CSR			= mat.BAR_CSR.value
		self.CSR_TCAM_OFFSET	= mat.CSR_TCAM_OFFSET.value
		self.CSR_ACTN_OFFSET	= mat.CSR_ACTN_OFFSET.value
		self.CSR_TCAM_WR		= mat.CSR_TCAM_WR.value
		self.CSR_TCAM_RD		= mat.CSR_TCAM_RD.value
		self.CSR_ACTN_WR		= mat.CSR_ACTN_WR.value
		self.CSR_ACTN_RD		= mat.CSR_ACTN_RD.value
		self.IF_COUNT = dut.IF_COUNT.value
		self.PORTS_PER_IF = dut.PORTS_PER_IF.value
		self.PORT_COUNT = dut.PORT_COUNT.value
		self.tcam_dict = {}
		self.tcam_list = [set()]*self.TCAM_DEPTH
		self.act_table = [0]*self.TCAM_DEPTH
		
		# PCIe
		self.rc = RootComplex()

		self.rc.max_payload_size = 0x1  # 256 bytes
		self.rc.max_read_request_size = 0x2  # 512 bytes

		self.dev = UltraScalePlusPcieDevice(
			# configuration options
			pcie_generation=3,
			# pcie_link_width=16,
			user_clk_frequency=250e6,
			alignment="dword",
			cq_cc_straddle=False,
			rq_rc_straddle=False,
			rc_4tlp_straddle=False,
			enable_pf1=False,
			enable_client_tag=True,
			enable_extended_tag=True,
			enable_parity=False,
			enable_rx_msg_interface=False,
			enable_sriov=False,
			enable_extended_configuration=False,

			enable_pf0_msi=True,
			enable_pf1_msi=False,

			# signals
			# Clock and Reset Interface
			user_clk=dut.clk,
			user_reset=dut.rst,
			# user_lnk_up
			# sys_clk
			# sys_clk_gt
			# sys_reset
			# phy_rdy_out

			# Requester reQuest Interface
			rq_bus=AxiStreamBus.from_prefix(dut, "m_axis_rq"),
			pcie_rq_seq_num0=dut.s_axis_rq_seq_num_0,
			pcie_rq_seq_num_vld0=dut.s_axis_rq_seq_num_valid_0,
			pcie_rq_seq_num1=dut.s_axis_rq_seq_num_1,
			pcie_rq_seq_num_vld1=dut.s_axis_rq_seq_num_valid_1,
			# pcie_rq_tag0
			# pcie_rq_tag1
			# pcie_rq_tag_av
			# pcie_rq_tag_vld0
			# pcie_rq_tag_vld1

			# Requester Completion Interface
			rc_bus=AxiStreamBus.from_prefix(dut, "s_axis_rc"),

			# Completer reQuest Interface
			cq_bus=AxiStreamBus.from_prefix(dut, "s_axis_cq"),
			# pcie_cq_np_req
			# pcie_cq_np_req_count

			# Completer Completion Interface
			cc_bus=AxiStreamBus.from_prefix(dut, "m_axis_cc"),

			# Transmit Flow Control Interface
			# pcie_tfc_nph_av=dut.pcie_tfc_nph_av,
			# pcie_tfc_npd_av=dut.pcie_tfc_npd_av,

			# Configuration Management Interface
			cfg_mgmt_addr=dut.cfg_mgmt_addr,
			cfg_mgmt_function_number=dut.cfg_mgmt_function_number,
			cfg_mgmt_write=dut.cfg_mgmt_write,
			cfg_mgmt_write_data=dut.cfg_mgmt_write_data,
			cfg_mgmt_byte_enable=dut.cfg_mgmt_byte_enable,
			cfg_mgmt_read=dut.cfg_mgmt_read,
			cfg_mgmt_read_data=dut.cfg_mgmt_read_data,
			cfg_mgmt_read_write_done=dut.cfg_mgmt_read_write_done,
			# cfg_mgmt_debug_access

			# Configuration Status Interface
			# cfg_phy_link_down
			# cfg_phy_link_status
			# cfg_negotiated_width
			# cfg_current_speed
			cfg_max_payload=dut.cfg_max_payload,
			cfg_max_read_req=dut.cfg_max_read_req,
			# cfg_function_status
			# cfg_vf_status
			# cfg_function_power_state
			# cfg_vf_power_state
			# cfg_link_power_state
			# cfg_err_cor_out
			# cfg_err_nonfatal_out
			# cfg_err_fatal_out
			# cfg_local_error_out
			# cfg_local_error_valid
			# cfg_rx_pm_state
			# cfg_tx_pm_state
			# cfg_ltssm_state
			# cfg_rcb_status
			# cfg_obff_enable
			# cfg_pl_status_change
			# cfg_tph_requester_enable
			# cfg_tph_st_mode
			# cfg_vf_tph_requester_enable
			# cfg_vf_tph_st_mode

			# Configuration Received Message Interface
			# cfg_msg_received
			# cfg_msg_received_data
			# cfg_msg_received_type

			# Configuration Transmit Message Interface
			# cfg_msg_transmit
			# cfg_msg_transmit_type
			# cfg_msg_transmit_data
			# cfg_msg_transmit_done

			# Configuration Flow Control Interface
			cfg_fc_ph=dut.cfg_fc_ph,
			cfg_fc_pd=dut.cfg_fc_pd,
			cfg_fc_nph=dut.cfg_fc_nph,
			cfg_fc_npd=dut.cfg_fc_npd,
			cfg_fc_cplh=dut.cfg_fc_cplh,
			cfg_fc_cpld=dut.cfg_fc_cpld,
			cfg_fc_sel=dut.cfg_fc_sel,

			# Configuration Control Interface
			# cfg_hot_reset_in
			# cfg_hot_reset_out
			# cfg_config_space_enable
			# cfg_dsn
			# cfg_bus_number
			# cfg_ds_port_number
			# cfg_ds_bus_number
			# cfg_ds_device_number
			# cfg_ds_function_number
			# cfg_power_state_change_ack
			# cfg_power_state_change_interrupt
			cfg_err_cor_in=dut.status_error_cor,
			cfg_err_uncor_in=dut.status_error_uncor,
			# cfg_flr_in_process
			# cfg_flr_done
			# cfg_vf_flr_in_process
			# cfg_vf_flr_func_num
			# cfg_vf_flr_done
			# cfg_pm_aspm_l1_entry_reject
			# cfg_pm_aspm_tx_l0s_entry_disable
			# cfg_req_pm_transition_l23_ready
			# cfg_link_training_enable

			# Configuration Interrupt Controller Interface
			# cfg_interrupt_int
			# cfg_interrupt_sent
			# cfg_interrupt_pending
			cfg_interrupt_msi_enable=dut.cfg_interrupt_msi_enable,
			cfg_interrupt_msi_mmenable=dut.cfg_interrupt_msi_mmenable,
			cfg_interrupt_msi_mask_update=dut.cfg_interrupt_msi_mask_update,
			cfg_interrupt_msi_data=dut.cfg_interrupt_msi_data,
			# cfg_interrupt_msi_select=dut.cfg_interrupt_msi_select,
			cfg_interrupt_msi_int=dut.cfg_interrupt_msi_int,
			cfg_interrupt_msi_pending_status=dut.cfg_interrupt_msi_pending_status,
			cfg_interrupt_msi_pending_status_data_enable=dut.cfg_interrupt_msi_pending_status_data_enable,
			# cfg_interrupt_msi_pending_status_function_num=dut.cfg_interrupt_msi_pending_status_function_num,
			cfg_interrupt_msi_sent=dut.cfg_interrupt_msi_sent,
			cfg_interrupt_msi_fail=dut.cfg_interrupt_msi_fail,
			# cfg_interrupt_msix_enable
			# cfg_interrupt_msix_mask
			# cfg_interrupt_msix_vf_enable
			# cfg_interrupt_msix_vf_mask
			# cfg_interrupt_msix_address
			# cfg_interrupt_msix_data
			# cfg_interrupt_msix_int
			# cfg_interrupt_msix_vec_pending
			# cfg_interrupt_msix_vec_pending_status
			cfg_interrupt_msi_attr=dut.cfg_interrupt_msi_attr,
			cfg_interrupt_msi_tph_present=dut.cfg_interrupt_msi_tph_present,
			cfg_interrupt_msi_tph_type=dut.cfg_interrupt_msi_tph_type,
			# cfg_interrupt_msi_tph_st_tag=dut.cfg_interrupt_msi_tph_st_tag,
			# cfg_interrupt_msi_function_number=dut.cfg_interrupt_msi_function_number,

			# Configuration Extend Interface
			# cfg_ext_read_received
			# cfg_ext_write_received
			# cfg_ext_register_number
			# cfg_ext_function_number
			# cfg_ext_write_data
			# cfg_ext_write_byte_enable
			# cfg_ext_read_data
			# cfg_ext_read_data_valid
		)

		# self.dev.log.setLevel(logging.DEBUG)

		self.rc.make_port().connect(self.dev)

		self.driver = mqnic.Driver()

		self.dev.functions[0].msi_cap.msi_multiple_message_capable = 5

		self.dev.functions[0].configure_bar(0, 2**len(dut.core_pcie_inst.axil_ctrl_araddr), ext=True, prefetch=True)
		if hasattr(dut.core_pcie_inst, 'pcie_app_ctrl'):
			self.dev.functions[0].configure_bar(2, 2**len(dut.core_pcie_inst.axil_app_ctrl_araddr), ext=True, prefetch=True)

		# Ethernet
		self.port_mac = []

		eth_int_if_width = len(dut.core_pcie_inst.core_inst.m_axis_tx_tdata) / \
			len(dut.core_pcie_inst.core_inst.m_axis_tx_tvalid)
		eth_clock_period = 6.4
		eth_speed = 10e9

		if eth_int_if_width == 64:
			# 10G
			eth_clock_period = 6.4
			eth_speed = 10e9
		elif eth_int_if_width == 128:
			# 25G
			eth_clock_period = 2.56
			eth_speed = 25e9
		elif eth_int_if_width == 512:
			# 100G
			eth_clock_period = 3.102
			eth_speed = 100e9

		for iface in dut.core_pcie_inst.core_inst.iface:
			for k in range(len(iface.port)):
				cocotb.start_soon(Clock(iface.port[k].port_rx_clk, eth_clock_period, units="ns").start())
				cocotb.start_soon(Clock(iface.port[k].port_tx_clk, eth_clock_period, units="ns").start())

				iface.port[k].port_rx_rst.setimmediatevalue(0)
				iface.port[k].port_tx_rst.setimmediatevalue(0)

				if (dut.PTP_TS_ENABLE.value):
					mac = EthMac(
						tx_clk=iface.port[k].port_tx_clk,
						tx_rst=iface.port[k].port_tx_rst,
						tx_bus=AxiStreamBus.from_prefix(
							iface.interface_inst.port[k].port_inst.port_tx_inst, "m_axis_tx"),
						tx_ptp_time=iface.port[k].port_tx_ptp_ts_96,
						tx_ptp_ts=iface.interface_inst.port[k].port_inst.port_tx_inst.s_axis_tx_cpl_ts,
						tx_ptp_ts_tag=iface.interface_inst.port[k].port_inst.port_tx_inst.s_axis_tx_cpl_tag,
						tx_ptp_ts_valid=iface.interface_inst.port[k].port_inst.port_tx_inst.s_axis_tx_cpl_valid,
						rx_clk=iface.port[k].port_rx_clk,
						rx_rst=iface.port[k].port_rx_rst,
						rx_bus=AxiStreamBus.from_prefix(
							iface.interface_inst.port[k].port_inst.port_rx_inst, "s_axis_rx"),
						rx_ptp_time=iface.port[k].port_rx_ptp_ts_96,
						ifg=12, speed=eth_speed
					)
				else:
					mac = EthMac(
						tx_clk=iface.port[k].port_tx_clk,
						tx_rst=iface.port[k].port_tx_rst,
						tx_bus=AxiStreamBus.from_prefix(
							iface.interface_inst.port[k].port_inst.port_tx_inst, "m_axis_tx"),
						rx_clk=iface.port[k].port_rx_clk,
						rx_rst=iface.port[k].port_rx_rst,
						rx_bus=AxiStreamBus.from_prefix(
							iface.interface_inst.port[k].port_inst.port_rx_inst, "s_axis_rx"),
					)

				self.port_mac.append(mac)

		dut.eth_tx_status.setimmediatevalue(2**len(dut.core_pcie_inst.core_inst.m_axis_tx_tvalid)-1)
		dut.eth_rx_status.setimmediatevalue(2**len(dut.core_pcie_inst.core_inst.m_axis_tx_tvalid)-1)

		dut.ctrl_reg_wr_wait.setimmediatevalue(0)
		dut.ctrl_reg_wr_ack.setimmediatevalue(0)
		dut.ctrl_reg_rd_data.setimmediatevalue(0)
		dut.ctrl_reg_rd_wait.setimmediatevalue(0)
		dut.ctrl_reg_rd_ack.setimmediatevalue(0)

		cocotb.start_soon(Clock(dut.ptp_clk, 6.4, units="ns").start())
		dut.ptp_rst.setimmediatevalue(0)
		cocotb.start_soon(Clock(dut.ptp_sample_clk, 8, units="ns").start())

		dut.s_axis_stat_tdata.setimmediatevalue(0)
		dut.s_axis_stat_tid.setimmediatevalue(0)
		dut.s_axis_stat_tvalid.setimmediatevalue(0)

		self.loopback_enable = False
		cocotb.start_soon(self._run_loopback())

	async def init(self):

		for mac in self.port_mac:
			mac.rx.reset.setimmediatevalue(0)
			mac.tx.reset.setimmediatevalue(0)

		self.dut.ptp_rst.setimmediatevalue(0)

		await RisingEdge(self.dut.clk)
		await RisingEdge(self.dut.clk)

		for mac in self.port_mac:
			mac.rx.reset.setimmediatevalue(1)
			mac.tx.reset.setimmediatevalue(1)

		self.dut.ptp_rst.setimmediatevalue(1)

		await FallingEdge(self.dut.rst)
		await Timer(100, 'ns')

		await RisingEdge(self.dut.clk)
		await RisingEdge(self.dut.clk)

		for mac in self.port_mac:
			mac.rx.reset.setimmediatevalue(0)
			mac.tx.reset.setimmediatevalue(0)

		self.dut.ptp_rst.setimmediatevalue(0)

		await self.rc.enumerate(enable_bus_mastering=True, configure_msi=True)

	async def _run_loopback(self):
		while True:
			await RisingEdge(self.dut.clk)

			if self.loopback_enable:
				for mac in self.port_mac:
					if not mac.tx.empty():
						await mac.rx.send(await mac.tx.recv())

	def _model_wr(self, wr_data=0, wr_keep=0, wr_addr=0, idx=0):
		while(wr_keep & (1 << idx)):
			idx = idx+1
		if(idx == self.TCAM_WR_WIDTH):
			set_1 = self.tcam_dict.get(wr_data, set())
			set_1.add(wr_addr)
			self.tcam_dict[wr_data] = set_1
			set_2 = self.tcam_list[wr_addr]
			set_2.add(wr_data)
			self.tcam_list[wr_addr] = set_2
		else:
			self._model_wr(wr_data, wr_keep, wr_addr, idx+1)
			self._model_wr(wr_data ^ (1 << idx), wr_keep, wr_addr, idx+1)

	async def tcam_wr(self, tcam_data=([0]*8), tcam_keep=([(1 << 32)-1]*8), tcam_addr=0x0001):
		for i in range(8):
			set_2 = self.tcam_list[tcam_addr+i]
			for sk in set_2:
				set_1 = self.tcam_dict[sk].discard(tcam_addr+i)
			self.tcam_list[tcam_addr+i] = set()
			self._model_wr(tcam_data[i], tcam_keep[i], tcam_addr+i)
			self.log.debug("addr = %d; data = %X|%X" %
						   (tcam_addr+i, tcam_data[i], tcam_keep[i]))

			await self.driver.app_hw_regs.write_dword(self.BAR_TCAM_WR_DATA+i*0x4, tcam_data[i])
			await self.driver.app_hw_regs.write_dword(self.BAR_TCAM_WR_KEEP+i*0x4, tcam_keep[i])

		# TODO: mask
		csr_op_code = (1 << self.CSR_TCAM_WR) | (tcam_addr << self.CSR_TCAM_OFFSET % 0x10000)
		await self.driver.app_hw_regs.write_dword(self.BAR_CSR, csr_op_code)

	async def actn_wr(self, actn_data=0x0001, actn_addr=0x0001):
		for i in range(4):
			wr_data = actn_data >> i*32 & 0xFFFF_FFFF
			await self.driver.app_hw_regs.write_dword(self.BAR_ACTN_WR_DATA+i*0x4, wr_data)

		# TODO: mask
		csr_op_code = (1 << self.CSR_ACTN_WR) | (actn_addr << self.CSR_ACTN_OFFSET % 0x10000)
		await self.driver.app_hw_regs.write_dword(self.BAR_CSR, csr_op_code)

	async def send(pkt_sent,itf=0, prt=0):
		await self.driver.interfaces[itf].start_xmit(pkt_sent, prt % len(self.driver.interfaces[0].ports))

	async def recv(itf=0):
		return await self.driver.interfaces[itf].recv()

@cocotb.test()
async def run_test_nic(dut):

	tb = TB(dut)
	DEBUG = 0
	if not DEBUG:
		await tb.init()
		tb.log.info("Init driver")
		await tb.driver.init_pcie_dev(tb.rc, tb.dev.functions[0].pcie_id)
		for interface in tb.driver.interfaces:
			await interface.open()
		# enable queues
		tb.log.info("Enable queues")
		for interface in tb.driver.interfaces:
			await interface.sched_blocks[0].schedulers[0].rb.write_dword(mqnic.MQNIC_RB_SCHED_RR_REG_CTRL, 0x00000001)
			for k in range(interface.tx_queue_count):
				await interface.sched_blocks[0].schedulers[0].hw_regs.write_dword(4*k, 0x00000003)
		# wait for all writes to complete
		await tb.driver.hw_regs.read_dword(0)
		tb.log.info("Init complete")
		
		tb.log.info("Send and receive single packet")
		for i,interface in enumerate(tb.driver.interfaces):
			data = bytearray([(x+i) % 256 for x in range(1024)])
			await interface.start_xmit(data, 0)
			pkt = await tb.port_mac[interface.index*interface.port_count].tx.recv()
			tb.log.info("Packet: %s", pkt)
			await tb.port_mac[interface.index*interface.port_count].rx.send(pkt)
			pkt = await interface.recv()
			tb.log.info("Packet: %s", pkt)
			assert pkt.rx_checksum == ~scapy.utils.checksum(bytes(pkt.data[14:])) & 0xffff
		tb.log.info("RX and TX checksum tests")
		payload = bytes([x % 256 for x in range(256)])
		eth = Ether(src='5A:51:52:53:54:55', dst='DA:D1:D2:D3:D4:D5')
		ip = IP(src='192.168.1.100', dst='192.168.1.101')
		udp = UDP(sport=1, dport=2)
		test_pkt = eth / ip / udp / payload
		test_pkt2 = test_pkt.copy()
		test_pkt2[UDP].chksum = scapy.utils.checksum(bytes(test_pkt2[UDP]))
		await tb.driver.interfaces[0].start_xmit(test_pkt2.build(), 0, 34, 6)
		pkt = await tb.port_mac[0].tx.recv()
		tb.log.info("Packet: %s", pkt)
		await tb.port_mac[0].rx.send(pkt)
		pkt = await tb.driver.interfaces[0].recv()
		tb.log.info("Packet: %s", pkt)
		assert pkt.rx_checksum == ~scapy.utils.checksum(bytes(pkt.data[14:])) & 0xffff
		# assert Ether(pkt.data).build() == test_pkt.build()

	## Application: l3fwd
	dmac_dict = {}
	smac_dict = {}
	vlan_dict = {}
	chnl_dict = {}
	search_keys = [0xC0A80101+i for i in range(tb.TCAM_DEPTH)]
	for i in range(tb.TCAM_DEPTH):
		dmac_1 = (0xD1_D1_D2_D3_D4_D5 + (i << 40)) % (1 << 48)
		smac_1 = (0x51_51_52_53_54_55 + (i << 40)) % (1 << 48)
		vlan_1 = (0xF001+i) % 0x10000
		chnl_1 = (0x1+i) % tb.PORT_COUNT
		dmac_dict[search_keys[i]] = dmac_1
		smac_dict[search_keys[i]] = smac_1
		vlan_dict[search_keys[i]] = vlan_1
		chnl_dict[search_keys[i]] = chnl_1
		actn_code_1 = libmat.f_set_actn_code(d_mac=dmac_1, s_mac=smac_1, vl_data=vlan_1, tdest=0, tid=chnl_1,
										 vl_op=0b01, tdest_en=True, cks_en=True, d_mac_en=True, s_mac_en=True)
		if not DEBUG:
			await tb.actn_wr(actn_code_1, i)

	for i in range(tb.TCAM_DEPTH//8):
		tcam_data = search_keys[8*i:8*i+8]
		tcam_addr = i*8
		if not DEBUG:
			await tb.tcam_wr(tcam_data=tcam_data, tcam_addr=tcam_addr)
			await RisingEdge(tb.mat.tcam_wr_ready)

	MAC_WIDTH = 48
	DMAC_OFFSET = 0
	SMAC_OFFSET = DMAC_OFFSET+MAC_WIDTH
	ET_OFFSET = SMAC_OFFSET+MAC_WIDTH
	ET_WIDTH = 16
	VLAN_WIDTH = 16
	VLAN_OFFSET = ET_OFFSET+VLAN_WIDTH
	DIP_OFFSET_v4 = ET_OFFSET+ET_WIDTH+16*8
	DIP_OFFSET_VL = ET_OFFSET+ET_WIDTH+VLAN_WIDTH*2+16*8
	IP_WIDTH = 32

	count = 24
	payloads = [bytes([(x+k) % 256 for x in range(1514)]) for k in range(count)]
	chnl_list = [[] for i in range(tb.IF_COUNT+tb.PORT_COUNT)]
	for k, payload in enumerate(payloads):
		eth = Ether(src='5A:51:52:53:54:55', dst='DA:D1:D2:D3:D4:D5')
		dip = '192.168.1.' + str(k % 256)
		ip = IP(src='192.168.1.16', dst=dip)
		udp = UDP(sport=1, dport=2)
		pkt_sent = eth / ip / udp / payload
		
		tb.log.debug("sending: pkt %d" % (k))
		if not DEBUG:
			await tb.port_mac[k % tb.PORT_COUNT].rx.send(pkt_sent.build())
		dip = 0xC0A80100+k%0x100
		chnl_dflt = (k % tb.PORT_COUNT) // tb.PORTS_PER_IF+tb.PORT_COUNT
		chnl_xpct = chnl_dict.get(dip, chnl_dflt)
		chnl_list[chnl_xpct].append(dip)
		print("%02d: ip=%08X" % (chnl_xpct, dip))

	for chnl_xpct, list in enumerate(chnl_list):
		print("chnl_xpct: %02d\n list:" % (chnl_xpct))
		print(list)
		for dip_xpct in list:
			tb.log.debug("waiting at: %X for pkt" % (chnl_xpct))
			if (DEBUG):
				pkt_recv = bytearray([i & 0xFF for i in range(512)])	# TODO: debug
			else: 
				if (chnl_xpct < tb.PORT_COUNT):
					pkt_recv = await tb.port_mac[chnl_xpct].tx.recv()
				else:
					pkt_recv = await tb.driver.interfaces[chnl_xpct - tb.PORT_COUNT].recv()
				pkt_recv = pkt_recv.data
			dmac_recv = libmat.bytearray2int(pkt_recv, DMAC_OFFSET//8, MAC_WIDTH//8)
			smac_recv = libmat.bytearray2int(pkt_recv, SMAC_OFFSET//8, MAC_WIDTH//8)
			vlan_recv = libmat.bytearray2int(pkt_recv, VLAN_OFFSET//8, VLAN_WIDTH//8)
			et_recv = libmat.bytearray2int(pkt_recv, ET_OFFSET//8, ET_WIDTH//8)
			dip_recv_v4 = libmat.bytearray2int(pkt_recv, DIP_OFFSET_v4//8, IP_WIDTH//8)
			dip_recv_vl = libmat.bytearray2int(pkt_recv, DIP_OFFSET_VL//8, IP_WIDTH//8)
			dip_recv = dip_recv_v4 if (et_recv == 0x0800) else dip_recv_vl

			dmac_xpct = dmac_dict.get(dip_xpct, 0xDA_D1_D2_D3_D4_D5)
			smac_xpct = smac_dict.get(dip_xpct, 0x5A_51_52_53_54_55)
			vlan_xpct = vlan_dict.get(dip_xpct, 0x4500)
			tb.log.debug("Chnl: %02d" % (chnl_xpct))
			tb.log.debug("assert dip: xpct %X	==	recv %X" % (dip_xpct, dip_recv))
			tb.log.debug("assert dmac: xpct %X	==	recv %X" % (dmac_xpct, dmac_recv))
			tb.log.debug("assert smac: xpct %X	==	recv %X" % (smac_xpct, smac_recv))
			tb.log.debug("assert vlan: xpct %X	==	recv %X" % (vlan_xpct, vlan_recv))
			try:
				assert dmac_recv == dmac_xpct
				assert smac_recv == smac_xpct
				assert vlan_recv == vlan_xpct
				assert dip_recv == dip_xpct
			except AssertionError:
				tb.log.debug("\n failed! \n")
				input("push any key...")

	return
