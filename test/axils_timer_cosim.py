import random
import time
import cocotb
import logging

from cocotb.utils import get_sim_time
from cocotb.binary import BinaryValue
from cocotb.clock import Clock
from cocotb.monitors import BusMonitor
from cocotb.scoreboard import Scoreboard
from cocotb.triggers import Timer
from cocotb.triggers import RisingEdge
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
		                  "stor0_a", "stor1_a", "stor2_a" ]
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


	def failure(self, message):
		self._scoreboard.errors += 1
		if self._scoreboard._imm:
			raise TestFailure(message)
		else:
			self._log.error(message)


	def compare(self, transaction):
		if self._expected == None:
			return

		self._log.debug("Checking " + self._expected["name"] + "...")

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

			self._scoreboard.errors += 1
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
			yield Timer(clk_t / 16)
			#yield Timer(1)

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
		        "bready"  : BinaryValue(0),
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
	def _wrxact_addr_phase(self, addr, delay):
		if (delay):
		    yield Timer(delay)

		# address phase
		self._entity.awvalid = 1
		self._entity.awaddr  = addr

		tmout = get_sim_time() + (100 * clk_t)
		while True:
			if int(self._entity.awready) == 1:
				break
			if get_sim_time() >= tmout:
				self._omon.failure("Timeout while waiting for" \
				                   " awready assertion")
				return
			yield Timer(clk_t / 16)

		yield RisingEdge(self._entity.aclk)

		self._entity.awvalid = 0


	@cocotb.coroutine
	def _wrxact_data_phase(self, data, delay):
		if (delay):
		    yield Timer(delay)

		# data phase
		self._entity.wvalid = 1
		self._entity.wdata  = data

		tmout = get_sim_time() + (100 * clk_t)
		while True:
			if int(self._entity.wready) == 1:
				break
			if get_sim_time() >= tmout:
				self._omon.failure("Timeout while waiting for" \
				                   " wready assertion")
				return
			yield Timer(clk_t / 16)

		yield RisingEdge(self._entity.aclk)

		self._entity.wvalid = 0


	@cocotb.coroutine
	def _wrxact_resp_phase(self, delay):
		if (delay):
		    yield Timer(delay)

		self._entity.bready = 1

		tmout = get_sim_time() + (100 * clk_t)
		while True:
			if int(self._entity.bvalid) == 1:
				break
			if get_sim_time() >= tmout:
				self._omon.failure("Timeout while waiting for" \
				                   " bvalid assertion")
				return
			yield Timer(clk_t / 16)

		yield RisingEdge(self._entity.aclk)

		self._entity.bready = 0


	@cocotb.coroutine
	def wrxact(self, addr, addr_delay, data, data_delay, resp, resp_delay):
		# validate preconditions
		exp = { "name"    : "write transaction preconditions",
		        "areset_n": BinaryValue(1),
		        "awvalid" : BinaryValue(0),
		        "awready" : BinaryValue(1),
		        "wvalid"  : BinaryValue(0),
		        "wready"  : BinaryValue(1),
		        "bvalid"  : BinaryValue(0),
		        "bready"  : BinaryValue(0)
		}
		yield self.expect(exp)

		addr = BinaryValue(addr, bits=32, bigEndian=False)
		data = BinaryValue(data, bits=32)

		addr_phase = cocotb.fork(self._wrxact_addr_phase(addr,
		                                                 addr_delay))
		data_phase = cocotb.fork(self._wrxact_data_phase(data,
		                                                 data_delay))
		yield self._wrxact_resp_phase(resp_delay)
		yield addr_phase.join()
		yield data_phase.join()
                
		# validate phases postconditions
		exp = { "areset_n": BinaryValue(1),
		        "awvalid" : BinaryValue(0),
		        "awready" : BinaryValue(1),
		        "awaddr"  : addr,
		        "wvalid"  : BinaryValue(0),
		        "wready"  : BinaryValue(1),
		        "wdata"   : data,
		        "bvalid"  : BinaryValue(0),
		        "bready"  : BinaryValue(0),
                        "bresp"   : BinaryValue(resp, bits=2),
                        "stor0_a" : self._entity.stor0_a,
		        "stor1_a" : self._entity.stor1_a,
		        "stor2_a" : self._entity.stor2_a
		}
		if resp == 0:
			exp["name"]  = "valid write transaction postconditions"
			stor         = "stor" + str(int(addr) / 4) + "_a"
			exp[stor]    = data
		else:
			exp["name"]  = "invalid write transaction " \
			               "postconditions"
		yield self.expect(exp)


	@cocotb.coroutine
	def _rdxact_addr_phase(self, addr, delay):
		if (delay):
		    yield Timer(delay)

		# address phase
		self._entity.arvalid = 1
		self._entity.araddr  = addr

		tmout = get_sim_time() + (100 * clk_t)
		while True:
			if int(self._entity.arready) == 1:
				break
			if get_sim_time() >= tmout:
				self._omon.failure("Timeout while waiting for" \
				                   " arready assertion")
				return
			yield Timer(clk_t / 16)

		yield RisingEdge(self._entity.aclk)

		self._entity.arvalid = 0


	@cocotb.coroutine
	def _rdxact_data_phase(self, output, delay):
		if (delay):
		    yield Timer(delay)

		# data phase
		self._entity.rready = 1

		tmout = get_sim_time() + (100 * clk_t)
		while True:
			if int(self._entity.rvalid) == 1:
				break
			if get_sim_time() >= tmout:
				self._omon.failure("Timeout while waiting for" \
				                   " rvalid assertion")
				return
			yield Timer(clk_t / 16)

		output["data"] = self._entity.rdata
		output["resp"] = self._entity.rresp
                
		yield RisingEdge(self._entity.aclk)

		self._entity.rready = 0


	@cocotb.coroutine
	def rdxact(self, addr, addr_delay, data, resp, data_delay):
		# validate preconditions
		exp = { "name"    : "read transaction preconditions",
		        "areset_n": BinaryValue(1),
		        "arvalid" : BinaryValue(0),
		        "arready" : BinaryValue(1),
		        "rvalid"  : BinaryValue(0),
		        "rready"  : BinaryValue(0)
		}
		yield self.expect(exp)

		addr = BinaryValue(addr, bits=32, bigEndian=False)
		res = { }

		addr_phase = cocotb.fork(self._rdxact_addr_phase(addr,
		                                                 addr_delay))
		yield self._rdxact_data_phase(res, data_delay)
		yield addr_phase.join()
                
		# validate phases postconditions
		exp = { "areset_n": BinaryValue(1),
		        "arvalid" : BinaryValue(0),
		        "arready" : BinaryValue(1),
		        "araddr"  : addr,
		        "rvalid"  : BinaryValue(0),
		        "rready"  : BinaryValue(1),
		        "rresp"   : BinaryValue(resp, bits=2)
		}
		if resp == 0:
			exp["name"]  = "valid read transaction postconditions"
			exp["rdata"] = BinaryValue(data, bits=32)
		else:
			exp["name"]  = "invalid read transaction postconditions"
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
def axils_test_wrxact(dut, addr, resp, addr_delay, data_delay, resp_delay,
                      post_cycles):
	""" AXI lite slave write transaction"""
	tb = AxilSlaveTB(dut, exit_on_fail)
	tb = AxilSlaveTB(dut, exit_on_fail)

	yield tb.start(clk_t)

	data = random.getrandbits(32)

	for t in range(0, xact_nr):
		yield tb.wrxact(addr, addr_delay, data, data_delay, resp,
		                resp_delay)
		data = data + 1
		for e in range(0, post_cycles):
			yield RisingEdge(dut.aclk)


@cocotb.coroutine
def axils_test_valid_rdxact(dut, addr_delay, data_delay, post_cycles):
	""" AXI lite slave read transaction"""
	tb = AxilSlaveTB(dut, exit_on_fail)
	tb = AxilSlaveTB(dut, exit_on_fail)

	yield tb.start(clk_t)

	for t in range(0, xact_nr - 1):
		data = (random.getrandbits(32),
		        random.getrandbits(32),
		        random.getrandbits(32))

		yield tb.wrxact(0, 0, data[0], 0, 0, 0);
		yield tb.wrxact(4, 0, data[1], 0, 0, 0);
		yield tb.wrxact(8, 0, data[2], 0, 0, 0);
		for e in range(0, post_cycles):
			yield RisingEdge(dut.aclk)

		yield tb.rdxact(0, 0, data[0], 0, 0)
		yield tb.rdxact(4, 0, data[1], 0, 0)
		yield tb.rdxact(8, 0, data[2], 0, 0)
		for e in range(0, post_cycles):
			yield RisingEdge(dut.aclk)


@cocotb.coroutine
def axils_test_invalid_rdxact(dut, addr_delay, data_delay, post_cycles):
	""" AXI lite slave read transaction"""
	tb = AxilSlaveTB(dut, exit_on_fail)
	tb = AxilSlaveTB(dut, exit_on_fail)

	yield tb.start(clk_t)

	for t in range(0, xact_nr - 1):
		yield tb.rdxact(14, 0, random.getrandbits(32), 3, 0)
		for e in range(0, post_cycles):
			yield RisingEdge(dut.aclk)

random.seed(time.time())
clk_t = 2000
xact_nr = 3
exit_on_fail=True

fact = TestFactory(axils_test_reset)
fact.add_option("clk_delay",  [clk_t / 2, clk_t, 3 * clk_t / 2])
fact.add_option("reset_hold", [clk_t / 4, clk_t / 2, clk_t / 3, clk_t])
fact.add_option("post_delay", [clk_t / 4, clk_t / 2, clk_t / 3, clk_t])
fact.generate_tests()

fact = TestFactory(axils_test_wrxact)
fact.add_option("addr",        [0, 1, 4, 6, 8, 11])
fact.add_option("addr_delay",  [0, clk_t / 2, 3 * clk_t / 4, 5 * clk_t / 4])
fact.add_option("data_delay",  [0, clk_t / 2, 3 * clk_t / 4, 5 * clk_t / 4])
fact.add_option("resp_delay",  [0, clk_t / 2, 3 * clk_t / 4, 5 * clk_t / 4])
fact.add_option("resp",        [0])
fact.add_option("post_cycles", [0, 1, 4])
fact.generate_tests("valid_")

fact = TestFactory(axils_test_wrxact)
fact.add_option("addr",        [12])
fact.add_option("addr_delay",  [0, clk_t / 2, 3 * clk_t / 4, 5 * clk_t / 4])
fact.add_option("data_delay",  [0, clk_t / 2, 3 * clk_t / 4, 5 * clk_t / 4])
fact.add_option("resp_delay",  [0, clk_t / 2, 3 * clk_t / 4, 5 * clk_t / 4])
fact.add_option("resp",        [3])
fact.add_option("post_cycles", [0, 1, 4])
fact.generate_tests("invalid_")

fact = TestFactory(axils_test_valid_rdxact)
fact.add_option("addr_delay",  [0, clk_t / 2, 3 * clk_t / 4, 5 * clk_t / 4])
fact.add_option("data_delay",  [0, clk_t / 2, 3 * clk_t / 4, 5 * clk_t / 4])
fact.add_option("post_cycles", [0, 1, 4])
fact.generate_tests()

fact = TestFactory(axils_test_invalid_rdxact)
fact.add_option("addr_delay",  [0, clk_t / 2, 3 * clk_t / 4, 5 * clk_t / 4])
fact.add_option("data_delay",  [0, clk_t / 2, 3 * clk_t / 4, 5 * clk_t / 4])
fact.add_option("post_cycles", [0, 1, 4])
fact.generate_tests()
