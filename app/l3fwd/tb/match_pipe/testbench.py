#
# Created on Wed Jan 05 2022
#
# Copyright (c) 2022 IOA UCAS
#
# @Filename:	 testbench.py
# @Author:		 Jiawei Lin
# @Last edit:	 09:45:47
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

warnings.filterwarnings("ignore")


class MatchPipeTB(object):
	def __init__(self, dut, debug=True):
		# Set verbosity on our various interfaces
		level = logging.DEBUG if debug else logging.WARNING
		self.log = logging.getLogger("MatchPipeTB")
		self.log.setLevel(level)

		self.dut = dut  # TODO: Control Status Register.
		self.source = AxiStreamSource(
			AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk, dut.rst)
		self.sink = AxiStreamSink(
			AxiStreamBus.from_prefix(dut, "m_axis"), dut.clk, dut.rst)
		self.source.log.setLevel(level)
		self.sink.log.setLevel(level)

		self.TCAM_DEPTH = self.dut.TCAM_DEPTH.value
		self.TCAM_WIDTH = self.dut.TCAM_DATA_WIDTH.value
		self.TCAM_WR_WIDTH = self.dut.TCAM_WR_WIDTH.value
		self.ACTN_ADDR_WIDTH = self.dut.ACTN_ADDR_WIDTH.value
		self.log.debug("TCAM_DEPTH = %d" % self.TCAM_DEPTH)
		self.log.debug("TCAM_WIDTH = %d" % self.TCAM_WIDTH)
		self.log.debug("TCAM_WR_WIDTH = %d" % self.TCAM_WR_WIDTH)
		
		self.tcam_dict = {}
		self.tcam_list = [set()]*self.TCAM_DEPTH
		self.actn_list = [0]*self.TCAM_DEPTH

		cocotb.start_soon(Clock(dut.clk, 4, units="ns").start())

	async def reset(self):
		self.dut.tcam_wr_data.value = 0
		self.dut.tcam_wr_keep.value = 0
		self.dut.tcam_wr_valid.value = 0
		self.dut.tcam_rd_cmd_addr.value = 0
		self.dut.tcam_rd_cmd_valid.value = 0
		self.dut.tcam_rd_rsp_ready.value = 1
		self.dut.actn_wr_cmd_addr.value = 0
		self.dut.actn_wr_cmd_data.value = 0
		self.dut.actn_wr_cmd_strb.value = (1 << self.dut.ACTN_STRB_WIDTH.value)-1
		self.dut.actn_wr_cmd_valid.value = 0
		self.dut.actn_rd_cmd_addr.value = 0
		self.dut.actn_rd_cmd_valid.value = 0
		self.dut.actn_rd_rsp_ready.value = 1

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

	def model_wr(self, wr_addr=0, wr_data=0, wr_keep=0, idx=0):
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
			self.model_wr(wr_addr, wr_data, wr_keep, idx+1)
			self.model_wr(wr_addr, wr_data ^ (1 << idx), wr_keep, idx+1)

	async def tcam_wr(self, wr_addr=0, wr_data=range(8), wr_keep=range(8)):
		wr_data_1 = 0
		wr_keep_1 = 0
		for i in range(8):
			wr_addr_i = (((wr_addr % self.TCAM_DEPTH) >> 3) << 3) + i
			wr_data_1 += wr_data[i] << (i*self.TCAM_WR_WIDTH)
			wr_keep_1 += wr_keep[i] << (i*self.TCAM_WR_WIDTH)
			set_2 = self.tcam_list[wr_addr_i]
			for sk in set_2:
				set_1 = self.tcam_dict[sk].discard(wr_addr_i)
			self.tcam_list[wr_addr_i] = set()
			self.model_wr(wr_addr_i, wr_data[i], wr_keep[i])

		self.dut.tcam_wr_valid.value = 1
		self.dut.tcam_wr_addr.value = wr_addr
		self.dut.tcam_wr_data.value = wr_data_1
		self.dut.tcam_wr_keep.value = wr_keep_1
		await RisingEdge(self.dut.clk)
		self.dut.tcam_wr_valid.value = 0
		for _ in range(32):
			await RisingEdge(self.dut.clk)
		await RisingEdge(self.dut.tcam_rd_cmd_ready)
	
	async def tcam_rd(self, rd_addr=0):
		self.dut.tcam_rd_cmd_addr.value = rd_addr
		self.dut.tcam_rd_cmd_valid.value = 1
		while not self.dut.tcam_rd_cmd_ready.value:
			await RisingEdge(self.dut.clk)
		await RisingEdge(self.dut.clk)
		self.dut.tcam_rd_cmd_valid.value = 0

		self.dut.tcam_rd_rsp_ready.value = 1
		await RisingEdge(self.dut.tcam_rd_rsp_valid)
		await RisingEdge(self.dut.clk)
		rd_data = self.dut.tcam_rd_rsp_data.value
		rd_keep = self.dut.tcam_rd_rsp_keep.value
		self.dut.tcam_rd_rsp_ready.value = 0
		return [rd_data, rd_keep]

	async def actn_wr(self, wr_addr=0, wr_data=0):
		self.actn_list[wr_addr] = wr_data
		self.dut.actn_wr_cmd_addr.value = wr_addr
		self.dut.actn_wr_cmd_data.value = wr_data
		self.dut.actn_wr_cmd_valid.value = 1
		await RisingEdge(self.dut.actn_wr_cmd_done)
		self.dut.actn_wr_cmd_valid.value = 0
		await RisingEdge(self.dut.clk)

	async def actn_rd(self, rd_addr=0):
		self.dut.actn_rd_cmd_addr.value = rd_addr
		self.dut.actn_rd_cmd_valid.value = 1
		await RisingEdge(self.dut.clk)
		while not (self.dut.actn_rd_cmd_ready.value):
			await RisingEdge(self.dut.clk)
		self.dut.actn_rd_cmd_valid.value = 0
		await RisingEdge(self.dut.clk)
		while not (self.dut.actn_rd_rsp_valid.value):
			await RisingEdge(self.dut.clk)
		return self.dut.actn_rd_rsp_data.value


async def run_test(dut, payload_lengths=None, payload_data=None, config_coroutine=None, idle_inserter=None, backpressure_inserter=None):
	random.seed(8)
	PKT_TYPE_IPv4 = 1
	PKT_TYPE_IPv4_VLAN = 2
	PKT_TYPE_IPv6 = 3
	PKT_TYPE_IPv6_VLAN = 4

	tb = MatchPipeTB(dut)
	await tb.reset()

	if idle_inserter is not None:
		tb.source.set_pause_generator(idle_inserter())
	if backpressure_inserter is not None:
		tb.sink.set_pause_generator(backpressure_inserter())

	for idx, wr_data in enumerate(incr_ipv4(int(tb.TCAM_DEPTH/8), 8, 0xC0A80100)):
		tb.log.debug("write tcam")
		wr_keep = [(1 << tb.TCAM_WR_WIDTH)-1]*8
		await tb.tcam_wr(idx<<3, wr_data, wr_keep)
		await RisingEdge(tb.dut.clk)
	tb.log.debug(str(tb.tcam_dict))
	tb.log.debug(str(tb.tcam_list))

	for wr_addr in range(1<<tb.ACTN_ADDR_WIDTH):
		wr_data = wr_addr
		await tb.actn_wr(wr_addr, wr_data)

	pkts = []
	for payload in [payload_data(x) for x in payload_lengths()]:
		eth = Ether(src='5A:51:52:53:54:55', dst='DA:D1:D2:D3:D4:D5')# 0xC0A80110 0xC0A880111
		dst_ip_l = random.randint(0, 0x1F)
		dst_ip = '192.168.1.'+str(dst_ip_l)
		ip = IP(src='192.168.1.16', dst=dst_ip)
		# ip_pkt_sent.append(dst_ip)
		udp = UDP(sport=1, dport=2)
		pkt_sent = eth / ip / udp / payload

		tx_frame = AxiStreamFrame(pkt_sent.build())
		tx_frame.tuser = PKT_TYPE_IPv4
		await tb.source.send(tx_frame)
		pkts.append(pkt_sent)

	for i in range(tb.TCAM_DEPTH):
		[rd_data, rd_keep] = await tb.tcam_rd(i)
		try:
			assert (int(rd_data) in tb.tcam_list[i])
		except AssertionError:
			tb.log.debug("tcam[%02X] = (%s, %s)" %
		             (i, format(int(rd_data), '08X'), format(int(rd_keep), '08X')))
			tb.log.debug("tcam_list[%02d]=%s" % (i, repr(tb.tcam_list[i])))
			input("\n\n\t Push any key...")

	for rd_addr in range(1 << tb.ACTN_ADDR_WIDTH):
		rd_data = await tb.actn_rd(rd_addr)
		try: assert rd_data == tb.actn_list[rd_addr]
		except AssertionError:
			tb.log.debug("inq:%08X != exp:%08X" % (rd_data, tb.actn_list[rd_addr]))
			input("\n\t push any key...\n")

	for pkt in pkts:
		rx_frame = await tb.sink.recv()
		if type(rx_frame.tuser) == int:
			user_recv = rx_frame.tuser
		else:
			user_recv = rx_frame.tuser[0]
		action_code = (user_recv>>4) & ((1<<48)-1)
		t = rx_frame.tdata
		dip_rx = (t[14+16] << 8*3) | (t[14+17] << 8*2) | (t[14+18] << 8) | (t[14+19])
		tb.log.debug("dip_rx = 0x%08X" % dip_rx)
		match_addr_s = tb.tcam_dict.get(dip_rx, {0})
		try:
			for i in match_addr_s:
				action_code_exp = tb.actn_list[i]
				assert action_code == action_code_exp
				tb.log.debug("rx:%d = exp:%d" % (action_code, action_code_exp))
		except AssertionError:
			tb.log.debug("rx:%d != exp:%d" % (action_code, action_code_exp))
			input("\n\t push any key...\n")

	# Wait at least 2 cycles where output ready is low before ending the test
	for i in range(2):
		await RisingEdge(dut.clk)
		while not dut.m_axis_tready.value:
			await RisingEdge(dut.clk)


def cycle_pause():
	return itertools.cycle([1, 1, 1, 0])


def size_list(min_1=8, max_1=22, step_1=1):
	return list(range(min_1, max_1+1, step_1))


def incrementing_payload(length):
	return bytes(itertools.islice(itertools.cycle(range(1, 256)), length))


def test_ipv4(times=4, length=8, ip_base=0xC0A80100):
	set = range(0xFF)
	for i in range(times):
		rand_set = random.sample(set, length)
		yield [i+ip_base for i in rand_set]


def incr_ipv4(times=4, length=8, ip_base=0xC0A80100):
	for i in range(times):
		set = range(i*length, (i+1)*length)
		yield [i+ip_base for i in set]


if cocotb.SIM_NAME:
	factory = TestFactory(run_test)
	factory.add_option("payload_lengths", [size_list])
	factory.add_option("payload_data", [incrementing_payload])
	factory.add_option("idle_inserter", [None, cycle_pause])
	factory.add_option("backpressure_inserter", [None, cycle_pause])
	factory.generate_tests()

