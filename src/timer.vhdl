library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity timer is
	port(
		clk    : in  std_logic;
		mode   : in  unsigned(1 downto 0);
		req_arm: in  std_logic;
		ack_arm: out std_logic;
		load   : in  unsigned(30 downto 0);
		req_int: out std_logic;
		ack_int: in  std_logic;
		count  : out unsigned(31 downto 0)
	);
end entity timer;

architecture behaviour of timer is
constant MODE_NONE  : unsigned(1 downto 0) := b"00";
constant MODE_COUNT : unsigned(1 downto 0) := b"01";
constant MODE_SINGLE: unsigned(1 downto 0) := b"10";
constant MODE_AUTO  : unsigned(1 downto 0) := b"11";
begin
	process (clk, mode, load, req_arm, ack_int) is
	variable ld : unsigned(30 downto 0) := (others => '0');
	variable exp: unsigned(30 downto 0) := (others => '0');
	variable cnt: unsigned(31 downto 0) := (others => '0');
	variable arm: std_logic             := '0';
	variable int: std_logic             := '0';
	begin
		case (mode) is
		when MODE_COUNT =>
			if (rising_edge(clk)) then
				cnt := cnt + 1;
			end if;

			arm := '0';
			int := '0';

		when MODE_SINGLE =>
			if (mode'event or rising_edge(req_arm)) then
				ld := load;
				exp := load;
				arm := '1';
				int := '0';
			end if;

			if (rising_edge(clk)) then
				if (ld /= to_unsigned(0, 31)) then
					if (exp = to_unsigned(0, 31)) then
						ld := (others => '0');
						int := '1';
					else
						exp := exp - 1;
					end if;
				end if;

				cnt := cnt + 1;
			end if;

			if (req_arm = '0') then
				arm := '0';
			end if;
			if (ack_int = '1') then
				int := '0';
			end if;

		when MODE_AUTO =>
			if (mode'event or rising_edge(req_arm)) then
				ld := load;
				exp := load;
				arm := '1';
				int := '0';
			end if;

			if (rising_edge(clk)) then
				if (exp = to_unsigned(0, 31)) then
					exp := ld;
					int := '1';
				else
					exp := exp - 1;
				end if;

				cnt := cnt + 1;
			end if;

			if (req_arm = '0') then
				arm := '0';
			end if;
			if (ack_int = '1') then
				int := '0';
			end if;

		when others =>
			arm := '0';
			int := '0';
		end case;

		count <= cnt;
		ack_arm <= arm;
		req_int <= int;
	end process;
end architecture behaviour;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity timer_regs is
	port(
	     clk    : in    std_logic;
	     oe     : in    std_logic;
	     control: inout unsigned(31 downto 0);
	     load   : inout unsigned(31 downto 0);
	     count  : out   unsigned(31 downto 0);
	     int    : out   std_logic
	);
end entity timer_regs;

architecture behaviour of timer_regs is
component timer
	port(clk    : in  std_logic;
		 mode   : in  unsigned(1 downto 0);
		 req_arm: in  std_logic;
		 ack_arm: out std_logic;
		 load   : in  unsigned(30 downto 0);
		 req_int: out std_logic;
		 ack_int: in  std_logic;
		 count  : out unsigned(31 downto 0)
	);
end component;
signal mode   : unsigned(1 downto 0)  := (others => '0');
signal req_arm: std_logic             := '0';
signal ack_arm: std_logic             := 'Z';
signal ld     : unsigned(30 downto 0) := (others => '0');
signal req_int: std_logic             := 'Z';
signal ack_int: std_logic             := '0';
begin
	tmr: timer port map(clk, mode, req_arm, ack_arm, ld, req_int,
	                    ack_int, count);

	process (clk) is
	begin
		if (rising_edge(clk)) then
			if (oe = '0') then
				mode <= control and b"11";
				req_arm <= load(31);
				ld <= load(30 downto 0);
				ack_int <= '0';
			else
				req_arm <= not ack_arm;
				ack_int <= req_int;
			end if;
		end if;
	end process;

	process (oe) is
	begin
		if (oe = '0') then
			control <= (others => 'Z');
			load <= (others => 'Z');
		else
			control <= (31 downto 3 => '0') & req_int & mode;
			load <= req_arm & ld;
		end if;
	end process;
end architecture behaviour;
