import cocotb
from logging import getLogger
from cocotb.monitors import BusMonitor
from cocotb.triggers import ReadOnly
from cocotb.result import TestFailure

class BaseMonitor(BusMonitor):

	def __init__(self, entity, clock, scoreboard):
		BusMonitor.__init__(self, entity, "", clock)

		self._expected = None
		self._log = getLogger(scoreboard.log.name + '.' + self.name)
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
				raise TestFailure(("Received unexpected ",
				                   "transaction"))

		self._expected = None


	@cocotb.coroutine
	def expect(self, expected):
		assert(self._expected == None)
		self._expected = expected

		yield self.wait_for_recv()


	@cocotb.coroutine
	def _monitor_recv(self):
		while True:
			yield ReadOnly()

			# build transaction from the entire list of declared
			# signals
			transaction = {}
			for sig in self._signals:
				transaction[sig] = getattr(self.bus, sig)

			self._recv(transaction)
