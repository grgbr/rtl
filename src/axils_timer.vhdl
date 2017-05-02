library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library amba;
use amba.axi.all;

entity axils_timer is
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
	     rresp   : out std_logic_vector(1 downto 0));
end entity axils_timer;

architecture behaviour of axils_timer is
	component axil_slave is
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
	end component axil_slave;

	signal wstat: axi_state;
	signal wreg : natural range 0 to 2;
	signal wval : std_logic_vector(31 downto 0);
	signal oreg0: std_logic_vector(31 downto 0);
	signal oreg1: std_logic_vector(31 downto 0);
	signal oreg2: std_logic_vector(31 downto 0);
begin
	tmr : axil_slave generic map (REG_NR => 3)
	                 port map (aclk, areset_n, awvalid, awready,
	                           awaddr, awprot, wvalid, wready, wdata,
	                           wstrb, bvalid, bready, bresp, arvalid,
	                           arready, araddr, arprot, rvalid,
	                           rready, rdata, rresp, wstat, wreg,
	                           wval);

	write: process (wstat, wreg, wval) is
	variable reg0: std_logic_vector(31 downto 0) := (others => '0');
	variable reg1: std_logic_vector(31 downto 0) := (others => '0');
	variable reg2: std_logic_vector(31 downto 0) := (others => '0');
	begin
		case (wstat) is
		when AXI_STAT_RST =>
			reg0 := (others => '0');
			reg1 := (others => '0');
			reg2 := (others => '0');

		when AXI_STAT_WR =>
			case (wreg) is
				when 0      => reg0 := wval;
				when 1      => reg1 := wval;
				when 2      => reg2 := wval;
				when others => NULL;
			end case;

		-- also process AXI_STAT_IDLE state
		when others => NULL;
		end case;

		oreg0 <= reg0;
		oreg1 <= reg1;
		oreg2 <= reg2;
	end process write;
end architecture behaviour;
