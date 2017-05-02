library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clk_div_tb is
end clk_div_tb;

architecture behaviour of clk_div_tb is
component clk_div
	port (
		en     : in std_logic;
		cnt    : in unsigned(31 downto 0);
		clk_in : in std_logic;
		clk_out: out std_logic
	);
end component;
signal   clk       : std_logic := '0';
signal   en        : std_logic;
signal   cnt       : unsigned(31 downto 0);
signal   clk_out   : std_logic;
constant clk_period: time := 20 ns;
signal   done      : boolean := false;
begin
	clk_div_uut: clk_div port map (en, cnt, clk, clk_out);

	clock: process
	begin
		if (done = false) then
			clk <= not clk;
			wait for clk_period / 2;
		else
			wait;
		end if;
	end process;

	reset: process
	begin
		cnt <= to_unsigned(0, 32);
		en <= '0';
		wait for clk_period * 5;
		en <= '1';
		wait for clk_period * 50;
		en <= '0';
		wait for clk_period * 5;

		done <= true;
		report "simulation finished" severity Note;

		wait;
	end process;
end architecture behaviour;

--process
--   type pattern_type is record
--      --  The inputs of the adder.
--      i0, i1, ci : bit;
--      --  The expected outputs of the adder.
--      s, co : bit;
--   end record;
--   --  The patterns to apply.
--   type pattern_array is array (natural range <>) of pattern_type;
--   constant patterns : pattern_array :=
--     (('0', '0', '0', '0', '0'),
--      ('0', '0', '1', '1', '0'),
--      ('0', '1', '0', '1', '0'),
--      ('0', '1', '1', '0', '1'),
--      ('1', '0', '0', '1', '0'),
--      ('1', '0', '1', '0', '1'),
--      ('1', '1', '0', '0', '1'),
--      ('1', '1', '1', '1', '1'));
--begin
--   --  Check each pattern.
--   for i in patterns'range loop
--      --  Set the inputs.
--      i0 <= patterns(i).i0;
--      i1 <= patterns(i).i1;
--      ci <= patterns(i).ci;
--      --  Wait for the results.
--      wait for 1 ns;
--      --  Check the outputs.
--      assert s = patterns(i).s
--	 report "bad sum value" severity error;
--      assert co = patterns(i).co
--	 report "bad carray out value" severity error;
--   end loop;
--   assert false report "end of test" severity note;
--   --  Wait forever; this will finish the simulation.
--   wait;
--end process;
