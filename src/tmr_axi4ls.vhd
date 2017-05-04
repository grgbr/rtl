library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library amba;
use amba.axi4.all;

library time;
use time.timer.all;

entity tmr_axi4ls is
	port(
		aclk    : in  std_logic;
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
		int     : out std_logic
	);
end entity tmr_axi4ls;

architecture behaviour of tmr_axi4ls is
	component axi4l_slave is
		generic(REG_NR: natural);
		port(
			aclk    : in  std_logic;
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
			re      : out std_logic;
			rreg    : out natural range 0 to REG_NR - 1;
			rval    : in  std_logic_vector(31 downto 0)
		);
	end component axi4l_slave;

	signal we_a  : std_logic;
	signal wreg_a: natural range 0 to TMR_REG_NR - 1;
	signal wdat_a: std_logic_vector(31 downto 0);
	signal oe_a  : std_logic;
	signal oreg_a: natural range 0 to TMR_REG_NR - 1;
	signal odat_a: std_logic_vector(31 downto 0);
begin
	bus_a: axi4l_slave generic map (REG_NR => TMR_REG_NR) port map (
		aclk     => aclk,
		areset_n => areset_n,
		awvalid  => awvalid,
		awready  => awready,
		awaddr   => awaddr,
		awprot   => awprot,
		wvalid   => wvalid,
		wready   => wready,
		wdata    => wdata,
		wstrb    => wstrb,
		bvalid   => bvalid,
		bready   => bready,
		bresp    => bresp,
		arvalid  => arvalid,
		arready  => arready,
		araddr   => araddr,
		arprot   => arprot,
		rvalid   => rvalid,
		rready   => rready,
		rdata    => rdata,
		rresp    => rresp,

		we       => we_a,
		wreg     => wreg_a,
		wval     => wdat_a,
		re       => oe_a,
		rreg     => oreg_a,
		rval     => odat_a
	);

	tmr_a: tmr_regs port map(
		rst_n => areset_n,
		clk   => aclk,
		we    => we_a,
		wreg  => wreg_a,
		wdat  => wdat_a,
		oe    => oe_a,
		oreg  => oreg_a,
		odat  => odat_a,
		int   => int
	);
end architecture behaviour;
