library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library amba;
use amba.axi4.all;

entity axi4ls_timer is
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
end entity axi4ls_timer;

architecture behaviour of axi4ls_timer is
	component axi4l_slave is
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
	end component axi4l_slave;

	signal we_a   : std_logic;
	signal wreg_a : natural range 0 to 2;
	signal wval_a : std_logic_vector(31 downto 0);
	signal rreg_a : natural range 0 to 2;
	signal rval_a : std_logic_vector(31 downto 0);

	signal stor0_a: std_logic_vector(31 downto 0);
	signal stor1_a: std_logic_vector(31 downto 0);
	signal stor2_a: std_logic_vector(31 downto 0);
begin
	tmr_i : axi4l_slave generic map (REG_NR => 3)
	                    port map (aclk, areset_n, awvalid, awready,
	                              awaddr, awprot, wvalid, wready, wdata,
	                              wstrb, bvalid, bready, bresp, arvalid,
	                              arready, araddr, arprot, rvalid,
	                              rready, rdata, rresp, we_a, wreg_a,
	                              wval_a, rreg_a, rval_a);

	comb: process (areset_n, we_a, wreg_a, wval_a, rreg_a) is
	variable val_p : std_logic_vector(31 downto 0) := (others => '0');
	variable reg0_p: std_logic_vector(31 downto 0) := (others => '0');
	variable reg1_p: std_logic_vector(31 downto 0) := (others => '0');
	variable reg2_p: std_logic_vector(31 downto 0) := (others => '0');
	begin
		if (areset_n = '0') then
			val_p  := (others => '0');
			reg0_p := (others => '0');
			reg1_p := (others => '0');
			reg2_p := (others => '0');
		else
			if (rising_edge(we_a)) then
				case (wreg_a) is
					when 0      => reg0_p := wval_a;
					when 1      => reg1_p := wval_a;
					when 2      => reg2_p := wval_a;
					when others => NULL;
				end case;
			end if;

			case (rreg_a) is
				when 0      => val_p := reg0_p;
				when 1      => val_p := reg1_p;
				when 2      => val_p := reg2_p;
				when others => NULL;
			end case;
		end if;

		rval_a  <= val_p;
		stor0_a <= reg0_p;
		stor1_a <= reg1_p;
		stor2_a <= reg2_p;
	end process comb;
end architecture behaviour;
