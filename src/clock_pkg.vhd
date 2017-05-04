library ieee;
use ieee.std_logic_1164.all;

package clock is

--------------------------------------------------------------------------------
-- Simple clock gater
--------------------------------------------------------------------------------

component clk_gate_impl is
	port(
		en  : in std_logic;
		iclk: in std_logic;
		oclk: in std_logic
	);
end component clk_gate_impl;

end package clock;
