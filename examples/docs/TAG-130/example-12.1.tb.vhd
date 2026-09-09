library ieee;
use ieee.std_logic_1164.all;
use work.matterscript_ncl.all;

entity example_12_1_tb is
end example_12_1_tb;

architecture sim of example_12_1_tb is
  signal result   : ncl_signal;
  signal carryout : ncl_signal;
begin
  dut : entity work.fulladd_network
    port map(
      result   => result,
      carryout => carryout
    );

  check : process
  begin
    wait for 1 ns;

    assert result = data_value(1)
      report "unnamed FULLADD return should carry SUM = 1"
      severity failure;

    assert carryout = data_value(0)
      report "named FULLADD return should carry CARRY = 0"
      severity failure;

    report "PASS: unnamed and named source-place returns are correctly wired";
    wait;
  end process;
end sim;