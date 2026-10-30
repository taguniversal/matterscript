-- Testbench for TAG-149 (example-12.9): mutex completeness
-- Drives one member of each mutex source group per wavefront and
-- checks the destination group's response.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.matterscript_ncl.all;

entity example_12_9_tb is
end example_12_9_tb;

architecture sim of example_12_9_tb is
  signal a0 : ncl_signal := null_value;
  signal a1 : ncl_signal := null_value;
  signal b0 : ncl_signal := null_value;
  signal b1 : ncl_signal := null_value;
  signal ms_0 : ncl_signal;
  signal ms_1 : ncl_signal;

  type row_t is record
    a0_v : std_logic;
    a1_v : std_logic;
    b0_v : std_logic;
    b1_v : std_logic;
    ms_0_v : std_logic;
    ms_1_v : std_logic;
    ms_0_sym : integer;  -- -1 for "expect null"
    ms_1_sym : integer;
  end record;

  type vector_array_t is array (natural range <>) of row_t;
  constant vectors : vector_array_t := (
    -- A0=valid, B0=valid  → ms_0 = 0, ms_1 = null
    (a0_v => '1', a1_v => '0', b0_v => '1', b1_v => '0',
     ms_0_v => '1', ms_1_v => '0', ms_0_sym => 0, ms_1_sym => -1),
    -- A0=valid, B1=valid  → ms_0 = null, ms_1 = 1
    (a0_v => '1', a1_v => '0', b0_v => '0', b1_v => '1',
     ms_0_v => '0', ms_1_v => '1', ms_0_sym => -1, ms_1_sym => 1),
    -- A1=valid, B0=valid  → ms_0 = null, ms_1 = 1
    (a1_v => '1', a0_v => '0', b0_v => '1', b1_v => '0',
     ms_0_v => '0', ms_1_v => '1', ms_0_sym => -1, ms_1_sym => 1),
    -- A1=valid, B1=valid  → ms_0 = null, ms_1 = 1
    (a1_v => '1', a0_v => '0', b0_v => '0', b1_v => '1',
     ms_0_v => '0', ms_1_v => '1', ms_0_sym => -1, ms_1_sym => 1)
  );
begin
  dut : entity work.ms_or149
    port map (
      a0 => a0, a1 => a1,
      b0 => b0, b1 => b1,
      ms_0 => ms_0, ms_1 => ms_1
    );

  stim : process
    variable pass_count : integer := 0;
    variable total : integer := vectors'length;
  begin
    for i in vectors'range loop
      -- Reset to null.
      a0 <= null_value; a1 <= null_value;
      b0 <= null_value; b1 <= null_value;
      wait for 1 ns;

      -- Drive this row's inputs.
      if vectors(i).a0_v = '1' then a0 <= data_value(0); end if;
      if vectors(i).a1_v = '1' then a1 <= data_value(1); end if;
      if vectors(i).b0_v = '1' then b0 <= data_value(0); end if;
      if vectors(i).b1_v = '1' then b1 <= data_value(1); end if;
      wait for 1 ns;

      -- Check ms_0.
      if vectors(i).ms_0_v = '1' then
        assert valid_of(ms_0) = '1'
          report "row " & integer'image(i) & ": expected ms_0 valid"
          severity failure;
        assert ms_0(7 downto 1) = std_logic_vector(to_unsigned(vectors(i).ms_0_sym, 7))
          report "row " & integer'image(i) & ": ms_0 symbol mismatch"
          severity failure;
      else
        assert valid_of(ms_0) = '0'
          report "row " & integer'image(i) & ": expected ms_0 null"
          severity failure;
      end if;

      -- Check ms_1.
      if vectors(i).ms_1_v = '1' then
        assert valid_of(ms_1) = '1'
          report "row " & integer'image(i) & ": expected ms_1 valid"
          severity failure;
        assert ms_1(7 downto 1) = std_logic_vector(to_unsigned(vectors(i).ms_1_sym, 7))
          report "row " & integer'image(i) & ": ms_1 symbol mismatch"
          severity failure;
      else
        assert valid_of(ms_1) = '0'
          report "row " & integer'image(i) & ": expected ms_1 null"
          severity failure;
      end if;

      pass_count := pass_count + 1;
    end loop;

    report "example-12.9: " & integer'image(pass_count) & "/" & integer'image(total) & " passed"
      severity note;
    std.env.stop;
  end process;
end sim;