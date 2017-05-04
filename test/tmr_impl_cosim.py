import random
import time
import cocotb
from cocotb.clock import Clock
from cocotb.monitors import BusMonitor
from cocotb.scoreboard import Scoreboard
from cocotb.triggers import Timer, RisingEdge, ReadOnly, ClockCycles
from cocotb.utils import get_sim_steps
from cocotb.binary import BinaryValue
from cocotb.result import ReturnValue
from monitor import BaseMonitor
from cocotb.regression import TestFactory

class TmrImpl():
	"""
	Timer logic driver
	"""

	def __init__(self, entity, clock, bits):
		self._entity = entity
		self._clk = clock
		self._bits = bits


	def reset(self):
		# At reset assertion time, master MUST drive arvalid, awvalid
		# and awvalid to low level in addition to areset_n.
		self._entity.ld_cnt   = 1
		self._entity.cnt      = BinaryValue(0, bits=self._bits)
		self._entity.set_laps = 1
		self._entity.laps     = BinaryValue(0, bits=self._bits - 2)
		self._entity.clr_alrm = 1


	def dereset(self):
		self._entity.ld_cnt   = 0
		self._entity.set_laps = 0
		self._entity.laps     = BinaryValue(0, bits=self._bits - 2)
		self._entity.clr_alrm = 0


	@cocotb.coroutine
	def get_count(self):
		while True:
			yield ReadOnly()
			if self._entity.ld_cnt == 0:
				break

		raise ReturnValue(self._entity.cntdwn)


	@cocotb.coroutine
	def set_count(self, count, trigger):
		self._entity.ld_cnt = 1
		self._entity.cnt    = BinaryValue(count, bits=self._bits,
		                                  bigEndian=False)

		while True:
			yield ReadOnly()
			if self._entity.cnt_ld == 1:
				break

		yield trigger
		self._entity.ld_cnt = 0


	@cocotb.coroutine
	def set_lapse(self, lapse, trigger):
		self._entity.set_laps = 1
		self._entity.laps     = BinaryValue(lapse, bits=self._bits - 2,
		                                    bigEndian=False)

		while True:
			yield ReadOnly()
			if self._entity.laps_set == 1:
				break

		yield trigger
		self._entity.set_laps = 0


	@cocotb.coroutine
	def wait_alarm(self, trigger):
		cyc = 0
		while True:
			yield ReadOnly()
			if self._entity.alrm_set == 1:
				break
			yield RisingEdge(self._clk)
			cyc = cyc + 1

		yield trigger
		raise ReturnValue(cyc)


	@cocotb.coroutine
	def clr_alarm(self, trigger):
		self._entity.clr_alrm = 1

		while True:
			yield ReadOnly()
			if self._entity.alrm_set == 0:
				break

		yield trigger
		self._entity.clr_alrm = 0


class TmrImplMonitor(BaseMonitor):
	"""
	Timer logic monitor
	"""

	_signals = [ "cnt_ld", "cntdwn", "laps_set", "alrm_set" ]

	def __init__(self, entity, scoreboard):
		BaseMonitor.__init__(self, entity, entity.clk, scoreboard)


class TmrImplTestBench():

	def __init__(self, entity, fail_immediately):
		self._entity = entity
		self._drv = TmrImpl(entity, entity.clk, 32)
		self._sbrd = Scoreboard(entity,
		                        fail_immediately=fail_immediately)
		self._mon = TmrImplMonitor(entity, self._sbrd)


	def driver(self):
		return self._drv


	@cocotb.coroutine
	def expect(self, expected):
		yield self._mon.expect(expected)


	@cocotb.coroutine
	def start(self, period):
		yield Timer(3 * period / 4)
		self._drv.reset()
		yield Timer(period / 4)
		cocotb.fork(Clock(self._entity.clk, period).start())
		yield Timer(3 * period / 4)
		self._drv.dereset()
		yield RisingEdge(self._entity.clk)


	def failure(self, message):
		self._mon.failure(message)


@cocotb.test()
def tmr_test_count(dut):
	tb  = TmrImplTestBench(dut, exit_on_fail)
	drv = tb.driver()

	yield tb.start(clk_t)

	for c in range(1, 9):
		exp = {
		        "name"  : "get count",
		        "cntdwn": BinaryValue(c, bits=32, bigEndian=False)
		}
		yield tb.expect(exp)
		yield RisingEdge(dut.clk)


@cocotb.coroutine
def tmr_test_alarm(dut, lapse, lapse_cycles):
	tb  = TmrImplTestBench(dut, exit_on_fail)
	drv = tb.driver()

	yield tb.start(clk_t)

	yield drv.set_lapse(lapse, ClockCycles(dut.clk, lapse_cycles))

	for l in range(0, 5):
		cyc = yield drv.wait_alarm(Timer(clk_t / 4))
		if cyc != lapse:
			tb.failure("unexpected alarm ticks (received != " +
			           "expected): %d != %d" % (cyc, lapse))
		yield drv.clr_alarm(Timer(clk_t / 4))


@cocotb.coroutine
def tmr_test_set_count(dut, hold_cycles, wait_cycles):
	tb  = TmrImplTestBench(dut, exit_on_fail)
	drv = tb.driver()

	yield tb.start(clk_t)

	for c in range(0, 5):
		yield RisingEdge(dut.clk)

	for c in range(0, 5):
		cnt = random.getrandbits(32)
		yield drv.set_count(cnt, ClockCycles(dut.clk, hold_cycles))
		exp = {
		        "name"  : "set count",
		}

		for w in range (0, wait_cycles):
			exp["cntdwn"] = BinaryValue(cnt, bits=32,
			                            bigEndian=False)
			yield tb.expect(exp)
			yield RisingEdge(dut.clk)
			cnt = cnt + 1


random.seed(time.time())
clk_t = 2000
exit_on_fail=True

fact = TestFactory(tmr_test_set_count)
fact.add_option("hold_cycles", [1, 2, 3, 10])
fact.add_option("wait_cycles", [1, 2, 3, 10])
fact.generate_tests()

fact = TestFactory(tmr_test_alarm)
fact.add_option("lapse", [1, 2, 3, 10, 100])
fact.add_option("lapse_cycles", [1, 2, 3, 10])
fact.generate_tests()
