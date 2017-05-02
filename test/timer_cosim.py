import cocotb
from cocotb.triggers import FallingEdge
from cocotb.triggers import ClockCycles
from cocotb.triggers import ReadOnly
from cocotb.clock import Clock
from cocotb.result import TestFailure

def tmr_check_sig(dut, mode, load, ack_int, req_int, count):
	if isinstance(mode, str):
		if str(dut.mode) != mode:
			raise TestFailure("invalid mode (%s)" % str(dut.mode))
	else:
		if int(dut.mode) != mode:
			raise TestFailure("invalid mode (%d)" % int(dut.mode))

	if isinstance(load, str):
		if str(dut.load) != load:
			raise TestFailure("invalid load (%s)" % str(dut.load))
	else:
		if int(dut.load) != load:
			raise TestFailure("invalid load (%d)" % int(dut.load))

	if isinstance(ack_int, str):
		if str(dut.ack_int) != ack_int:
			raise TestFailure("invalid ack_int (%s)" % str(dut.ack_int))
	else:
		if int(dut.ack_int) != ack_int:
			raise TestFailure("invalid ack_int (%d)" % int(dut.ack_int))

	if int(dut.req_int) != req_int:
		raise TestFailure("invalid req_int (%d)" % int(dut.req_int))

	if int(dut.count) != count:
		raise TestFailure("invalid count (0x%x)" % int(dut.count))


@cocotb.coroutine
def tmr_check_cnt(dut):
	"""Time counter logic testbench"""

	yield ClockCycles(dut.clk, 1)
	tmr_check_sig(dut, "UU", "UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU", "U", 0, 0)

	yield ClockCycles(dut.clk, 1)
	dut.mode = 0
	yield ClockCycles(dut.clk, 1)
	tmr_check_sig(dut, 0, "UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU", "U", 0, 0)

	yield FallingEdge(dut.clk)
	dut.mode = 1
	for c in range(10):
		yield ClockCycles(dut.clk, 1)
		tmr_check_sig(dut, 1, "UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU", "U", 0,
		              c)

	dut.mode = 0
	yield ReadOnly()
	tmr_check_sig(dut, 0, "UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU", "U", 0,
	              c + 1)

	yield ClockCycles(dut.clk, 2)
	tmr_check_sig(dut, 0, "UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU", "U", 0,
	              c + 1)


@cocotb.test()
def tmr_run(dut):
	cocotb.fork(Clock(dut.clk, 2000).start())

	yield tmr_check_cnt(dut)
