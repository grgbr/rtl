--------------------------------------------------------------------------------
-- AXI4-lite compliant slave implementation
--
-- Notes:
--   * no support for data interleaving, all transactions are of burst length 1
--   * all data accesses use the full width of the data bus
--   * all accesses are Non-modifiable, Non-bufferable
--   * exclusive accesses are not supported.
--   * supports multiple outstanding transactions, but slave can restrict this
--     by the appropriate use of the handshake signals.
--   * 32-bits or 64-bits fixed DATA bus width, all transactions are the same
--     width as the data bus
--   * following write strobes support options permitted for slaves:
--      * full use of write strobes
--      * ignore write strobes (treat write accesses as using full data bus
--        width)
--      * detect unsupported write strobe combinations and provide an error
--        response
--     slave providing memory access must fully support write strobes ; others
--     might support a more limited write strobe option.
--   * RRESP, BRESP: EXOKAY not supported for READ DATA and WRITE RESPONSE
--     channels
--   * no support for AXI IDs, i.e. all transactions must be in order, all
--     accesses use a single fixed ID value
--   * however, slave can optionally support AXI ID signals, so that it can be
--     connected to a full AXI interface without modification, i.e. without
--     bridging logic and if master generates AXI4-lite compliant transactions
--     only for this slave:
--      * requires AXI ID reflection
--      * reflection logic is recommended to use AWID, instead of WID, to ensure
--        compatibility with both AXI3 and AXI4
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library amba;
use amba.axi4.all;

entity axi4l_slave is
	generic(REG_NR: natural);
	port(aclk    : in  std_logic;
	     areset_n: in  std_logic;
	     awvalid : in  std_logic;
	     awready : out std_logic;
	     awaddr  : in  std_logic_vector(31 downto 0);
	     awprot  : in  std_logic_vector(2 downto 0);
	     wvalid  : in  std_logic;
	     wready  : out std_logic;
	     wdata   : in  std_logic_vector(31 downto 0);
	     wstrb   : in  std_logic_vector(3 downto 0);
	     bvalid  : out std_logic;
	     bready  : in  std_logic;
	     bresp   : out std_logic_vector(1 downto 0);
	     arvalid : in  std_logic;
	     arready : out std_logic;
	     araddr  : in  std_logic_vector(31 downto 0);
	     arprot  : in  std_logic_vector(3 downto 0);
	     rvalid  : out std_logic;
	     rready  : in  std_logic;
	     rdata   : out std_logic_vector(31 downto 0);
	     rresp   : out std_logic_vector(1 downto 0);

	     we      : out std_logic;
	     wreg    : out natural range 0 to REG_NR - 1;
	     wval    : out std_logic_vector(31 downto 0);
	     rreg    : out natural range 0 to REG_NR - 1;
	     rval    : in  std_logic_vector(31 downto 0));
end entity axi4l_slave;

architecture behaviour of axi4l_slave is
	-- Declare state machine states in human readable form. Encode state
	-- values according to a gray encoding scheme for better resilience to
	-- glitches and enhanced power saving.
	type state                     is (STAT_RST, STAT_REQ, STAT_RESP);
	attribute enum_encoding         : string;
	attribute enum_encoding of state: type is "00 01 11";

	signal wcur_stat_a: state;
	signal wnxt_stat_a: state;
	signal awsteady_a : std_logic;
	signal wsteady_a  : std_logic;

	signal rcur_stat_a: state;
	signal rnxt_stat_a: state;
	signal arsteady_a : std_logic;
	signal rsteady_a  : std_logic;
begin
	-- Synchronise state switching and transaction handshake output ready
	-- signals with clock and reset
	sync: process (areset_n, aclk) is
	begin
		if (areset_n = '0') then
			awready     <= '0';
			wready      <= '0';
			wcur_stat_a <= STAT_RST;
			arready     <= '0';
			rvalid      <= '0';
			rcur_stat_a <= STAT_RST;
		elsif (rising_edge(aclk)) then
			awready     <= not awsteady_a;
			wready      <= not wsteady_a;
			wcur_stat_a <= wnxt_stat_a;
			arready     <= not arsteady_a;
			rvalid      <= rsteady_a;
			rcur_stat_a <= rnxt_stat_a;
		end if;
	end process sync;

	-- Process write transactions state machine
	wxact: process (wcur_stat_a, awvalid, awaddr, wvalid, wdata, bready) is
	variable awsteady_p: std_logic                     := '0';
	variable wsteady_p : std_logic                     := '0';
	variable reg_p     : natural range 0 to REG_NR - 1 := 0;
	variable addr_p    : unsigned(29 downto 0)         := (others => '0');
	variable data_p    : std_logic_vector(31 downto 0) := (others => '0');
	variable resp_p    : std_logic_vector(1 downto 0)  := (others => '0');
	variable nxt_stat_p: state                         := STAT_RST;
	begin
		case (wcur_stat_a) is
		-- processing transaction initiated by master
		when STAT_REQ =>
			if (awvalid = '1') then
				addr_p     := unsigned(awaddr(31 downto 2));
				awsteady_p := '1';
			end if;

			if (wvalid = '1') then
				data_p    := wdata;
				wsteady_p := '1';
			end if;

			if ((awsteady_p = '1') and (wsteady_p = '1')) then
				if (to_integer(addr_p) < REG_NR) then
					reg_p  := to_integer(addr_p);
					resp_p := AXI_RESP_OKAY;
				else
					resp_p := AXI_RESP_DECERR;
				end if;

				nxt_stat_p := STAT_RESP;
			else
				nxt_stat_p := STAT_REQ;
			end if;

			bvalid <= '0';
			we     <= '0';

		-- completing ongoing transaction, i.e. feeding master back
		-- with a response code
		when STAT_RESP =>
			awsteady_p := '0';
			wsteady_p  := '0';
			bvalid     <= '1';
			we         <= '1';

			if (bready = '1') then
				nxt_stat_p := STAT_REQ;
			end if;

		-- default / unknown / reset state handling
		when others =>
			awsteady_p := '0';
			wsteady_p  := '0';
			nxt_stat_p := STAT_REQ;
			bvalid     <= '0';
			we         <= '0';
		end case;

		awsteady_a  <= awsteady_p;
		wsteady_a   <= wsteady_p;
		bresp       <= resp_p;
		wreg        <= reg_p;
		wval        <= data_p;
		wnxt_stat_a <= nxt_stat_p;
	end process wxact;

	-- Process read transactions state machine
	rxact: process (rcur_stat_a, arvalid, rready, araddr, rval) is
	variable arsteady_p: std_logic                     := '0';
	variable reg_p     : natural range 0 to REG_NR - 1 := 0;
	variable addr_p    : unsigned(29 downto 0)         := (others => '0');
	variable resp_p    : std_logic_vector(1 downto 0)  := (others => '0');
	variable nxt_stat_p: state                         := STAT_RST;
	begin
		case (rcur_stat_a) is
		-- processing transaction initiated by master
		when STAT_REQ =>
			if (arvalid = '1') then
				addr_p     := unsigned(araddr(31 downto 2));
				arsteady_p := '1';
			end if;

			if (arsteady_p = '1') then
				if (to_integer(addr_p) < REG_NR) then
					reg_p  := to_integer(addr_p);
					resp_p := AXI_RESP_OKAY;
				else
					resp_p := AXI_RESP_DECERR;
				end if;

				nxt_stat_p := STAT_RESP;
				rsteady_a  <= '1';
			else
				nxt_stat_p := STAT_REQ;
				rsteady_a  <= '0';
			end if;

		-- completing ongoing transaction, i.e. feeding master back
		-- with response code and data
		when STAT_RESP =>
			arsteady_p := '0';

			if (rready = '1') then
				nxt_stat_p := STAT_REQ;
				rsteady_a <= '0';
			else
				rsteady_a <= '1';
			end if;

		-- default / unknown / reset state handling
		when others =>
			arsteady_p := '0';
			nxt_stat_p := STAT_REQ;
			rsteady_a  <= '0';
		end case;

		arsteady_a  <= arsteady_p;
		rresp       <= resp_p;
		rreg        <= reg_p;
		rdata       <= rval;
		rnxt_stat_a <= nxt_stat_p;
	end process rxact;
end architecture behaviour;
