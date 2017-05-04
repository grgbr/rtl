library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library time;
use time.timer.all;
use time.clock.all;

entity tmr_regs is
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
end entity tmr_regs;

architecture behaviour of tmr_regs is
	component clk_gate_impl is
		port(
			en  : in  std_logic;
			iclk: in  std_logic;
			oclk: out std_logic
		);
	end component clk_gate_impl;

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

	-- clock gater logic interface
	signal clk_en_a: std_logic;
	signal clk_a   : std_logic;

	-- timer logic interface
	signal ld_cnt_a  : std_logic;
	signal cnt_a     : unsigned(31 downto 0);
	signal cnt_ld_a  : std_logic;
	signal cntdwn_a  : unsigned(31 downto 0);

	signal set_laps_a: std_logic;
	signal laps_a    : unsigned(31 - 2 downto 0);
	signal laps_set_a: std_logic;

	signal clr_alrm_a: std_logic;
	signal alrm_set_a: std_logic;
begin
	div: clk_gate_impl port map (
		en   => clk_en_a,
		iclk => clk,
		oclk => clk_a
	);

	tmr: tmr_impl port map (
		clk      => clk_a,

		ld_cnt   => ld_cnt_a,
		cnt      => cnt_a,
		cnt_ld   => cnt_ld_a,
		cntdwn   => cntdwn_a,

		set_laps => set_laps_a,
		laps     => laps_a,
		laps_set => laps_set_a,

		clr_alrm => clr_alrm_a,
		alrm_set => alrm_set_a
	);

	sync: process (rst_n, clk, we, wreg, wdat, oe, oreg, cnt_ld_a, cntdwn_a,
	               laps_set_a, alrm_set_a) is
		variable clk_en_p  : std_logic                    := '0';

		variable ld_cnt_p  : std_logic                    := '1';
		variable cnt_p     : unsigned(cnt_a'range)        := (others => '0');
		variable set_laps_p: std_logic                    := '1';
		variable laps_p    : unsigned(laps_a'range)       := (others => '0');
		variable clr_alrm_p: std_logic                    := '1';

		variable odat_p    : std_logic_vector(odat'range) := (others => '0');
		variable int_p     : std_logic                    := '0';

		variable mod_p     : std_logic_vector(1 downto 0) := TMR_CTRL_MODE_NONE;
		variable arm_p     : std_logic                    := '0';
	begin
		if (rst_n = '0') then
			clk_en_p   := '0';

			ld_cnt_p   := '1';
			cnt_p      := (others => '0');
			set_laps_p := '1';
			laps_p     := (others => '0');
			clr_alrm_p := alrm_set_a;

			odat_p     := (others => '0');
			int_p      := '0';

			mod_p      := TMR_CTRL_MODE_NONE;
			arm_p      := '0';
		elsif (rising_edge(clk)) then
			if (cnt_ld_a = '1') then
				ld_cnt_p := '0';
			end if;

			if (laps_set_a = '1') then
				set_laps_p := '0';
			end if;

			if (we = '1') then
				case  (wreg) is
				when TMR_CTRL_REG =>
					mod_p := wdat(1 downto 0);

				when TMR_ALRM_REG =>
					laps_p     := unsigned(wdat(wdat'left downto 2));
					arm_p      := wdat(1);
					set_laps_p := wdat(0);

				when TMR_CNT_REG =>
					cnt_p    := unsigned(wdat);
					ld_cnt_p := '1';

				when others => NULL;
				end case;
			end if;

			if (mod_p = TMR_CTRL_MODE_NONE) then
				clk_en_p := '0';
			else
				clk_en_p := '1';
			end if;

			if (mod_p = TMR_CTRL_MODE_AUTO) then
				arm_p := '1';
			end if;

			if (oe = '1') then
				case (oreg) is
				when TMR_CTRL_REG =>
					odat_p := (odat_p'left downto 2 => '0') &
					          mod_p;

				when TMR_STAT_REG =>
					odat_p     := (odat_p'left downto 2 => '0') &
					              arm_p & alrm_set_a;
					clr_alrm_p := alrm_set_a;

				when TMR_ALRM_REG =>
					odat_p := std_logic_vector(laps_p) &
					          b"00";

				when TMR_CNT_REG =>
					odat_p := std_logic_vector(cntdwn_a);

				when others => NULL;
				end case;
			end if;

			if (alrm_set_a = '1' and arm_p = '1') then
				int_p := '1';
			end if;
			if (clr_alrm_p = '1') then
				arm_p := '0';
				int_p := '0';
			end if;
		end if;

		-- drive clock gater
		clk_en_a <= clk_en_p;

		-- drive timer logic inputs
		ld_cnt_a   <= ld_cnt_p;
		cnt_a      <= cnt_p;
		set_laps_a <= set_laps_p;
		laps_a     <= laps_p;
		clr_alrm_a <= clr_alrm_p;

		-- drive output registers and interrupt
		odat <= odat_p;
		int  <= int_p;
	end process sync;
end architecture behaviour;

--architecture behaviour of tmr_regs is
--	signal mod_a     : std_logic_vector(1 downto 0);
--	signal alrm_a    : unsigned(odat'left - 2 downto 0);
--	signal set_laps_a: std_logic;
--	signal ack_laps_a: std_logic;
--	signal arm_a     : std_logic;
--	signal disarm_a  : std_logic;
--	signal clr_past_a: std_logic;
--	signal set_cnt_a : boolean;
--	signal ack_cnt_a : boolean;
--	signal cnt_a     : unsigned(odat'range);
--	signal sync_cnt_a: unsigned(odat'range);
--	signal past_a    : std_logic;
--begin
--	sync: process (rst_n, clk, set_laps_a, alrm_a, arm_a, clr_past_a,
--	               mod_a, set_cnt_a, cnt_a) is
--		type tmr_stat is record
--			cnt : unsigned(31 downto 0);
--			laps: unsigned(29 downto 0);
--			past: std_logic;
--			int : std_logic;
--		end record tmr_stat;
--
--		procedure tmr_count(constant count: in    unsigned(31 downto 0);
--		                    constant alarm: in    unsigned(29 downto 0);
--		                    constant lapse: in    unsigned(29 downto 0);
--		                    constant armed: in    std_logic;
--		                    variable state: inout tmr_stat) is
--		begin
--			state.cnt  := count + 1;
--			state.laps := lapse - 1;
--			if (state.laps = to_unsigned(0, lapse'length)) then
--				state.laps := alarm;
--				state.past := '1';
--				if (armed = '1') then
--					state.int := '1';
--				end if;
--			end if;
--		end tmr_count;
--
--		constant INIT_STAT: tmr_stat   := ((others => '0'),
--		                                   (others => '0'), '0', '0');
--
--		variable ack_laps_p: std_logic := '0';
--		variable disarm_p  : std_logic := '0';
--		variable ack_cnt_p : boolean   := false;
--		variable stat_p    : tmr_stat  := INIT_STAT;
--	begin
--		if (rst_n = '0') then
--			ack_laps_p := '1';
--			disarm_p   := '1';
--			ack_cnt_p  := true;
--			stat_p     := INIT_STAT;
--		elsif (rising_edge(clk)) then
--			if (set_laps_a = '1') then
--				stat_p.laps := alrm_a;
--			end if;
--			ack_laps_p := set_laps_a;
--
--			if (clr_past_a = '1') then
--				stat_p.past := '0';
--				stat_p.int  := '0';
--			end if;
--
--			if (set_cnt_a = true) then
--				stat_p.cnt := cnt_a;
--			end if;
--			ack_cnt_p := set_cnt_a;
--
--			case (mod_a) is
--			when TMR_CTRL_MODE_CNT =>
--				tmr_count(stat_p.cnt, alrm_a, stat_p.laps, '0',
--				          stat_p);
--				disarm_p := '1';
--
--			when TMR_CTRL_MODE_SNGL =>
--				tmr_count(stat_p.cnt, alrm_a, stat_p.laps,
--				          arm_a, stat_p);
--				disarm_p := stat_p.int;
--
--			when TMR_CTRL_MODE_AUTO =>
--				tmr_count(stat_p.cnt, alrm_a, stat_p.laps, '1',
--				          stat_p);
--				disarm_p := '0';
--
--			when others => NULL;
--			end case;
--		end if;
--
--		ack_laps_a <= ack_laps_p;
--		disarm_a   <= disarm_p ;
--		past_a     <= stat_p.past;
--		int        <= stat_p.int;
--		ack_cnt_a  <= ack_cnt_p;
--		sync_cnt_a <= stat_p.cnt;
--	end process sync;
--
--	regs: process (we, wreg, wdat, oe, oreg, ack_laps_a, disarm_a, past_a,
--		       ack_cnt_a, sync_cnt_a) is
--		variable mod_p     : std_logic_vector(mod_a'range) := TMR_CTRL_MODE_NONE;
--		variable alrm_p    : unsigned(alrm_a'range)        := (others => '0');
--		variable set_laps_p: std_logic                     := '0';
--		variable arm_p     : std_logic                     := '0';
--		variable clr_past_p: std_logic                     := '0';
--		variable set_cnt_p : boolean                       := false;
--		variable cnt_p     : unsigned(odat'range)          := (others => '0');
--		variable odat_p    : std_logic_vector(odat'range)  := (others => '0');
--	begin
--		if (ack_laps_a = '1') then
--			set_laps_p := '0';
--		end if;
--
--		if (disarm_a = '1') then
--			arm_p := '0';
--		end if;
--
--		if (past_a = '0') then
--			clr_past_p := '0';
--		end if;
--
--		if (ack_cnt_a = true) then
--			set_cnt_p := false;
--		end if;
--
--		if (we = '1') then
--			case  (wreg) is
--			when TMR_CTRL_REG => mod_p      := wdat(1 downto 0);
--
--			when TMR_ALRM_REG => alrm_p     := unsigned(wdat(wdat'left downto 2));
--			                     arm_p      := wdat(1);
--			                     set_laps_p := wdat(0);
--
--			when TMR_CNT_REG  => cnt_p      := unsigned(wdat);
--			                     set_cnt_p  := true;
--
--			when others       => NULL;
--			end case;
--		end if;
--
--		mod_a      <= mod_p;
--		alrm_a     <= alrm_p;
--		set_laps_a <= set_laps_p;
--		arm_a      <= arm_p;
--		set_cnt_a  <= set_cnt_p;
--		cnt_a      <= cnt_p;
--
--		if (oe = '1') then
--			case (oreg) is
--			when TMR_CTRL_REG => odat_p     := (odat_p'left downto 2 => '0') &
--			                                   mod_p ;
--
--			when TMR_STAT_REG => odat_p     := (odat_p'left downto 2 => '0') &
--			                                   arm_p &
--			                                   past_a;
--			                     clr_past_p := past_a;
--
--			when TMR_ALRM_REG => odat_p     := std_logic_vector(alrm_p) &
--			                                   b"00";
--
--			when TMR_CNT_REG  => odat_p     := std_logic_vector(sync_cnt_a);
--
--			when others       => NULL;
--			end case;
--		end if;
--
--		clr_past_a <= clr_past_p;
--		odat       <= odat_p;
--	end process regs;
--end architecture behaviour;
