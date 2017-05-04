library ieee;
use ieee.std_logic_1164.all;

entity clk_gate_impl is
	port(
		en  : in  std_logic;
		iclk: in  std_logic;
		oclk: out std_logic
	);
end entity clk_gate_impl;

architecture behaviour of clk_gate_impl is
begin
	process (iclk, en) is
		variable en_p: std_logic := '0';
	begin
		-- disable clock output only when input clock is low ;
		-- enable output clock upon input clock rising edge otherwise
		-- to prevent from output clock glitches...
		if (en = '0') then
			if (iclk = '0') then
				en_p := '0';
			end if;
		elsif (rising_edge(iclk)) then
			en_p := '1';
		end if;

		oclk <= iclk and en_p;
	end process;
end architecture behaviour;
