library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Experimental metadata only: never drives native GTE registers or timing.
-- X/Y are signed Q16.16 screen coordinates, retaining the existing projection
-- arithmetic's fractional bits (not recovering precision lost before MAC0).
entity gte_precision is
   port (
      clk                  : in  std_logic;
      ce                   : in  std_logic;
      invalidate           : in  std_logic;
      enable               : in  std_logic;
      push                 : in  std_logic;
      projection_valid     : in  std_logic;
      projected_x          : in  signed(34 downto 0);
      projected_y          : in  signed(34 downto 0);
      write_ena            : in  std_logic;
      write_addr           : in  unsigned(5 downto 0);
      read_ena             : in  std_logic;
      read_addr            : in  unsigned(5 downto 0);
      read_valid           : out std_logic := '0';
      read_x               : out signed(31 downto 0) := (others => '0');
      read_y               : out signed(31 downto 0) := (others => '0')
   );
end entity;

architecture rtl of gte_precision is
   type coordinates is array (0 to 2) of signed(31 downto 0);
   signal x, y : coordinates := (others => (others => '0'));
   signal valid : std_logic_vector(0 to 2) := (others => '0');
begin
   process (clk)
      variable slot : integer range 0 to 2;
   begin
      if rising_edge(clk) then
         -- Do this even when CE is low. Savestates contain no precision data,
         -- and disabling/re-enabling must not resurrect stale metadata.
         if invalidate = '1' or enable = '0' then
            x <= (others => (others => '0'));
            y <= (others => (others => '0'));
            valid <= (others => '0');
            read_valid <= '0';
            read_x <= (others => '0');
            read_y <= (others => '0');
         elsif ce = '1' then
            -- Same registered read latency and read-before-write semantics as
            -- gte_readData. Register 15 aliases SXY2 on reads.
            if read_ena = '1' then
               read_valid <= '0';
               read_x <= (others => '0');
               read_y <= (others => '0');
               if read_addr >= 12 and read_addr <= 15 then
                  slot := 2;
                  if read_addr < 14 then
                     slot := to_integer(read_addr) - 12;
                  end if;
                  read_valid <= valid(slot);
                  if valid(slot) = '1' then
                     read_x <= x(slot);
                     read_y <= y(slot);
                  end if;
               end if;
            end if;

            -- A CPU write supplies only integers: never attach an older
            -- projection to the new word, even when its integer value matches.
            if write_ena = '1' then
               case to_integer(write_addr) is
                  when 12 | 13 | 14 =>
                     valid(to_integer(write_addr) - 12) <= '0';
                  when 15 =>
                     x(0) <= x(1); x(1) <= x(2);
                     y(0) <= y(1); y(1) <= y(2);
                     valid(0) <= valid(1); valid(1) <= valid(2);
                     valid(2) <= '0';
                  when others => null;
               end case;
            end if;

            -- Native projection writeback wins over CPU writes on the same
            -- edge. Shift old values, matching the native SXY FIFO exactly.
            if push = '1' then
               x(0) <= x(1); x(1) <= x(2);
               y(0) <= y(1); y(1) <= y(2);
               valid(0) <= valid(1); valid(1) <= valid(2);
               x(2) <= projected_x(31 downto 0);
               y(2) <= projected_y(31 downto 0);
               valid(2) <= '0';
               -- Match native integer clipping boundaries, including negative
               -- fractions. Reject either clipped axis or a divide overflow.
               if projection_valid = '1' and
                  projected_x(34 downto 16) >= -1024 and
                  projected_x(34 downto 16) <= 1023 and
                  projected_y(34 downto 16) >= -1024 and
                  projected_y(34 downto 16) <= 1023 then
                  valid(2) <= '1';
               end if;
            end if;
         end if;
      end if;
   end process;
end architecture;
