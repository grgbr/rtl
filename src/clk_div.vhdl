library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clk_div is
	port(
		en     : in std_logic;
		cnt    : in unsigned(31 downto 0);
		clk_in : in std_logic;
		clk_out: out std_logic
	);
end entity clk_div;

architecture behaviour of clk_div is
begin
	process (en, clk_in) is
	variable cyc: unsigned(31 downto 0) := to_unsigned(0, 32);
	variable clk: std_logic := '0';
	begin
		case (en) is
		when '0' =>
			cyc := to_unsigned(0, 32);
			clk := '0';

		when '1' =>
			if (clk_in'event) then
				if (cyc = to_unsigned(0, 32)) then
					cyc := cnt;
					clk := not clk;
				else
					cyc := cyc - 1;
				end if;
			end if;

		when others =>
			null;
		end case;

		clk_out <= clk;
	end process;
end architecture behaviour;
