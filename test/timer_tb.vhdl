library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity timer_tb is
end timer_tb;

architecture behaviour of timer_tb is
component timer
	port(
		mode   : in  unsigned(1 downto 0);
		load   : in  unsigned(31 downto 0);
		ack_int: in  std_logic;
		clk    : in  std_logic;
		req_int: out std_logic;
		count  : out unsigned(31 downto 0)
	);
end component;
constant MODE_NONE  : unsigned(1 downto 0) := b"00";
constant MODE_COUNT : unsigned(1 downto 0) := b"01";
constant MODE_SINGLE: unsigned(1 downto 0) := b"10";
constant MODE_AUTO  : unsigned(1 downto 0) := b"11";
signal   mode_tb   : unsigned(1 downto 0)  := MODE_NONE;
signal   load_tb   : unsigned(31 downto 0) := (others => '0');
signal   ack_int_tb: std_logic             := '0';
signal   clk_tb    : std_logic             := '0';
signal   req_int_tb: std_logic             := '0';
signal   count_tb  : unsigned(31 downto 0) := (others => '0');
constant t_tb      : time                  := 20 ns;
signal   done      : boolean               := false;
begin
	timer_uut: timer port map (mode_tb, load_tb, ack_int_tb, clk_tb,
	                           req_int_tb, count_tb);

	clock: process
	begin
		if (done = false) then
			clk_tb <= not clk_tb;
			wait for t_tb / 2;
		else
			wait;
		end if;
	end process;

	count: process
	variable l: integer;
	begin
		wait for t_tb;

		mode_tb <= MODE_NONE;
		wait for t_tb * 2;

		assert count_tb = x"ffffffff";
		assert req_int_tb = '0';
		
		mode_tb <= MODE_COUNT;
		wait for t_tb * 2;
		assert count_tb = to_unsigned(1, 32);
		assert req_int_tb = '0';
		wait for t_tb;
		assert count_tb = to_unsigned(2, 32);
		assert req_int_tb = '0';

		wait for t_tb / 4;
		load_tb <= to_unsigned(4, 32);
		assert count_tb = to_unsigned(3, 32);
		wait for 3 * t_tb / 4;
		assert count_tb = to_unsigned(3, 32);
		assert req_int_tb = '0';

		mode_tb <= MODE_SINGLE;
		assert count_tb = to_unsigned(3, 32);
		assert req_int_tb = '0';
		wait for 3 * t_tb;
		assert count_tb = to_unsigned(6, 32);
		assert req_int_tb = '0';
		wait for t_tb;
		assert count_tb = to_unsigned(7, 32);

		wait for t_tb / 4;
		assert req_int_tb = '1';
		ack_int_tb <= '1';
		wait for t_tb / 4;
		assert req_int_tb = '0';
		ack_int_tb <= '0';
		wait for t_tb / 2;
		assert count_tb = to_unsigned(8, 32);

		wait for 4 * t_tb;
		assert req_int_tb = '0';
		assert count_tb = to_unsigned(12, 32);

		load_tb <= to_unsigned(2, 32);
		wait for (2 * t_tb) + (t_tb / 4);
		assert req_int_tb = '1';
		assert count_tb = to_unsigned(15, 32);

		mode_tb <= MODE_NONE;
		wait for 3 * t_tb / 4;
		assert req_int_tb = '0';

		--rld_tb <= to_unsigned(5, 32);
		--en_tb <= '1';
		--for l in 0 to 4 loop
		--	wait on tck_tb;
		--	assert tck_tb = '1';
		--	wait for t_tb / 4;
		--	ack_tb <= '1';
		--	wait for t_tb / 4;
		--	assert tck_tb = '0';
		--	ack_tb <= '0';
		--end loop;

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
