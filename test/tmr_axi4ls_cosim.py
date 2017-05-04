import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.binary import BinaryValue
from cocotb.result import ReturnValue
from amba import Axi4lMaster, AxiError

class Axi4lsTmrTB():
	def __init__(self, entity):
		self._entity = entity
		self._mst = Axi4lMaster(entity, entity.aclk, 32)


	@cocotb.coroutine
	def start(self, period):
		yield Timer(period / 2)
		yield self._mst.reset(period / 2)
		cocotb.fork(Clock(self._entity.aclk, period).start())
		yield Timer(period / 2)
		yield self._mst.dereset()


	@cocotb.coroutine
	def set_mode(self, mode):
		yield self._mst.wrxact(0, mode)


	@cocotb.coroutine
	def get_count(self):
		cnt = yield self._mst.rdxact(12)
		raise ReturnValue(cnt)


	@cocotb.coroutine
	def set_count(self, count):
		yield self._mst.wrxact(12, count)


@cocotb.test()
def axi4ls_test_cnt(dut):
	tb = Axi4lsTmrTB(dut)
	yield tb.start(clk_t)

	yield tb.set_mode(1)
	yield tb.get_count()
	yield tb.get_count()
	yield tb.get_count()
	yield tb.set_count(10)
	cnt = yield tb.get_count()
	print cnt
	yield RisingEdge(dut.aclk)
	yield RisingEdge(dut.aclk)

clk_t = 2000
