library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.matterscript_ncl.all;

entity example_12_36_tb is
end example_12_36_tb;

architecture sim of example_12_36_tb is
  signal a, b : ncl_signal := null_value;
  signal result : ncl_signal;

  type row_t is record
    a_sym : integer;    -- 0 = FALSE, 1 = TRUE
    b_sym : integer;
    expected : integer; -- 0 = FALSE, 1 = TRUE
  end record;

  type vector_array_t is array (natural range <>) of row_t;
  constant vectors : vector_array_t := (
    (a_sym => 1, b_sym => 1, expected => 1),  -- TRUE, TRUE   → TRUE
    (a_sym => 1, b_sym => 0, expected => 0),  -- TRUE, FALSE  → FALSE
    (a_sym => 0, b_sym => 1, expected => 0),  -- FALSE, TRUE  → FALSE
    (a_sym => 0, b_sym => 0, expected => 1)   -- FALSE, FALSE → TRUE
  );
begin
  dut : entity work.tag163_top
    port map (
      a => a,
      b => b,
      result => result
    );

  check : process
    variable pass_count : integer := 0;
    variable total : integer := vectors'length;
  begin
    for i in vectors'range loop
      a <= null_value;
      b <= null_value;
      wait for 1 ns;

      a <= data_value(vectors(i).a_sym);
      b <= data_value(vectors(i).b_sym);
      wait for 5 ns;

      assert valid_of(result) = '1'
        report "row " & integer'image(i) & ": expected result valid"
        severity failure;

      assert result(7 downto 1) = std_logic_vector(to_unsigned(vectors(i).expected, 7))
        report "row " & integer'image(i) & ": result symbol mismatch"
        severity failure;

      pass_count := pass_count + 1;
    end loop;

    report "example-12.36: " & integer'image(pass_count) & "/" &
           integer'image(total) & " passed" severity note;
    std.env.stop;
  end process;
end sim;