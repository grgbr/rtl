library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library amba;
use amba.axi.all;

entity axil_slave is
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

	     wstat   : out axi_state;
	     wreg    : out natural range 0 to REG_NR - 1;
	     wval    : out std_logic_vector(31 downto 0));
end entity axil_slave;

architecture behaviour of axil_slave is
	-- Declare state machine states in human readable form. Encode state
	-- values according to a gray encoding scheme for better resilience to
	-- glitches and enhanced power saving.
	type state is                     (STAT_RST, STAT_REQ, STAT_RESP);
	attribute enum_encoding         : string;
	attribute enum_encoding of state: type is "00 01 11";

	signal cur_stat_i: state;
	signal nxt_stat_i: state;
	signal awsteady_i: std_logic;
	signal wsteady_i : std_logic;
begin
	-- Synchronise state switching and transaction handshake output ready
	-- signals with clock and reset
	sync: process (areset_n, aclk) is
	begin
		if (areset_n = '0') then
			awready    <= '0';
			wready     <= '0';
			cur_stat_i <= STAT_RST;
		elsif (rising_edge(aclk)) then
			awready    <= not awsteady_i;
			wready     <= not wsteady_i;
			cur_stat_i <= nxt_stat_i;
		end if;
	end process sync;

	-- Process write transactions state machine
	wrxact: process (cur_stat_i, awvalid, awaddr, wvalid, wdata, bready) is
	variable awsteady_v: std_logic                     := '0';
	variable wsteady_v : std_logic                     := '0';
	variable reg_v     : natural range 0 to REG_NR - 1 := 0;
	variable addr_v    : unsigned(29 downto 0)         := (others => '0');
	variable data_v    : std_logic_vector(31 downto 0) := (others => '0');
	variable resp_v    : std_logic_vector(1 downto 0)  := (others => '0');
	variable nxt_stat_v: state                         := STAT_RST;
	begin
		case (cur_stat_i) is
		-- processing transaction initiated by master
		when STAT_REQ =>
			if (awvalid = '1') then
				addr_v     := unsigned(awaddr(31 downto 2));
				awsteady_v := '1';
			end if;

			if (wvalid = '1') then
				data_v    := wdata;
				wsteady_v := '1';
			end if;

			if ((awsteady_v = '1') and (wsteady_v = '1')) then
				if (to_integer(addr_v) < REG_NR) then
					reg_v  := to_integer(addr_v);
					resp_v := AXI_RESP_OKAY;
				else
					resp_v := AXI_RESP_DECERR;
				end if;

				nxt_stat_v := STAT_RESP;
			else
				nxt_stat_v := STAT_REQ;
			end if;

			bvalid <= '0';
			wstat  <= AXI_STAT_IDLE;

		-- completing ongoing transaction, i.e. feeding master back
		-- with a response code
		when STAT_RESP =>
			awsteady_v := '0';
			wsteady_v  := '0';
			bvalid     <= '1';
			wstat      <= AXI_STAT_WR;

			if (bready = '1') then
				nxt_stat_v := STAT_REQ;
			end if;

		-- default / unknown / reset state handling
		when others =>
			awsteady_v := '0';
			wsteady_v  := '0';
			nxt_stat_v := STAT_REQ;
			bvalid     <= '0';
			wstat      <= AXI_STAT_RST;
		end case;

		awsteady_i <= awsteady_v;
		wsteady_i  <= wsteady_v;
		bresp      <= resp_v;
		wreg       <= reg_v;
		wval       <= data_v;
		nxt_stat_i <= nxt_stat_v;
	end process wrxact;

	-- Process read transactions state machine
	rdxact: process (cur_stat_i) is
	begin
		case (cur_stat_i) is
		-- default / unknown / reset state handling
		when others =>
			rvalid <= '0';
		end case;
	end process rdxact;
end architecture behaviour;
