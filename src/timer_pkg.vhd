library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package timer is

--------------------------------------------------------------------------------
-- AXI4 lite slave timer
--------------------------------------------------------------------------------

component tmr_axi4ls is
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
end component tmr_axi4ls;

--------------------------------------------------------------------------------
-- timer logic register definitions
--------------------------------------------------------------------------------

-- control register
constant TMR_CTRL_REG: natural := 0;
-- status register
constant TMR_STAT_REG: natural := 1;
-- alarm register
constant TMR_ALRM_REG: natural := 2;
-- counter register
constant TMR_CNT_REG : natural := 3;
-- number of register implemented by timer logic
constant TMR_REG_NR  : natural := 4;

-- disabled mode
constant TMR_CTRL_MODE_NONE: std_logic_vector(1 downto 0) := b"00";
-- counting mode
constant TMR_CTRL_MODE_CNT : std_logic_vector(1 downto 0) := b"01";
-- counting mode with single shot interrupt generation
constant TMR_CTRL_MODE_SNGL: std_logic_vector(1 downto 0) := b"10";
-- counting mode with automatic rearm of interrupt generation
constant TMR_CTRL_MODE_AUTO: std_logic_vector(1 downto 0) := b"11";

type tmr_reg is (ctrl_reg, stat_reg, alrm_reg, cnt_reg);

--------------------------------------------------------------------------------
-- timer logic with register access interface
--------------------------------------------------------------------------------

component tmr_regs is
	port(
		-- active low reset: out of reset upon de-assertion at next
		-- clk rising edge
		rst_n: in  std_logic;
		-- clock
		clk  : in  std_logic;
		-- active high register write enable
		we   : in  std_logic;
		-- index of register to write
		wreg : in  natural range 0 to TMR_REG_NR - 1;
		-- content to write to register
		wdat : in  std_logic_vector(31 downto 0);
		-- active high register output enable
		oe   : in  std_logic;
		-- index of register to read
		oreg : in  natural range 0 to TMR_REG_NR - 1;
		-- content of read register
		odat : out std_logic_vector(31 downto 0);
		-- interrupt request
		int  : out std_logic
	);
end component tmr_regs;

--------------------------------------------------------------------------------
-- timer logic
--------------------------------------------------------------------------------

component tmr_impl is
	port(
		clk     : in  std_logic;

		ld_cnt  : in  std_logic;
		cnt     : in  unsigned(31 downto 0);
		cnt_ld  : out std_logic;
		cntdwn  : out unsigned(31 downto 0);

		set_laps: in  std_logic;
		laps    : in  unsigned(31 - 2 downto 0);
		laps_set: out std_logic;

		clr_alrm: in  std_logic;
		alrm_set: out std_logic
	);
end component tmr_impl;

end package timer;
