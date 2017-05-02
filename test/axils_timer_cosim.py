import random
import time
import cocotb
import logging

from cocotb.binary import BinaryValue

import simulator
from cocotb.handle import SimHandle
from cocotb.monitors import BusMonitor
from cocotb.scoreboard import Scoreboard
from cocotb.triggers import Timer
from cocotb.triggers import FallingEdge
from cocotb.triggers import RisingEdge
from cocotb.triggers import ClockCycles
from cocotb.triggers import ReadOnly
from cocotb.triggers import ReadWrite
from cocotb.triggers import NextTimeStep
from cocotb.triggers import Lock
from cocotb.clock import Clock
from cocotb.result import TestFailure
from cocotb.regression import TestFactory

class AxilSlaveBusMonitor(BusMonitor):
	"""
	AXI lite slave bus monitor
	"""
	
	def __init__(self, entity, scoreboard):
		# declare signals to be monitored
		self._signals = [ "awready", "awvalid", "awaddr", "wready",
		                  "wvalid", "wdata", "bvalid", "bresp",
		                  "arready", "rvalid", "rdata", "rresp",
		                  "oreg0", "oreg1", "oreg2" ]
		BusMonitor.__init__(self, entity, "",
		                    entity.aclk, reset_n=entity.areset_n)

		self._expected = None
		self._log = logging.getLogger(scoreboard.log.name +
		                              '.' +
		                              self.name)
		self._scoreboard = scoreboard
		scoreboard.add_interface(self, [], compare_fn=self.compare)


	def _print_expected(self, key, value):
		try:
			self._log.info("    %s: %s (0x%x)",
			               key, str(value), int(value))
		except :
			self._log.info("    %s: %s", key, str(value))


	def _print_diff(self, key, value, expect):
		try:
			self._log.info("    %s: %s != %s (0x%x != 0x%x)",
			               key, str(expect), str(value),
			               int(expect), int(value))
		except :
			self._log.info("    %s: %s != %s",
			               key, str(expect), str(value))


	def compare(self, transaction):
		if self._expected == None:
			return

		self._log.info("Checking " + self._expected["name"] + "...")

		wrong = False
		# validate transaction against signals present into expected
		# output
		for k,v in transaction.items():
			if (self._expected.has_key(k) and
			    (k != "name") and
			    (not str(v) == str(self._expected[k]))):
				wrong = True
				break

		if wrong:
			self._scoreboard.errors += 1
			
			self._log.error("Received unexpected %s" %
			                (self._expected.has_key("name") == True
			                 and self._expected["name"] or
			                 "anonymous transaction"))

			self._log.info("Expected:")
			for k, v in sorted(self._expected.items()):
				if k != "name":
					self._print_expected(k, v)

			self._log.info("Received:")
			for k, v in sorted(transaction.items()):
				if k != "name":
					self._print_expected(k, v)

			self._log.info("Diff:")
			for k, v in sorted(transaction.items()):
				if ((k == "name") or
				    (not self._expected.has_key(k))):
					continue
				if not str(v) == str(self._expected[k]):
					self._print_diff(k, v,
					                 self._expected[k])

			if self._scoreboard._imm:
				raise TestFailure("Received unexpected transaction")

		self._expected = None


	@cocotb.coroutine
	def expect(self, expected):
		assert(self._expected == None)
		self._expected = expected

		yield self.wait_for_recv()


	@cocotb.coroutine
	def _monitor_recv(self):
		while True:
			#yield Timer(clk_t / 10)
			yield Timer(1)

			# build transaction from the entire list of declared
			# signals
			transaction = {}
			for sig in self._signals:
				transaction[sig] = getattr(self.bus, sig)

			self._recv(transaction)


class AxilSlaveTB:
	"""
	AXI lite slave test bench
	"""
	
	def __init__(self, entity, fail_immediately):
		self._entity = entity
		self._sbrd = Scoreboard(entity,
		                        fail_immediately=fail_immediately)
		self._omon = AxilSlaveBusMonitor(entity, self._sbrd)


	@cocotb.coroutine
        def _toggle_clock(self, period, start_delay):
                self._entity.aclk = 0
		yield Timer(start_delay)
		yield Clock(self._entity.aclk, period).start()


	@cocotb.coroutine
	def expect(self, expected):
		yield self._omon.expect(expected)


	def start_clock(self, period, start_delay):
		return cocotb.fork(self._toggle_clock(clk_t, start_delay))


	@cocotb.coroutine
	def assert_reset(self, hold_delay):
		# At reset assertion time, master MUST drive arvalid, awvalid
		# and awvalid to low level in addition to areset_n.
		self._entity.arvalid  = 0
		self._entity.awvalid  = 0
		self._entity.wvalid   = 0
		self._entity.areset_n = 0

		yield Timer(hold_delay)

		# While reset asserted, slave MUST drive rvalid and bvalid LOW.
		# All other signals can be driven to any value.
		exp = {
		        "name"    : "reset assertion",
		        # check slave inputs are properly applied
		        "arvalid" : BinaryValue(0),
		        "awvalid" : BinaryValue(0),
		        "wvalid"  : BinaryValue(0),
		        "areset_n": BinaryValue(0),
		        # check slave properly drives its outputs
		        "bvalid"  : BinaryValue(0),
		        "rvalid"  : BinaryValue(0)
		}
		yield self.expect(exp)


	@cocotb.coroutine
	def deassert_reset(self, post_delay):
		self._entity.areset_n = 1

		yield Timer(post_delay)

		# While reset asserted, slave MUST drive rvalid and bvalid LOW.
		# All other signals can be driven to any value.
		exp = {
		        "name"    : "reset deassertion",
		        # check slave inputs are properly applied
		        "arvalid" : BinaryValue(0),
		        "awvalid" : BinaryValue(0),
		        "wvalid"  : BinaryValue(0),
		        "areset_n": BinaryValue(1),
		        # check slave properly drives its outputs
		        "bvalid"  : BinaryValue(0),
		        "rvalid"  : BinaryValue(0)
		}
		yield self.expect(exp)

		yield RisingEdge(self._entity.aclk)

		# At clock rising edge following reset deassertion, slave SHOULD
                # drive awready and wready high. bvalid and rvalid MUST stay
                # low.
		exp = {
		        "name"    : "synchronized reset deassertion",
		        # check slave inputs are properly applied
		        "areset_n": BinaryValue(1),
		        # check slave properly drives its outputs
		        "awready" : BinaryValue(1),
		        "wready"  : BinaryValue(1),
		        "bvalid"  : BinaryValue(0),
		        "rvalid"  : BinaryValue(0)
		}
		yield self.expect(exp)


	@cocotb.coroutine
	def start(self, period):
		self.start_clock(period, period)
		yield Timer(period / 2)
		yield self.assert_reset(3 * period / 4)
		yield self.deassert_reset(period / 4)


	@cocotb.coroutine
	def axils_wrxact_addr_phase(self, addr, delay):
		"""
		AXI lite slave write transaction address phase
		"""

		addr = BinaryValue(addr, bits=32, bigEndian=False)

		# validate preconditions
		exp = { "name"    : "write transaction address phase "
                                    "preconditions",
		        "areset_n": BinaryValue(1),
		        "awvalid" : BinaryValue(0),
		        "awready" : BinaryValue(1),
		        "bvalid"  : BinaryValue(0) }
		yield self.expect(exp)
                
		# address phase
		self._entity.awvalid = 1
		self._entity.awaddr  = addr
		self._entity.bready  = 1

		if (delay):
		    yield Timer(delay)

		exp = { "name"    : "write transaction address phase "
                                    "postconditions",
		        "areset_n": BinaryValue(1),
		        "awvalid" : BinaryValue(1),
		        "awready" : BinaryValue(1),
		        "awaddr"  : addr,
		        "bready"  : BinaryValue(1) }
		yield self.expect(exp)


	@cocotb.coroutine
	def axils_wrxact_data_phase(self, data, delay):
		"""
		AXI lite slave write transaction data phase
		"""

		data = BinaryValue(data, bits=32)

		# validate preconditions
		exp = { "name"    : "write transaction data phase "
                                    "preconditions",
		        "areset_n": BinaryValue(1),
		        "wvalid"  : BinaryValue(0),
		        "wready"  : BinaryValue(1),
		        "bvalid"  : BinaryValue(0) }
		yield self.expect(exp)
                
		# data phase
		self._entity.wvalid = 1
		self._entity.wdata  = data
		self._entity.bready = 1
                
		if (delay):
		    yield Timer(delay)

		exp = { "name"    : "write transaction data phase "
                                    "postconditions",
		        "areset_n": BinaryValue(1),
		        "wvalid"  : BinaryValue(1),
		        "wready"  : BinaryValue(1),
		        "wdata"   : data,
		        "bready"  : BinaryValue(1) }
		yield self.expect(exp)


	@cocotb.coroutine
        def axils_wrxact_resp_phase(self, resp):
		"""
		AXI lite slave write transaction response phase
		"""
		
		# validate preconditions
		exp = { "name"    : "write transaction response phase "
                                    "preconditions",
		        "areset_n": BinaryValue(1),
		        "awready" : BinaryValue(1),
		        "wready"  : BinaryValue(1),
		        "bvalid"  : BinaryValue(1),
		        "bready"  : BinaryValue(1) }
		yield self.expect(exp)

                # response phase: available at next clock rising edge
		yield RisingEdge(self._entity.aclk)

		self._entity.awvalid = 0
		self._entity.wvalid  = 0
		self._entity.bready  = 0

		exp = { "name"    : "write transaction response phase "
                                    "postconditions",
		        "areset_n": BinaryValue(1),
		        "awvalid" : BinaryValue(0),
		        "awready" : BinaryValue(0),
		        "wvalid"  : BinaryValue(0),
		        "wready"  : BinaryValue(0),
		        "bvalid"  : BinaryValue(1),
		        "bready"  : BinaryValue(1),
		        "bresp"   : BinaryValue(resp, bits=2) }
		yield self.expect(exp)


@cocotb.coroutine
def axils_test_reset(dut, clk_delay, reset_hold, post_delay):
	""" AXI lite slave asynchronous reset / synchronous de-reset"""
	tb = AxilSlaveTB(dut, exit_on_fail)
	tb = AxilSlaveTB(dut, exit_on_fail)

	tb.start_clock(clk_t, clk_delay)
	yield Timer(clk_t)
	yield tb.assert_reset(reset_hold)
	yield tb.deassert_reset(post_delay)


@cocotb.coroutine
def axils_test_wrxact(dut, addr, resp):
	""" AXI lite slave write transaction"""
	tb = AxilSlaveTB(dut, exit_on_fail)
	tb = AxilSlaveTB(dut, exit_on_fail)

	yield tb.start(clk_t)

	data = random.getrandbits(32)

	yield tb.axils_wrxact_addr_phase(addr, clk_t / 4)
	yield tb.axils_wrxact_data_phase(data, clk_t / 4)
	yield tb.axils_wrxact_resp_phase(resp)

	exp = { "areset_n": BinaryValue(1),
	        "awvalid" : BinaryValue(0),
	        "awready" : BinaryValue(0),
	        "wvalid"  : BinaryValue(0),
	        "wready"  : BinaryValue(0),
	        "bvalid"  : BinaryValue(1),
	        "bready"  : BinaryValue(0),
		"bresp"   : BinaryValue(resp, bits=2) }
	if resp == 0:
		oreg = "oreg" + str(addr / 4)
		exp["name"]  = "valid write transaction phase final " \
		               "postconditions"
		exp["oreg0"] = dut.oreg0
		exp["oreg1"] = dut.oreg1
		exp["oreg2"] = dut.oreg2
		exp[oreg]    = BinaryValue(data, bits=32)
	else:
		exp["name"]  = "invalid write transaction phase final " \
		               "postconditions"
	yield tb.expect(exp)
	yield RisingEdge(dut.aclk)



random.seed(time.time())
clk_t = 2000
exit_on_fail=False

#fact = TestFactory(axils_test_reset)
#fact.add_option("clk_delay",     [clk_t / 2, clk_t, 3 * clk_t / 2])
#fact.add_option("reset_hold",    [clk_t / 4, clk_t / 2, clk_t / 3, clk_t])
#fact.add_option("post_delay",    [clk_t / 4, clk_t / 2, clk_t / 3, clk_t])
#fact.generate_tests()

fact = TestFactory(axils_test_wrxact)
fact.add_option("addr", [0, 1, 4, 6, 8, 9])
fact.add_option("resp", [0])
fact.generate_tests("valid_")

fact = TestFactory(axils_test_wrxact)
fact.add_option("addr", [16])
fact.add_option("resp", [3])
fact.generate_tests("invalid_")

#@cocotb.coroutine
#def axils_addr_before_data_wrxact(testbench, dut, addr):
#	"""
#	AXI lite slave write transaction with address phase ahead of data phase
#	"""
#
#	data = BinaryValue(random.getrandbits(32), bits=32)
#	
#	# validate preconditions
#	expected = { "name"   : "precondition",
#	             "awready": BinaryValue(1),
#	             "wready" : BinaryValue(1),
#	             "bvalid" : BinaryValue(0) }
#	testbench.expect(expected)
#	yield RisingEdge(dut.aclk)
#	
#	# address phase
#	yield Timer(clk_t / 4)
#	expected = { "name"   : "address phase",
#	             "awvalid": BinaryValue(1),
#	             "awready": BinaryValue(0),
#	             "wvalid" : BinaryValue(0),
#	             "wready" : BinaryValue(1),
#	             "bvalid" : BinaryValue(0),
#	             "bready" : BinaryValue(0),
#	             "oreg0"  : dut.oreg0,
#	             "oreg1"  : dut.oreg1,
#	             "oreg2"  : dut.oreg2 }
#	dut.awvalid = 1
#	dut.awaddr = addr
#	dut.wvalid = 0
#	dut.bready = 0
#	testbench.expect(expected)
#	yield RisingEdge(dut.aclk)
#
#	# data phase
#	yield Timer(clk_t / 4)
#	expected = { "name"   : "data phase",
#	             "awvalid": BinaryValue(0),
#	             "awready": BinaryValue(0),
#	             "wvalid" : BinaryValue(1),
#	             "wdata"  : data,
#	             "wready" : BinaryValue(0),
#	             "bvalid" : BinaryValue(1),
#	             "bready" : BinaryValue(1),
#	             "bresp"  : BinaryValue(0, bits=2),
#	             "oreg0"  : dut.oreg0,
#	             "oreg1"  : dut.oreg1,
#	             "oreg2"  : dut.oreg2 }
#	dut.awvalid = 0
#	dut.wvalid = 1
#	dut.wdata = data
#	dut.bready = 1
#	testbench.expect(expected)
#	yield RisingEdge(dut.aclk)
#	
#	# response phase
#	yield Timer(clk_t / 4)
#	expected = { "name"   : "response phase",
#	             "awvalid": BinaryValue(0),
#	             "awready": BinaryValue(1),
#	             "wvalid" : BinaryValue(0),
#	             "wready" : BinaryValue(1),
#	             "bvalid" : BinaryValue(1),
#	             "bready" : BinaryValue(0),
#	             "bresp"  : BinaryValue(0, bits=2),
#	             "oreg0"  : dut.oreg0,
#	             "oreg1"  : dut.oreg1,
#	             "oreg2"  : dut.oreg2 }
#	oreg = "oreg" + str(addr / 4)
#	expected[oreg] = data
#	dut.wvalid = 0
#	dut.bready = 0
#	testbench.expect(expected)
#	yield Timer(clk_t / 2)
#	
#	# postconditions
#	expected = { "name"   : "postconditions",
#	             "awready": BinaryValue(1),
#	             "wready" : BinaryValue(1),
#	             "bvalid" : BinaryValue(0) }
#	expected[oreg] = data
#	testbench.expect(expected)
#	yield RisingEdge(dut.aclk)
#
#
#@cocotb.coroutine
#def axils_simultaneous_addr_data_wrxact(testbench, dut, addr):
#	"""
#	AXI lite slave write transaction with simultaneous address / data
#	phase handshakes
#	"""
#	oreg = "oreg" + str(addr / 4)
#	dut.wdata = random.getrandbits(32)
#
#	yield Timer(clk_t / 4)
#	expected = { "awvalid": BinaryValue(1),
#	             "awready": BinaryValue(0),
#	             "wvalid" : BinaryValue(1),
#	             "wready" : BinaryValue(0),
#	             "bvalid" : BinaryValue(1),
#	             "bresp"  : BinaryValue(0, bits=2),
#	             "oreg0"  : dut.oreg0,
#	             "oreg1"  : dut.oreg1,
#	             "oreg2"  : dut.oreg2 }
#	expected[oreg] = BinaryValue(random.getrandbits(32), bits=32)
#	
#	testbench.expect(expected)
#	dut.awvalid = 1
#	dut.awaddr = addr
#	dut.wvalid = 1
#	dut.wdata = expected[oreg]
#	dut.bready = 1
#	yield RisingEdge(dut.aclk)
#	yield RisingEdge(dut.aclk)


#@cocotb.test()
#def axils_test_addr_before_data_wrxact(dut):
#	"""
#	AXI lite slave write transaction with simultaneous address / data
#	phase handshakes
#	"""
#	tb = AxilSlaveTB(dut, exit_on_fail)
#        
#	yield tb.start(clk_t)
#
#	yield axils_addr_before_data_wrxact(tb, dut, 4)


#@cocotb.test()
#def axils_test_simultaneous_addr_data_wrxact(dut):
#	"""
#	AXI lite slave write transaction with simultaneous address / data
#	phase handshakes
#	"""
#	tb = AxilSlaveTB(dut, exit_on_fail)
#        
#	yield tb.reset()
#
#	yield axils_simultaneous_addr_data_wrxact(tb, dut, 8)
