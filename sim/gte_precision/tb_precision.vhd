library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_precision is end;
architecture test of tb_precision is
   signal clk : std_logic := '0';
   signal ce, enable, projection_valid : std_logic := '1';
   signal invalidate, push, we, re : std_logic := '0';
   signal px, py : signed(34 downto 0) := (others => '0');
   signal wa, ra : unsigned(5 downto 0) := (others => '0');
   signal valid : std_logic;
   signal x, y : signed(31 downto 0);
begin
   clk <= not clk after 5 ns;
   dut : entity work.gte_precision port map (
      clk, ce, invalidate, enable, push, projection_valid, px, py,
      we, wa, re, ra, valid, x, y
   );
   process
      procedure tick is begin wait until rising_edge(clk); wait for 1 ns; end;
      procedure project(a, b : integer) is
      begin
         px <= to_signed(a, 35); py <= to_signed(b, 35);
         push <= '1'; tick; push <= '0';
      end;
      procedure check(addr : natural; expected_valid : std_logic; a, b : integer := 0) is
      begin
         ra <= to_unsigned(addr, 6); re <= '1'; tick; re <= '0';
         assert valid = expected_valid report "unexpected precision validity at " & integer'image(addr) severity failure;
         if expected_valid = '1' then
            assert x = a and y = b report "wrong fractional coordinate" severity failure;
         else
            assert x = 0 and y = 0 report "invalid response must be zero" severity failure;
         end if;
      end;
      procedure write_slot(addr : natural) is
      begin wa <= to_unsigned(addr, 6); we <= '1'; tick; we <= '0'; end;
   begin
      invalidate <= '1'; tick; invalidate <= '0';
      for i in 12 to 15 loop check(i, '0'); end loop;
      project(81920, -81920); -- +1.25, -1.25
      project(163840, -163840);
      project(245760, -245760);
      check(12, '1', 81920, -81920);
      check(13, '1', 163840, -163840);
      check(14, '1', 245760, -245760);
      check(15, '1', 245760, -245760);
      check(11, '0'); check(44, '0');

      -- Reads see the old FIFO on a simultaneous projection/write.
      ra <= to_unsigned(14, 6); re <= '1';
      project(327680, -327680); re <= '0';
      assert valid = '1' and x = 245760 and y = -245760 severity failure;
      check(14, '1', 327680, -327680);
      write_slot(13); check(13, '0');
      check(12, '1', 163840, -163840);
      write_slot(15);
      check(12, '0'); check(13, '1', 327680, -327680); check(14, '0');
      write_slot(12); check(12, '0');
      project(1, -1); write_slot(14); check(14, '0');

      -- Clipping uses the native floor-to-integer bounds, not real bounds.
      project(-1024 * 65536, 1024 * 65536 - 1);
      check(14, '1', -1024 * 65536, 1024 * 65536 - 1);
      project(-1024 * 65536 - 1, 0); check(14, '0');
      project(0, 1024 * 65536); check(14, '0');
      project(1024 * 65536, 0); check(14, '0');
      project(0, -1024 * 65536 - 1); check(14, '0');
      projection_valid <= '0'; project(1, 2); check(14, '0');
      projection_valid <= '1';

      project(13, 17); check(14, '1', 13, 17);
      ce <= '0'; project(19, 23); write_slot(14);
      assert valid = '1' and x = 13 and y = 17 severity failure;
      ce <= '1'; check(14, '1', 13, 17);
      ce <= '0'; enable <= '0'; tick;
      assert valid = '0' and x = 0 and y = 0 severity failure;
      enable <= '1'; ce <= '1'; check(14, '0');
      project(29, 31); ce <= '0'; invalidate <= '1'; tick;
      invalidate <= '0'; ce <= '1'; check(14, '0');

      -- Projection has the same priority as the native FIFO, even when a CPU
      -- write targets an earlier entry on the same edge.
      project(37, 41); project(43, 47);
      wa <= to_unsigned(13, 6); we <= '1'; project(53, 59); we <= '0';
      check(12, '1', 37, 41); check(13, '1', 43, 47); check(14, '1', 53, 59);
      report "PASS: precision FIFO fractions, alias, writes, clipping, stalls, invalidation, priority";
      finish;
   end process;
   process begin wait for 100 us; assert false report "watchdog" severity failure; end process;
end;
