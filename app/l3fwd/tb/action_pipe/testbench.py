#
# Created on Tue Feb 22 2022
#
# Copyright (c) 2022 IOA UCAS
#
# @Filename:	 testbench.py
# @Author:		 Jiawei Lin
# @Last edit:	 09:12:04
#

from cocotbext.axi import AxiLiteBus, AxiLiteMaster
from cocotbext.axi import AxiStreamBus, AxiStreamFrame
from cocotbext.axi import AxiStreamSource, AxiStreamSink
from cocotb.regression import TestFactory
from cocotb.triggers import RisingEdge, FallingEdge
from cocotb.clock import Clock
import cocotb
from scapy.layers.inet import IP, UDP
from scapy.layers.l2 import Ether
import scapy.utils
import itertools
import logging
import random
import warnings

try:
	import libmat
except ImportError:
	# attempt import from current directory
	sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
	try:
		import libmat
	finally:
		del sys.path[0]


class ActionPipeTB(object):
	def __init__(self, dut, debug=True):
		# Set verbosity on our various interfaces
		level = logging.DEBUG if debug else logging.WARNING
		self.log = logging.getLogger("ActionPipeTB")
		self.log.setLevel(level)

		self.dut = dut
		self.source = AxiStreamSource(
			AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk, dut.rst)
		self.sink = AxiStreamSink(
			AxiStreamBus.from_prefix(dut, "m_axis"), dut.clk, dut.rst)
		self.source.log.setLevel(level)
		self.sink.log.setLevel(level)

		self.ACTN_DATA_WIDTH = self.dut.ACTN_DATA_WIDTH.value
		self.S_DATA_WIDTH = self.dut.S_DATA_WIDTH.value
		self.M_DATA_WIDTH = self.dut.M_DATA_WIDTH.value
		self.log.debug("ACTN_DATA_WIDTH = %d" % self.ACTN_DATA_WIDTH)
		self.log.debug("S_DATA_WIDTH = %d" % self.S_DATA_WIDTH)
		self.log.debug("M_DATA_WIDTH = %d" % self.M_DATA_WIDTH)
		self.PT_IPV4 = self.dut.PT_IPV4.value
		self.PT_VLV4 = self.dut.PT_VLV4.value
		self.PT_IPV6 = self.dut.PT_IPV6.value
		self.PT_VLV6 = self.dut.PT_VLV6.value
		self.S_DEST_WIDTH = self.dut.S_DEST_WIDTH.value
		
		self.action_code = 0

		cocotb.start_soon(Clock(dut.clk, 4, units="ns").start())

	async def reset(self):
		await RisingEdge(self.dut.clk)
		await RisingEdge(self.dut.clk)
		self.log.info("reset begin")
		self.dut.rst.setimmediatevalue(0)
		await RisingEdge(self.dut.clk)
		await RisingEdge(self.dut.clk)
		self.dut.rst <= 1
		await RisingEdge(self.dut.clk)
		await RisingEdge(self.dut.clk)
		self.dut.rst.value = 0
		await RisingEdge(self.dut.clk)
		await RisingEdge(self.dut.clk)
		self.log.info("reset end")


async def run_test(dut, payload_lengths=None, payload_data=None, config_coroutine=None, idle_inserter=None, backpressure_inserter=None):
	tb = ActionPipeTB(dut)
	await tb.reset()

	if idle_inserter is not None:
		tb.source.set_pause_generator(idle_inserter())
	if backpressure_inserter is not None:
		tb.sink.set_pause_generator(backpressure_inserter())
	
	MAC_WIDTH = 48
	DMAC_OFFSET = 0
	SMAC_OFFSET = DMAC_OFFSET+MAC_WIDTH
	VLAN_WIDTH = 16
	VLAN_OFFSET = SMAC_OFFSET+MAC_WIDTH+VLAN_WIDTH
	IP_WIDTH = 32
	DIP_OFFSET = 30*8

	i = 0
	pkts = []
	mtdt_list = []
	for payload in [payload_data(x) for x in payload_lengths()]:
		i = i+1
		eth = Ether(src='5A:51:52:53:54:55', dst='DA:D1:D2:D3:D4:D5')
		ip = IP(src='192.168.1.16', dst='192.168.1.17')
		udp = UDP(sport=i, dport=2)
		pkt_sent = eth / ip / udp / payload

		dmac_1 = (0xD0_D1_D2_D3_D4_D5 + (i << 40)) % (1 << 48)
		smac_1 = (0x50_51_52_53_54_55 + (i+1 << 40)) % (1 << 48)
		vlan_1 = (0xFF00+i) & 0xFFFF
		chnl_1 = (0x1+i) % (1 << 4)
		action_code_1 = libmat.f_set_actn_code(d_mac=dmac_1, s_mac=smac_1, vl_data=vlan_1, tid=chnl_1, tdest=0,
		                          vl_op=0b01, tdest_en=True, cks_en=True, d_mac_en=True, s_mac_en=True)

		tx_frame = AxiStreamFrame(pkt_sent.build())
		tx_frame.tuser = tb.PT_IPV4+(action_code_1 << 4)
		await tb.source.send(tx_frame)
		pkts.append(pkt_sent)
		mtdt_list.append((dmac_1,smac_1,vlan_1,chnl_1))

	for i, pkt in enumerate(pkts):
		rx_frame = await tb.sink.recv()
		if type(rx_frame.tuser) == int:
			user_recv = rx_frame.tuser
		else:
			user_recv = rx_frame.tuser[0]
		action_code = (user_recv >> 4) & ((1 << 48)-1)

		pkt_recv = rx_frame.tdata
		dmac_2 = libmat.bytearray2int(pkt_recv, DMAC_OFFSET//8, MAC_WIDTH//8)
		smac_2 = libmat.bytearray2int(pkt_recv, SMAC_OFFSET//8, MAC_WIDTH//8)
		vlan_2 = libmat.bytearray2int(pkt_recv, VLAN_OFFSET//8, VLAN_WIDTH//8)
		chnl_2 = rx_frame.tdest
		(dmac_1,smac_1,vlan_1,chnl_1) = mtdt_list[i]
		tb.log.debug("recv, query: %012X==%012X" % (dmac_2, dmac_1))
		tb.log.debug("recv, query: %012X==%012X" % (smac_2, smac_1))
		tb.log.debug("recv, query: %04X==%04X" % (vlan_2, vlan_1))
		tb.log.debug("recv, query: %X==%X" % (chnl_2, chnl_1))
		try:
			assert dmac_2 == dmac_1
			assert smac_2 == smac_1
			assert vlan_2 == vlan_1
			assert chnl_2 == chnl_1
		except AssertionError:
			tb.log.debug("failed")
			input("\n\n\t push any key...\n")


def cycle_pause():
	return itertools.cycle([1, 1, 1, 0])


def size_list(min_1=8, max_1=22, step_1=1):
	return list(range(min_1, max_1+1, step_1))


def incrementing_payload(length):
	return bytes(itertools.islice(itertools.cycle(range(1, 256)), length))


if cocotb.SIM_NAME:
	factory = TestFactory(run_test)
	factory.add_option("payload_lengths", [size_list])
	factory.add_option("payload_data", [incrementing_payload])
	factory.add_option("idle_inserter", [None, cycle_pause])
	factory.add_option("backpressure_inserter", [None, cycle_pause])
	factory.generate_tests()
