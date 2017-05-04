library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tmr_impl is
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
end entity tmr_impl;

architecture behaviour of tmr_impl is
begin
	process (clk, ld_cnt, cnt, set_laps, laps, clr_alrm) is
		variable cntdwn_p: unsigned(cntdwn'range) := (others => '0');
		variable laps_p  : unsigned(laps'range)   := (others => '0');
		variable trig_p  : std_logic              := '0';
	begin
		if (ld_cnt = '1') then
			cntdwn_p := cnt;
		elsif (rising_edge(clk)) then
			cntdwn_p := cntdwn_p + 1;
		end if;

		if (set_laps = '1') then
			laps_p := laps;
		elsif (rising_edge(clk)) then
			laps_p := laps_p - 1;

			if (laps_p = to_unsigned(0, laps_p'length)) then
				laps_p := laps;
				trig_p := '1';
			end if;
		end if;

		if (trig_p = '1') then
			trig_p := not clr_alrm;
		end if;

		cnt_ld   <= ld_cnt;
		cntdwn   <= cntdwn_p;
		laps_set <= set_laps;
		alrm_set <= trig_p;
	end process;
end architecture behaviour;
