#!/usr/bin/env python
"""

Copyright (c) 2021 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

"""

import itertools
import logging
import os
import random
import subprocess

import cocotb_test.simulator
import pytest

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Event
from cocotb.regression import TestFactory

from cocotbext.axi import AxiLiteBus, AxiLiteMaster
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource, AxiStreamSink

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
warnings.filterwarnings("ignore")

class TB(object):
	def __init__(self, dut):
		self.dut = dut

		ports = dut.COUNT.value

		self.log = logging.getLogger("cocotb.tb")
		self.log.setLevel(logging.DEBUG)

		cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

		self.rx_src = [AxiStreamSource(AxiStreamBus.from_prefix(dut, f"s{k:02d}_axis_rx"), dut.clk, dut.rst) for k in range(ports)]
		self.rx_snk = [AxiStreamSink(AxiStreamBus.from_prefix(dut, f"m{k:02d}_axis_rx"), dut.clk, dut.rst) for k in range(ports)]
		self.tx_src = [AxiStreamSource(AxiStreamBus.from_prefix(dut, f"s{k:02d}_axis_tx"), dut.clk, dut.rst) for k in range(ports)]
		self.tx_snk = [AxiStreamSink(AxiStreamBus.from_prefix(dut, f"m{k:02d}_axis_tx"), dut.clk, dut.rst) for k in range(ports)]
		self.axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil"), dut.clk, dut.rst)

		mat = dut.app_top_1.app_core_1.app_mat_1
		self.log.debug(dut.app_top_1.M_CONNECT.value)
		self.COUNT = dut.COUNT.value
		self.TCAM_DEPTH = 16 # mat.TCAM_DEPTH.value
		self.TCAM_WR_WIDTH = mat.TCAM_WR_WIDTH.value
		self.BAR_TCAM_WR_DATA = mat.BAR_TCAM_WR_DATA.value
		self.BAR_TCAM_WR_KEEP = mat.BAR_TCAM_WR_KEEP.value
		self.BAR_ACTN_WR_DATA = mat.BAR_ACTN_WR_DATA.value
		self.BAR_ACTN_RD_DATA = mat.BAR_ACTN_RD_DATA.value
		self.BAR_TCAM_RD_DATA = mat.BAR_TCAM_RD_DATA.value
		self.BAR_TCAM_RD_KEEP = mat.BAR_TCAM_RD_KEEP.value
		self.BAR_CSR = mat.BAR_CSR.value
		self.CSR_TCAM_OFFSET = mat.CSR_TCAM_OFFSET.value
		self.CSR_ACTN_OFFSET = mat.CSR_ACTN_OFFSET.value
		self.CSR_TCAM_WR = mat.CSR_TCAM_WR.value
		self.CSR_TCAM_RD = mat.CSR_TCAM_RD.value
		self.CSR_ACTN_WR = mat.CSR_ACTN_WR.value
		self.CSR_ACTN_RD = mat.CSR_ACTN_RD.value

		self.tcam_dict = {}
		self.tcam_list = [set()]*self.TCAM_DEPTH
		self.actn_list = [0]*self.TCAM_DEPTH

	def set_idle_generator(self, generator=None):
		if generator:
			for source in self.rx_src:
				source.set_pause_generator(generator())
			for source in self.tx_src:
				source.set_pause_generator(generator())

	def set_backpressure_generator(self, generator=None):
		if generator:
			for sink in self.rx_snk:
				sink.set_pause_generator(generator())
			for sink in self.tx_snk:
				sink.set_pause_generator(generator())

	def set_idle_generator_axil(self, generator=None):
		if generator:
			self.axil_master.write_if.aw_channel.set_pause_generator(generator())
			self.axil_master.write_if.w_channel.set_pause_generator(generator())
			self.axil_master.read_if.ar_channel.set_pause_generator(generator())

	def set_backpressure_generator_axil(self, generator=None):
		if generator:
			self.axil_master.write_if.b_channel.set_pause_generator(generator())
			self.axil_master.read_if.r_channel.set_pause_generator(generator())

	async def reset(self):
		self.dut.rst.setimmediatevalue(0)
		await RisingEdge(self.dut.clk)
		await RisingEdge(self.dut.clk)
		self.dut.rst.value = 1
		await RisingEdge(self.dut.clk)
		await RisingEdge(self.dut.clk)
		self.dut.rst.value = 0
		await RisingEdge(self.dut.clk)
		await RisingEdge(self.dut.clk)

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
			await self.axil_master.write_dword(self.BAR_TCAM_WR_DATA+i*0x4, tcam_data[i])
			await self.axil_master.write_dword(self.BAR_TCAM_WR_KEEP+i*0x4, tcam_keep[i])

		# TODO: mask
		csr_op_code = (1 << self.CSR_TCAM_WR) | (
		    tcam_addr << self.CSR_TCAM_OFFSET % 0x10000)
		await self.axil_master.write_dword(self.BAR_CSR, csr_op_code)

	async def tcam_rd(self, tcam_addr=0x0001):
		csr_op_code = (1 << self.CSR_TCAM_RD) | (
		    tcam_addr << self.CSR_TCAM_OFFSET % 0x10000)
		await self.axil_master.write_dword(self.BAR_CSR, csr_op_code)
		rd_data = 0
		rd_keep = 0
		for i in range(1):
			tcam_data = await self.axil_master.read_dword(self.BAR_TCAM_RD_DATA+i*0x4)
			tcam_keep = await self.axil_master.read_dword(self.BAR_TCAM_RD_KEEP+i*0x4)
			rd_data |= tcam_data << (i*32)
			rd_keep |= tcam_keep << (i*32)
		return [rd_data, rd_keep]

	async def actn_wr(self, actn_data=0x0001, actn_addr=0x0001):
		self.actn_list[actn_addr] = actn_data
		for i in range(4):
			wr_data = (actn_data >> i*32) & 0xFFFF_FFFF
			await self.axil_master.write_dword(self.BAR_ACTN_WR_DATA+i*0x4, wr_data)

		# TODO: mask
		csr_op_code = (1 << self.CSR_ACTN_WR) | (
		    actn_addr << self.CSR_ACTN_OFFSET % 0x10000)
		await self.axil_master.write_dword(self.BAR_CSR, csr_op_code)

	async def actn_rd(self, actn_addr=0x0001):
		csr_op_code = (1 << self.CSR_ACTN_RD) | (
		    actn_addr << self.CSR_ACTN_OFFSET % 0x10000)
		await self.axil_master.write_dword(self.BAR_CSR, csr_op_code)
		rd_data = 0
		for i in range(4):
			actn_data = await self.axil_master.read_dword(self.BAR_ACTN_RD_DATA+i*0x4)
			rd_data |= actn_data << (i*32)
		return rd_data


async def run_test(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

	tb = TB(dut)
	await tb.reset()

	tb.set_idle_generator(idle_inserter)
	tb.set_backpressure_generator(backpressure_inserter)
	tb.set_idle_generator_axil(idle_inserter)
	tb.set_backpressure_generator_axil(backpressure_inserter)

	payloads = [payload_data(x) for x in payload_lengths(4, 4+4*8, 4)]
	tx_frames = []
	for i, payload in enumerate(payloads):
		eth = Ether(src='5A:51:52:53:54:55', dst="%02X" % (i % 256)+':D1:D2:D3:D4:D5')
		pkt_sent = eth / payload
		tx_frame = AxiStreamFrame(pkt_sent.build())
		tx_frame.tid = i % (1 << 4)
		tx_frame.tdest = i % (1 << 4)
		tx_frames.append(tx_frame)
		await tb.tx_src[i % tb.COUNT].send(tx_frame)
		await tb.rx_src[i % tb.COUNT].send(tx_frame)

	for i, tx_frame in enumerate(tx_frames):
		rx_frame = await tb.tx_snk[i % tb.COUNT].recv()
		assert rx_frame == tx_frame
		rx_frame = await tb.rx_snk[i % tb.COUNT].recv()
		assert rx_frame.tdata == tx_frame.tdata

	## Configure Tables. 
	dmac_dict = {}
	smac_dict = {}
	vlan_dict = {}
	chnl_dict = {}
	search_keys = [0xC0A80101+i for i in range(tb.TCAM_DEPTH)]
	for i in range(tb.TCAM_DEPTH):
		dmac_1 = (0xD1_D1_D2_D3_D4_D5 + (i << 40)) % (1 << 48)
		smac_1 = (0x51_51_52_53_54_55 + (i << 40)) % (1 << 48)
		vlan_1 = (0xF001+i) % 0x10000
		chnl_1 = (0x1+i) % (tb.COUNT*2)
		dmac_dict[search_keys[i]] = dmac_1
		smac_dict[search_keys[i]] = smac_1
		vlan_dict[search_keys[i]] = vlan_1
		chnl_dict[search_keys[i]] = chnl_1
		actn_code_1 = libmat.f_set_actn_code(d_mac=dmac_1, s_mac=smac_1, vl_data=vlan_1, tdest=0, tid=chnl_1,
                                       vl_op=0b01, tdest_en=True, cks_en=True, d_mac_en=True, s_mac_en=True)
		await tb.actn_wr(actn_code_1, i)

	for i in range(tb.TCAM_DEPTH//8):
		tcam_data = search_keys[8*i:8*i+8]
		tcam_addr = i*8
		await tb.tcam_wr(tcam_data=tcam_data, tcam_addr=tcam_addr)

	for _ in range(33):
		await RisingEdge(dut.clk)

	## Send packet and receive
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
	
	min_1 = 2
	step_1 = 16
	max_1 = (tb.TCAM_DEPTH+2)*step_1
	payloads = [payload_data(x) for x in payload_lengths(min_1, max_1, step_1)]
	tx_frames = []
	dip_dict = {}
	chnl_list = [[] for i in range(tb.COUNT*2)]
	for i, payload in enumerate(payloads):
		dip = 0xC0A80100+i % 0x100
		chnl_dflt = (i % tb.COUNT) + tb.COUNT
		chnl_xpct = chnl_dict.get(dip, chnl_dflt)
		chnl_list[chnl_xpct].append(dip)
		print("%02d: ip=%08X" % (chnl_xpct, dip))

		eth = Ether(src='5A:51:52:53:54:55', dst='DA:D1:D2:D3:D4:D5')
		dip = '192.168.1.' + str(i % 256)
		ip = IP(src='192.168.1.16', dst=dip)
		udp = UDP(sport=1, dport=2)
		pkt_sent = eth / ip / udp / payload
		tx_frame = AxiStreamFrame(pkt_sent.build())
		tx_frame.tid = i % (1 << 4)
		tx_frame.tdest = chnl_xpct % (1 << 4)
		tx_frames.append(tx_frame)
		await tb.rx_src[i % tb.COUNT].send(tx_frame)

	for i in range(tb.TCAM_DEPTH):
		actn_inq = await tb.actn_rd(i)
		try:
		    assert actn_inq == tb.actn_list[i]
		except AssertionError:
			tb.log.debug("actn inq!=expc: %08X==%08X" % (actn_inq, tb.actn_list[i]))
			input("\n\n\t push any key...")

	for i in range(tb.TCAM_DEPTH):
		[tcam_data, tcam_keep] = await tb.tcam_rd(i)
		try:
		    assert (tcam_data in tb.tcam_list[i])
		except AssertionError:
			tb.log.debug("tcam_rd: %08X not in %s" % (tcam_data, repr(tb.tcam_list[i])))
			input("\n\n\t push any key...")

	for chnl_xpct, list in enumerate(chnl_list):
		print("chnl_xpct: %02d\n list:" % (chnl_xpct))
		print(list)
		for dip_xpct in list:
			tb.log.debug("waiting at: %X for pkt %X" % (chnl_xpct, dip_xpct))
			if (chnl_xpct < tb.COUNT):
				pkt_recv = await tb.tx_snk[chnl_xpct].recv()
			else:
				pkt_recv = await tb.rx_snk[chnl_xpct - tb.COUNT].recv()

			pkt_recv = pkt_recv.tdata
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

			tb.log.debug("search key: %X" % (dip_xpct))
			tb.log.debug("assert dip: %X==%X" % (dip_xpct, dip_recv))
			tb.log.debug("assert dmac: %X==%X" % (dmac_xpct, dmac_recv))
			tb.log.debug("assert smac: %X==%X" % (smac_xpct, smac_recv))
			tb.log.debug("assert vlan: %X==%X" % (vlan_xpct, vlan_recv))
			try:
				assert dmac_recv == dmac_xpct
				assert smac_recv == smac_xpct
				assert vlan_recv == vlan_xpct
				assert dip_recv == dip_xpct
			except AssertionError:
				tb.log.debug("\n failed! \n")
				input("push any key...")
	
	for i in range(tb.COUNT):
		assert tb.rx_snk[i].empty()
		assert tb.tx_snk[i].empty()
	await RisingEdge(dut.clk)
	await RisingEdge(dut.clk)


async def run_stress_test(dut, idle_inserter=None, backpressure_inserter=None):

	tb = TB(dut)

	byte_lanes = tb.rx_src[0].byte_lanes
	id_width = len(tb.rx_src[0].bus.tid)
	id_count = 2**id_width
	id_mask = id_count-1

	src_width = (len(tb.rx_src)-1).bit_length()
	src_mask = 2**src_width-1 if src_width else 0
	src_shift = id_width-src_width
	max_count = 2**src_shift
	count_mask = max_count-1

	cur_id = 1

	await tb.reset()

	tb.set_idle_generator(idle_inserter)
	tb.set_backpressure_generator(backpressure_inserter)

	tx_frames = [list() for x in tb.rx_src]

	for p in range(len(tb.rx_src)):
		for k in range(128):
			length = random.randint(1, byte_lanes*16)
			test_data = bytearray(itertools.islice(itertools.cycle(range(256)), length))
			tx_frame = AxiStreamFrame(test_data)
			tx_frame.tid = cur_id | (p << src_shift)
			tx_frame.tdest = cur_id

			tx_frames[p].append(tx_frame)
			await tb.rx_src[p].send(tx_frame)

			cur_id = (cur_id + 1) % max_count

	while any(tx_frames):
		rx_frame = await tb.sink.recv()

		tx_frame = None

		for lst in tx_frames:
			if lst and lst[0].tid == (rx_frame.tid & id_mask):
				tx_frame = lst.pop(0)
				break

		assert tx_frame is not None

		assert rx_frame.tdata == tx_frame.tdata
		assert (rx_frame.tid & id_mask) == tx_frame.tid
		assert ((rx_frame.tid >> src_shift) & src_mask) == (rx_frame.tid >> id_width)
		assert rx_frame.tdest == tx_frame.tdest
		assert not rx_frame.tuser

	assert tb.sink.empty()

	await RisingEdge(dut.clk)
	await RisingEdge(dut.clk)


def cycle_pause():
	return itertools.cycle([1, 1, 1, 0])


def size_list(min_1=8, max_1=8, step_1=1):
	return list(range(min_1, max_1+1, step_1))


def incrementing_payload(length):
	return bytes(itertools.islice(itertools.cycle(range(1, 256)), length))


if cocotb.SIM_NAME:

	ports = len(cocotb.top.app_top_1.s_axis_tx_tvalid)

	factory = TestFactory(run_test)
	factory.add_option("payload_lengths", [size_list])
	factory.add_option("payload_data", [incrementing_payload])
	# factory.add_option("idle_inserter", [None])
	# factory.add_option("backpressure_inserter", [None])
	factory.add_option("idle_inserter", [None, cycle_pause])
	factory.add_option("backpressure_inserter", [None, cycle_pause])
	factory.generate_tests()
