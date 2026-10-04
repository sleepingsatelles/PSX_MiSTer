library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
library baseline;

entity tb_gte_precision is end;
architecture test of tb_gte_precision is
   signal clk1, clk2, idx : std_logic := '0';
   signal reset : std_logic := '1';
   signal ce, enable : std_logic := '1';
   signal re, we, cmd, loading, ss_reset, ss_we : std_logic := '0';
   signal ra, wa, ss_addr : unsigned(5 downto 0) := (others => '0');
   signal wd, command : unsigned(31 downto 0) := (others => '0');
   signal ss_wd : std_logic_vector(31 downto 0) := (others => '0');
   signal widescreen : std_logic_vector(1 downto 0) := "00";
   signal turbo : std_logic := '0';
   type words is array (0 to 1) of unsigned(31 downto 0);
   type ss_words is array (0 to 1) of std_logic_vector(31 downto 0);
   type precise_words is array (0 to 1) of signed(31 downto 0);
   signal rd : words;
   signal ss_rd : ss_words;
   signal busy, idle, debug, pv : std_logic_vector(0 to 1);
   signal px, py : precise_words;
   signal ref_rd : unsigned(31 downto 0);
   signal ref_ss : std_logic_vector(31 downto 0);
   signal ref_busy, ref_idle, ref_debug : std_logic;
   signal cycles : natural := 0;
begin
   clk1 <= not clk1 after 10 ns;
   clk2 <= not clk2 after 5 ns;
   process(clk2) begin if falling_edge(clk2) then idx <= not idx; end if; end process;

   reference : entity baseline.gte port map (
      clk1x => clk1, clk2x => clk2, clk2xIndex => idx, ce => ce, reset => reset,
      WIDESCREEN => widescreen, TURBO => turbo,
      gte_busy => ref_busy, gte_readAddr => ra, gte_readData => ref_rd, gte_readEna => re,
      gte_writeAddr_in => wa, gte_writeData_in => wd, gte_writeEna_in => we,
      gte_cmdData => command, gte_cmdEna => cmd,
      loading_savestate => loading, SS_reset => ss_reset, SS_DataWrite => ss_wd,
      SS_Adr => ss_addr, SS_wren => ss_we, SS_rden => '1', SS_DataRead => ref_ss,
      SS_idle => ref_idle, debug_firstGTE => ref_debug
   );
   variants : for i in 0 to 1 generate
      dut : entity work.gte generic map (PRECISION_CAPTURE => i = 1) port map (
         clk1x => clk1, clk2x => clk2, clk2xIndex => idx, ce => ce, reset => reset,
         WIDESCREEN => widescreen, TURBO => turbo,
         gte_busy => busy(i), gte_readAddr => ra, gte_readData => rd(i), gte_readEna => re,
         gte_writeAddr_in => wa, gte_writeData_in => wd, gte_writeEna_in => we,
         gte_cmdData => command, gte_cmdEna => cmd,
         loading_savestate => loading, SS_reset => ss_reset, SS_DataWrite => ss_wd,
         SS_Adr => ss_addr, SS_wren => ss_we, SS_rden => '1', SS_DataRead => ss_rd(i),
         SS_idle => idle(i), debug_firstGTE => debug(i), precision_enable => enable,
         precision_read_valid => pv(i), precision_read_x => px(i), precision_read_y => py(i)
      );
   end generate;

   -- Compare all original outputs on every half-rate edge, not just final
   -- register values. This detects extra busy cycles and savestate changes.
   process
   begin
      wait until rising_edge(clk2); wait for 2 ns;
      cycles <= cycles + 1;
      for i in 0 to 1 loop
         assert std_logic_vector(rd(i)) = std_logic_vector(ref_rd)
            report "native register response differs" severity failure;
         assert busy(i) = ref_busy and idle(i) = ref_idle and debug(i) = ref_debug
            report "native timing/status differs" severity failure;
         assert ss_rd(i) = ref_ss report "savestate response differs" severity failure;
      end loop;
      assert pv(0) = '0' and px(0) = 0 and py(0) = 0
         report "disabled build exposes metadata" severity failure;
      if pv(1) = '1' then
         assert px(1)(31 downto 16) = signed(rd(1)(15 downto 0)) and
                py(1)(31 downto 16) = signed(rd(1)(31 downto 16))
            report "metadata is not paired with the native read response" severity failure;
      end if;
   end process;

   process
      type opcodes is array (natural range <>) of natural;
      constant aspect_x : opcodes := (540672, 475136, 442368, 409600);
      constant ops : opcodes := (1, 6, 12, 16, 17, 18, 19, 20, 22, 27, 28,
                                30, 32, 40, 41, 42, 45, 46, 48, 61, 62, 63);
      variable seed : unsigned(31 downto 0) := x"137AC529";
      procedure tick is begin wait until rising_edge(clk2); wait for 3 ns; end;
      procedure setup is
      begin
         wait until falling_edge(clk2); wait for 1 ns;
         while idx /= '1' loop wait until falling_edge(clk2); wait for 1 ns; end loop;
      end;
      procedure write_reg(addr : natural; value : unsigned(31 downto 0)) is
      begin
         setup; wa <= to_unsigned(addr, 6); wd <= value; we <= '1';
         tick; we <= '0';
      end;
      procedure read_reg(addr : natural) is
      begin
         ra <= to_unsigned(addr, 6); ss_addr <= to_unsigned(addr, 6);
         re <= '1'; tick; re <= '0';
      end;
      procedure execute(value : unsigned(31 downto 0)) is
         variable done : boolean := false;
      begin
         setup; command <= value; cmd <= '1'; tick; cmd <= '0';
         assert ref_busy = '1' report "command not accepted" severity failure;
         for j in 0 to 300 loop
            tick;
            if ref_busy = '0' then done := true; exit; end if;
         end loop;
         assert done report "command did not finish" severity failure;
      end;
      procedure expect_precise(addr : natural; a, b : integer) is
      begin
         read_reg(addr);
         assert pv(1) = '1' and px(1) = a and py(1) = b
            report "wrong integrated precision result at " & integer'image(addr) severity failure;
      end;
      procedure randomize is
      begin
         seed := seed(30 downto 0) & (seed(31) xor seed(21) xor seed(1) xor seed(0));
      end;
   begin
      for j in 0 to 9 loop tick; end loop;
      reset <= '0'; tick;
      -- Identity transform, H/Z = 1/2, fractional OFX/OFY.
      write_reg(32, x"00001000"); write_reg(34, x"00001000"); write_reg(36, x"00001000");
      write_reg(56, x"00004000"); write_reg(57, x"FFFFC000"); write_reg(58, x"00000100");
      write_reg(0, x"FFFD0003"); write_reg(1, x"00000200");
      execute(x"00080001"); -- RTPS sf=1
      expect_precise(14, 114688, -114688); expect_precise(15, 114688, -114688);
      write_reg(0, x"FFFD0010");
      for mode in 0 to 3 loop
         widescreen <= std_logic_vector(to_unsigned(mode, 2));
         execute(x"00080001"); expect_precise(14, aspect_x(mode), -114688);
      end loop;
      widescreen <= "00"; write_reg(0, x"FFFD0003");
      -- All three RTPT results must stay paired with their native FIFO entry.
      write_reg(2, x"FFFB0005"); write_reg(3, x"00000200");
      write_reg(4, x"FFF90007"); write_reg(5, x"00000200");
      execute(x"00080030");
      expect_precise(12, 114688, -114688);
      expect_precise(13, 180224, -180224);
      expect_precise(14, 245760, -245760);
      write_reg(15, x"00020001");
      expect_precise(12, 180224, -180224); expect_precise(13, 245760, -245760);
      read_reg(14); assert pv(1) = '0' severity failure;
      write_reg(12, x"00000000"); read_reg(12); assert pv(1) = '0' severity failure;
      write_reg(13, x"00000000"); read_reg(13); assert pv(1) = '0' severity failure;
      write_reg(14, x"00000000"); read_reg(14); assert pv(1) = '0' severity failure;
      -- Native screen clipping and divide overflow must cause fallback.
      write_reg(0, x"00000BB8"); execute(x"00080001");
      read_reg(14); assert pv(1) = '0' severity failure;
      write_reg(0, x"00010001"); write_reg(1, x"00000001"); execute(x"00080001");
      read_reg(14); assert pv(1) = '0' severity failure;
      write_reg(1, x"00000200"); execute(x"00080001");
      read_reg(14); assert pv(1) = '1' severity failure;
      ce <= '0'; enable <= '0'; tick; enable <= '1'; ce <= '1';
      read_reg(14); assert pv(1) = '0' severity failure;
      execute(x"00080001"); read_reg(14); assert pv(1) = '1' severity failure;
      -- Restore invalidates the whole metadata FIFO without adding state words.
      setup; loading <= '1'; ss_we <= '1'; ss_addr <= to_unsigned(14, 6); ss_wd <= x"00040003";
      tick; ss_we <= '0'; loading <= '0';
      for j in 12 to 15 loop read_reg(j); assert pv(1) = '0' severity failure; end loop;
      execute(x"00080001"); read_reg(14); assert pv(1) = '1' severity failure;
      ss_reset <= '1'; tick; ss_reset <= '0'; read_reg(14); assert pv(1) = '0' severity failure;

      -- Deterministic stress: every supported command, all registers, shift/
      -- limit/matrix selectors, widescreen settings, and normal/turbo timing.
      for pass in 0 to 7 loop
         widescreen <= std_logic_vector(to_unsigned(pass mod 4, 2));
         if pass >= 4 then turbo <= '1'; end if;
         for j in 0 to 63 loop randomize; write_reg(j, seed); end loop;
         for op in ops'range loop
            randomize;
            execute((seed and x"000FFC00") or to_unsigned(ops(op), 32));
            for j in 0 to 63 loop read_reg(j); end loop;
         end loop;
         ce <= '0'; for j in 0 to 3 loop tick; end loop; ce <= '1';
      end loop;
      reset <= '1'; for j in 0 to 5 loop tick; end loop; reset <= '0';
      for j in 12 to 15 loop read_reg(j); assert pv(1) = '0' severity failure; end loop;
      report "PASS: original GTE outputs match in both builds for " & integer'image(cycles) & " cycles";
      finish;
   end process;
   process begin wait for 10 ms; assert false report "watchdog" severity failure; end process;
end;
