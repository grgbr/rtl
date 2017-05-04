import cocotb
from cocotb.triggers import RisingEdge, Timer, ReadOnly
from cocotb.bus import Bus
from cocotb.result import ReturnValue
from cocotb.binary import BinaryValue

class AxiError(Exception):
	_errstr = [ "okay", "exclusive access okay", "slave error",
	            "decode error" ]
	_dir    = [ "write to", "read from" ]
        
	def __init__(self, msg, read, addr, resp):
		self._msg  = msg + ": " + self._dir[int(read)]
		self._addr = addr
		self._resp = resp

        def __str__(self): return "%s @0x%x failed with code %x (%s)".\
			format(self._msg, self._addr, self._resp,
			       self._errstr[self._resp])


class Axi4lMaster():
	"""
	AXI4-Lite Master
	"""
        
	def __init__(self, entity, clock, bits):
		self._entity = entity
		self._clk = clock
		self._bits = bits


	@cocotb.coroutine
	def reset(self, hold_delay=0):
		# At reset assertion time, master MUST drive arvalid, awvalid
		# and awvalid to low level in addition to areset_n.
		self._entity.areset_n <= 0
		self._entity.arvalid  <= 0
		self._entity.awvalid  <= 0
		self._entity.wvalid   <= 0

		yield Timer(hold_delay)


	@cocotb.coroutine
        def dereset(self):
		self._entity.areset_n = 1

		yield RisingEdge(self._clk)


	@cocotb.coroutine
	def _wrxact_addr_phase(self, addr, delay):
		if (delay):
			yield Timer(delay)

		# address phase
		self._entity.awvalid = 1
		self._entity.awaddr  = addr

		while True:
			if int(self._entity.awready) == 1:
				break
			yield ReadOnly()
		yield RisingEdge(self._clk)

		self._entity.awvalid = 0


	@cocotb.coroutine
	def _wrxact_data_phase(self, data, delay):
		if (delay):
			yield Timer(delay)

		# data phase
		self._entity.wvalid = 1
		self._entity.wdata  = data

		while True:
			yield ReadOnly()
			if int(self._entity.wready) == 1:
				break
		yield RisingEdge(self._clk)

		self._entity.wvalid = 0


	@cocotb.coroutine
	def _wrxact_resp_phase(self, addr, delay):
		if (delay):
			yield Timer(delay)

		self._entity.bready = 1

		while True:
			yield ReadOnly()
			if int(self._entity.bvalid) == 1:
				break
		yield RisingEdge(self._clk)

		self._entity.bready = 0


	@cocotb.coroutine
	def wrxact(self, addr, data, addr_delay=0, data_delay=0, resp_delay=0):
		addr = BinaryValue(addr, bits=self._bits, bigEndian=False)
		data = BinaryValue(data, bits=self._bits, bigEndian=False)

		addr_phase = cocotb.fork(self._wrxact_addr_phase(addr,
		                                                 addr_delay))
		data_phase = cocotb.fork(self._wrxact_data_phase(data,
		                                                 data_delay))
		resp_phase = cocotb.fork(self._wrxact_resp_phase(addr,
		                                                 resp_delay))

		yield addr_phase.join()
		yield data_phase.join()
		yield resp_phase.join()

		resp = self._entity.bresp
		if int(resp):
			raise AxiError("axi4 lite master", false, int(addr),
			               resp)


	@cocotb.coroutine
	def _rdxact_addr_phase(self, addr, delay):
		if (delay):
			yield Timer(delay)

		# address phase
		self._entity.arvalid = 1
		self._entity.araddr  = addr

		while True:
			yield ReadOnly()
			if int(self._entity.arready) == 1:
				break
		yield RisingEdge(self._clk)

		self._entity.arvalid = 0


	@cocotb.coroutine
	def _rdxact_data_phase(self, delay):
		if (delay):
			yield Timer(delay)

		# data phase
		self._entity.rready = 1

		while True:
			yield ReadOnly()
			if int(self._entity.rvalid) == 1:
				break
		yield RisingEdge(self._clk)

		self._entity.rready = 0


	@cocotb.coroutine
	def rdxact(self, addr, addr_delay=0, data_delay=0, resp_delay=0):
		addr = BinaryValue(addr, bits=self._bits, bigEndian=False)

		addr_phase = cocotb.fork(self._rdxact_addr_phase(addr,
		                                                 addr_delay))
		data_phase = cocotb.fork(self._rdxact_data_phase(data_delay))

		yield addr_phase.join()
		yield data_phase.join()

		resp = self._entity.rresp
		if int(resp):
			raise AxiError("axi4 lite master", True, int(addr),
			               resp)

		raise ReturnValue(self._entity.rdata)
