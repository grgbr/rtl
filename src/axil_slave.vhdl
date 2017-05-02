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
	type state is (STAT_RST, STAT_REQ, STAT_RESP);

	signal cur_stat_i: state;
	signal nxt_stat_i: state;
	signal awsteady_i: std_logic;
	signal wsteady_i : std_logic;
begin
	-- Synchronise state switching with clock and reset
	-- Synchronise transaction handshake output ready signals with clock and
	-- reset
	sync: process (areset_n, aclk) is
	begin
		if (areset_n = '0') then
			awready    <= '-';
			wready     <= '-';
			cur_stat_i <= STAT_RST;
		elsif (rising_edge(aclk)) then
			awready    <= not awsteady_i;
			wready     <= not wsteady_i;
			cur_stat_i <= nxt_stat_i;
		end if;
	end process sync;

	wrxact: process (cur_stat_i, nxt_stat_i, awvalid, awaddr, wvalid, wdata,
	                 bready) is
	variable awsteady_v: std_logic                     := '0';
	variable wsteady_v : std_logic                     := '0';
	variable addr_v    : unsigned(29 downto 0)         := (others => '-');
	variable data_v    : std_logic_vector(31 downto 0) := (others => '-');
	variable resp_v    : std_logic_vector(1 downto 0)  := AXI_RESP_OKAY;
	constant ANY_REG   : natural range 0 to REG_NR - 1 := to_integer(addr_v);
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
				if (addr_v < REG_NR) then
					resp_v := AXI_RESP_OKAY;
					wreg   <= to_integer(addr_v);
					wval   <= data_v;
					wstat  <= AXI_STAT_WR;
				else
					resp_v := AXI_RESP_DECERR;
					wreg   <= ANY_REG;
					wval   <= (others => '-');
					wstat  <= AXI_STAT_IDLE;
				end if;

				bvalid     <= '1';
				bresp      <= resp_v;
				nxt_stat_i <= STAT_RESP;
			else
				bvalid     <= '0';
				bresp      <= (others => '-');
				wreg       <= ANY_REG;
				wstat      <= AXI_STAT_IDLE;
				nxt_stat_i <= STAT_REQ;
			end if;

		-- completing ongoing transaction, i.e. feeding the master back
		-- with a response code
		when STAT_RESP =>
			awsteady_v := '0';
			wsteady_v  := '0';
			bvalid     <= '1';
			bresp      <= resp_v;
			wreg       <= ANY_REG;
			wval       <= (others => '-');
			wstat      <= AXI_STAT_IDLE;

			if ((bready = '1') or (nxt_stat_i = STAT_REQ)) then
				nxt_stat_i <= STAT_REQ;
			else
				nxt_stat_i <= STAT_RESP;
			end if;

		-- also handle STAT_RST
		when others =>
			awsteady_v := '0';
			wsteady_v  := '0';
			bvalid     <= '0';
			bresp      <= (others => '-');
			rvalid     <= '0';
			wreg       <= ANY_REG;
			wval       <= (others => '-');
			wstat      <= AXI_STAT_RST;
			nxt_stat_i <= STAT_REQ;
		end case;

		awsteady_i <= awsteady_v;
		wsteady_i  <= wsteady_v;
	end process wrxact;
end architecture behaviour;
