from random import seed
from time import time
import cocotb
from cocotb.clock import Clock
from cocotb.monitors import BusMonitor
from cocotb.scoreboard import Scoreboard
from cocotb.triggers import Timer, RisingEdge
from cocotb.utils import get_sim_steps
from cocotb.binary import BinaryValue
from cocotb.result import ReturnValue
from monitor import BaseMonitor
from cocotb.regression import TestFactory

class TmrRegs():
	"""
	Timer registers logic driver
	"""
        
	def __init__(self, entity, clock, bits):
		self._entity = entity
		self._clk = clock
		self._bits = bits


	def reset(self):
		self._entity.rst_n = 0
		self._entity.we    = 0
		self._entity.oe    = 0


	@cocotb.coroutine
        def dereset(self):
		self._entity.rst_n = 1

		yield RisingEdge(self._clk)


	def _begin_write(self, reg, data):
		self._entity.wdat = BinaryValue(data, bits=self._bits,
		                                bigEndian=False)
		self._entity.wreg = reg
		self._entity.we = 1


	def _end_write(self):
		self._entity.we = 0


	def _begin_read(self, reg):
		self._entity.oe = 1
		self._entity.oreg = reg


	def _end_read(self):
		self._entity.oe = 0
        
	@cocotb.coroutine
	def write_reg(self, reg, data, setup_trigger, hold_trigger):
		if setup_trigger != None:
			yield setup_trigger
		self._begin_write(reg, data)
		if hold_trigger != None:
			yield hold_trigger
		self._end_write()


	@cocotb.coroutine
	def read_reg(self, reg, setup_trigger, hold_trigger):
		if setup_trigger != None:
			yield setup_trigger
		self._begin_read(reg)
		if hold_trigger != None:
			yield hold_trigger
		self._end_read()

		raise ReturnValue(self._entity.odat)


class TmrRegsMonitor(BaseMonitor):
	"""
	Timer registers logic monitor
	"""

	_signals = [ "rst_n", "clk", "we", "wreg", "wdat", "oe", "oreg", "odat",
	             "int" ]

	def __init__(self, entity, scoreboard):
		BaseMonitor.__init__(self, entity, entity.clk, scoreboard)


class TmrReg:
	CTRL = 0
	STAT = 1
	ALRM = 2
	CNT  = 3


class TmrCtrlMode:
	NONE = 0
	CNT  = 1
	SNGL = 2
	AUTO = 3


class TmrRegsTestBench():

	def __init__(self, entity, fail_immediately):
		self._entity = entity
		self._drv = TmrRegs(entity, entity.clk, 32)
		self._sbrd = Scoreboard(entity,
		                        fail_immediately=fail_immediately)
		self._mon = TmrRegsMonitor(entity, self._sbrd)


	def driver(self):
		return self._drv


	@cocotb.coroutine
	def expect(self, expected):
		yield self._mon.expect(expected)


	@cocotb.coroutine
	def start(self, period):
		self._drv.reset()
		yield Timer(period)
		cocotb.fork(Clock(self._entity.clk, period).start())
		yield Timer(period / 2)
		yield self._drv.dereset()


	def failure(self, message):
		self._mon.failure(message)


	@cocotb.coroutine
	def set_mode(self, mode, setup_trigger, hold_trigger):
		yield self._drv.write_reg(TmrReg.CTRL, mode, setup_trigger,
		                          hold_trigger)


	@cocotb.coroutine
	def get_mode(self, setup_trigger, hold_trigger):
		mode = yield self._drv.read_reg(TmrReg.CTRL, setup_trigger,
		                                hold_trigger)
		raise ReturnValue(mode)


	@cocotb.coroutine
	def check_mode(self, mode, write_setup, write_hold, read_setup,
	               read_hold):
		wr = cocotb.fork(self.set_mode(mode,
		                               Timer(write_setup),
		                               Timer(write_hold)))
		m = yield self.get_mode(Timer(read_setup), Timer(read_hold))

		yield wr.join()

		if m != mode:
			self.failure("unexpected mode (received != " +
			             "expected): %d != %d" % (m, mode))

		yield RisingEdge(self._entity.clk)


	@cocotb.coroutine
	def set_count(self, count, setup_trigger, hold_trigger):
		yield self._drv.write_reg(TmrReg.CNT, count, setup_trigger,
		                          hold_trigger)


	@cocotb.coroutine
	def get_count(self, setup_trigger, hold_trigger):
		cnt = yield self._drv.read_reg(TmrReg.CNT, setup_trigger,
		                               hold_trigger)
		raise ReturnValue(cnt)


	@cocotb.coroutine
	def check_count(self, count, setup, hold):
		cnt = yield self.get_count(Timer(setup), Timer(hold))

		if cnt != count:
			self.failure("unexpected count (received != " +
			             "expected): %d != %d" % (cnt, count))

		yield RisingEdge(self._entity.clk)


	@cocotb.coroutine
	def set_alarm(self, lapse, arm, load, setup_trigger, hold_trigger):
		yield self._drv.write_reg(TmrReg.ALRM, lapse << 2 | arm | load,
		                          setup_trigger, hold_trigger)


	@cocotb.coroutine
	def get_alarm(self, setup_trigger, hold_trigger):
		alrm = yield self._drv.read_reg(TmrReg.ALRM, setup_trigger,
		                                hold_trigger)
		raise ReturnValue((int(alrm) >> 2,
		                   (int(alrm) >> 1) & 0x1,
		                   int(alrm) & 0x1))


	@cocotb.coroutine
	def check_alarm(self, lapse, write_setup, write_hold, read_setup,
	               read_hold):
		wr = cocotb.fork(self.set_alarm(lapse, 0, 1,
		                                Timer(write_setup),
		                                Timer(write_hold)))
		(laps, arm, load) = yield self.get_alarm(Timer(read_setup),
		                                         Timer(read_hold))

		yield wr.join()

		if laps != lapse:
			self.failure("unexpected lapse (received != " +
			             "expected): %d != %d" % (laps, lapse))
		if arm != 0:
			self.failure("unexpected arm (received != " +
			             "expected): %d != 0" % (arm))
		if load != 0:
			self.failure("unexpected lapse (received != " +
			             "expected): %d != 0" % (load))

		yield RisingEdge(self._entity.clk)


	@cocotb.coroutine
	def get_status(self, setup_trigger, hold_trigger):
		stat = yield self._drv.read_reg(TmrReg.STAT, setup_trigger,
		                                hold_trigger)
		raise ReturnValue(((int(stat) >> 1) & 0x1, int(stat) & 0x1))


	@cocotb.coroutine
	def check_status(self, lapse, setup, hold):
		yield self.set_alarm(lapse, 0, 1, None,
		                     RisingEdge(self._entity.clk))

		for l in range(0, lapse):
			yield RisingEdge(self._entity.clk)

		(arm, alrm) = yield self.get_status(Timer(setup), Timer(hold))
		if arm != 0:
			self.failure("unexpected arm (received != " +
			             "expected): %d != 0" % (arm))
		if alrm != 1:
			self.failure("unexpected alarm state (received != " +
			             "expected): %d != 1" % (alrm))

		yield RisingEdge(self._entity.clk)


# TODO: check reset machinery !!

@cocotb.coroutine
def tmr_test_mode(dut, write_setup, write_hold, read_setup, read_hold):
	tb  = TmrRegsTestBench(dut, exit_on_fail)
	drv = tb.driver()

	yield tb.start(clk_t)

	for m in (TmrCtrlMode.CNT, TmrCtrlMode.SNGL, TmrCtrlMode.AUTO,
	          TmrCtrlMode.NONE) :
		yield tb.check_mode(m, write_setup, write_hold, read_setup,
		                    read_hold)

	yield RisingEdge(dut.clk)


@cocotb.coroutine
def tmr_test_count(dut, setup, hold):
	tb  = TmrRegsTestBench(dut, exit_on_fail)
	drv = tb.driver()

	yield tb.start(clk_t)

	yield tb.set_mode(TmrCtrlMode.CNT, None, RisingEdge(dut.clk))

        # One cycle eaten by set_mode(): that's why range starts from 1
	for c in range(1, 9):
		yield tb.check_count(c, setup, hold)

	yield RisingEdge(dut.clk)


@cocotb.coroutine
def tmr_test_lapse(dut, write_setup, write_hold, read_setup, read_hold):
	tb  = TmrRegsTestBench(dut, exit_on_fail)
	drv = tb.driver()

	yield tb.start(clk_t)

	for l in (0, 16, 32, 0x3fffffff):
		yield tb.check_alarm(l, write_setup, write_hold, read_setup,
		                     read_hold)

	yield RisingEdge(dut.clk)


@cocotb.coroutine
def tmr_test_alarm(dut, lapse, setup, hold):
	tb  = TmrRegsTestBench(dut, exit_on_fail)
	drv = tb.driver()

	dut.wreg = 0
	dut.wdat = 0
	dut.oreg = 0
	yield tb.start(clk_t)

	yield tb.set_mode(TmrCtrlMode.CNT, None, RisingEdge(dut.clk))

	yield RisingEdge(dut.clk)
	yield RisingEdge(dut.clk)
	yield tb.check_status(lapse, setup, hold)

	yield RisingEdge(dut.clk)
	yield RisingEdge(dut.clk)


seed(time())
clk_t = 2000
exit_on_fail=False

#fact = TestFactory(tmr_test_mode)
#fact.add_option("write_setup", [0, clk_t / 2])
#fact.add_option("write_hold",  [clk_t / 2, clk_t])
#fact.add_option("read_setup",  [clk_t, 3 * clk_t / 2])
#fact.add_option("read_hold",   [clk_t / 2, clk_t])
#fact.generate_tests()
#
#fact = TestFactory(tmr_test_count)
#fact.add_option("setup", [0, clk_t / 4])
#fact.add_option("hold",  [clk_t / 4, 3 * clk_t / 4])
#fact.generate_tests(prefix="partial_")
#
#fact = TestFactory(tmr_test_count)
#fact.add_option("setup", [0])
#fact.add_option("hold",  [clk_t])
#fact.generate_tests(prefix="continuous_")

#fact = TestFactory(tmr_test_lapse)
#fact.add_option("write_setup", [0, clk_t / 2])
#fact.add_option("write_hold",  [clk_t / 2, clk_t])
#fact.add_option("read_setup",  [clk_t, 3 * clk_t / 2])
#fact.add_option("read_hold",   [clk_t / 2, clk_t])
#fact.generate_tests()

fact = TestFactory(tmr_test_alarm)
#fact.add_option("setup", [0, clk_t / 2])
#fact.add_option("hold",  [clk_t / 2, clk_t])
fact.add_option("lapse", [4])
fact.add_option("setup", [0])
fact.add_option("hold",  [clk_t])
fact.generate_tests()
