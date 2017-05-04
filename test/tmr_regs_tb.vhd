--------------------------------------------------------------------------------
-- Just a wrapper around tmr_regs since for some reason cocotb/ghdl cannot set
-- natural signals from the python test bench.
-- Not meant to be synthesizable.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library time;
use time.timer.all;

entity tmr_regs_tb is
	port(
		rst_n: in  std_logic;
		clk  : in  std_logic;
		we   : in  std_logic;
		wreg : in  unsigned(1 downto 0);
		wdat : in  std_logic_vector(31 downto 0);
		oe   : in  std_logic;
		oreg : in  unsigned(1 downto 0);
		odat : out std_logic_vector(31 downto 0);
		int  : out std_logic
	);
end entity tmr_regs_tb;

architecture behaviour of tmr_regs_tb is
	component tmr_regs is
		port(
			rst_n: in  std_logic;
			clk  : in  std_logic;
			we   : in  std_logic;
			wreg : in  natural range 0 to TMR_REG_NR - 1;
			wdat : in  std_logic_vector(31 downto 0);
			oe   : in  std_logic;
			oreg : in  natural range 0 to TMR_REG_NR - 1;
			odat : out std_logic_vector(31 downto 0);
			int  : out std_logic
		);
	end component tmr_regs;

	signal wreg_a: natural range 0 to TMR_REG_NR - 1;
	signal oreg_a: natural range 0 to TMR_REG_NR - 1;
begin
	regs: tmr_regs port map (
		rst_n => rst_n,
		clk   => clk,
		we    => we,
		wreg  => wreg_a,
		wdat  => wdat,
		oe    => oe,
		oreg  => oreg_a,
		odat  => odat,
		int   => int
	);

	process (rst_n, wreg, oreg) is
	begin
		if (rst_n = '1') then
			wreg_a <= to_integer(wreg);
			oreg_a <= to_integer(oreg);
		end if;
	end process;
end architecture behaviour;
