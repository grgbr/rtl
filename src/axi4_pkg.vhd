library ieee;
use ieee.std_logic_1164.all;

package axi4 is
	type axi4_regs is
		array(natural range <>) of std_logic_vector(31 downto 0);

	constant AXI_RESP_OKAY  : std_logic_vector(1 downto 0) := "00";
	constant AXI_RESP_EXOKAY: std_logic_vector(1 downto 0) := "01";
	constant AXI_RESP_SLVERR: std_logic_vector(1 downto 0) := "10";
	constant AXI_RESP_DECERR: std_logic_vector(1 downto 0) := "11";

	component axi4l_slave is
		generic(REG_NR: natural);
		port(aclk    : in  std_logic;
		     areset_n: in  std_logic;
		     awvalid : in  std_logic;
		     awready : out std_logic;
		     awaddr  : in  std_logic_vector(31 downto 0);
		     awprot  : in  std_logic_vector(2 downto 0);
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
		     re      : out std_logic;
		     rreg    : out natural range 0 to REG_NR - 1;
		     rval    : in  std_logic_vector(31 downto 0));
	end component axi4l_slave;
end package axi4;
