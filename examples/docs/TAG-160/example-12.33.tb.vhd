library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.matterscript_ncl.all;

entity example_12_33_tb is
end example_12_33_tb;

architecture sim of example_12_33_tb is
  signal a, b : ncl_signal := null_value;
  signal ms_result : ncl_signal;
begin
  dut : entity work.or180
    port map (a => a, b => b, ms_result => ms_result);

  check : process
  begin
    -- (0,0) → 0
    a <= data_value(0); b <= data_value(0);
    wait for 5 ns;
    assert valid_of(ms_result) = '1' report "0,0: expected valid" severity failure;
    assert ms_result(7 downto 1) = data_value(0)(7 downto 1) report "0,0: expected symbol 0" severity failure;

    -- (0,1) → 1
    a <= data_value(0); b <= data_value(1);
    wait for 5 ns;
    assert valid_of(ms_result) = '1' report "0,1: expected valid" severity failure;
    assert ms_result(7 downto 1) = data_value(1)(7 downto 1) report "0,1: expected symbol 1" severity failure;

    -- (1,0) → 1
    a <= data_value(1); b <= data_value(0);
    wait for 5 ns;
    assert valid_of(ms_result) = '1' report "1,0: expected valid" severity failure;
    assert ms_result(7 downto 1) = data_value(1)(7 downto 1) report "1,0: expected symbol 1" severity failure;

    -- (1,1) → 1
    a <= data_value(1); b <= data_value(1);
    wait for 5 ns;
    assert valid_of(ms_result) = '1' report "1,1: expected valid" severity failure;
    assert ms_result(7 downto 1) = data_value(1)(7 downto 1) report "1,1: expected symbol 1" severity failure;

    report "example-12.33: 4/4 passed" severity note;
    std.env.stop;
  end process;
end sim;