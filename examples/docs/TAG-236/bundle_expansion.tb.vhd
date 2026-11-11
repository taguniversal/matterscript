library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.matterscript_ncl.all;

entity bundle_expansion_tb is
end bundle_expansion_tb;

architecture sim of bundle_expansion_tb is
  -- Inputs: 4-bit A, 4-bit B (LSB first), carry-in.
  signal a0, a1, a2, a3 : ncl_signal := null_value;
  signal b0, b1, b2, b3 : ncl_signal := null_value;
  signal cin : ncl_signal := null_value;

  -- Outputs: 4-bit SUM (LSB first), carry-out.
  signal sum0, sum1, sum2, sum3 : ncl_signal;
  signal cout : ncl_signal;
begin
  dut : entity work.adder4_network
    port map (
      a0 => a0, a1 => a1, a2 => a2, a3 => a3,
      b0 => b0, b1 => b1, b2 => b2, b3 => b3,
      cin => cin,
      sum0 => sum0, sum1 => sum1, sum2 => sum2, sum3 => sum3,
      cout => cout
    );

  check : process
  begin
    -- 0 + 0 + 0 = 0, carry 0
    a0 <= data_value(0); a1 <= data_value(0); a2 <= data_value(0); a3 <= data_value(0);
    b0 <= data_value(0); b1 <= data_value(0); b2 <= data_value(0); b3 <= data_value(0);
    cin <= data_value(0);
    wait for 5 ns;
    assert valid_of(sum0) = '1' and sum0(7 downto 1) = data_value(0)(7 downto 1) report "0+0+0: sum0" severity failure;
    assert valid_of(sum1) = '1' and sum1(7 downto 1) = data_value(0)(7 downto 1) report "0+0+0: sum1" severity failure;
    assert valid_of(sum2) = '1' and sum2(7 downto 1) = data_value(0)(7 downto 1) report "0+0+0: sum2" severity failure;
    assert valid_of(sum3) = '1' and sum3(7 downto 1) = data_value(0)(7 downto 1) report "0+0+0: sum3" severity failure;
    assert valid_of(cout) = '1' and cout(7 downto 1) = data_value(0)(7 downto 1) report "0+0+0: cout" severity failure;

    -- 0 + 0 + 1 = 1, carry 0
    cin <= data_value(1);
    wait for 5 ns;
    assert valid_of(sum0) = '1' and sum0(7 downto 1) = data_value(1)(7 downto 1) report "0+0+1: sum0" severity failure;
    assert valid_of(sum1) = '1' and sum1(7 downto 1) = data_value(0)(7 downto 1) report "0+0+1: sum1" severity failure;
    assert valid_of(sum2) = '1' and sum2(7 downto 1) = data_value(0)(7 downto 1) report "0+0+1: sum2" severity failure;
    assert valid_of(sum3) = '1' and sum3(7 downto 1) = data_value(0)(7 downto 1) report "0+0+1: sum3" severity failure;
    assert valid_of(cout) = '1' and cout(7 downto 1) = data_value(0)(7 downto 1) report "0+0+1: cout" severity failure;

    -- 1 + 0 + 0 = 1, carry 0
    a0 <= data_value(1); a1 <= data_value(0); a2 <= data_value(0); a3 <= data_value(0);
    b0 <= data_value(0); b1 <= data_value(0); b2 <= data_value(0); b3 <= data_value(0);
    cin <= data_value(0);
    wait for 5 ns;
    assert valid_of(sum0) = '1' and sum0(7 downto 1) = data_value(1)(7 downto 1) report "1+0+0: sum0" severity failure;
    assert valid_of(sum1) = '1' and sum1(7 downto 1) = data_value(0)(7 downto 1) report "1+0+0: sum1" severity failure;
    assert valid_of(sum2) = '1' and sum2(7 downto 1) = data_value(0)(7 downto 1) report "1+0+0: sum2" severity failure;
    assert valid_of(sum3) = '1' and sum3(7 downto 1) = data_value(0)(7 downto 1) report "1+0+0: sum3" severity failure;
    assert valid_of(cout) = '1' and cout(7 downto 1) = data_value(0)(7 downto 1) report "1+0+0: cout" severity failure;

    -- 1 + 1 + 0 = 2, carry 0
    a0 <= data_value(1); a1 <= data_value(0); a2 <= data_value(0); a3 <= data_value(0);
    b0 <= data_value(1); b1 <= data_value(0); b2 <= data_value(0); b3 <= data_value(0);
    cin <= data_value(0);
    wait for 5 ns;
    assert valid_of(sum0) = '1' and sum0(7 downto 1) = data_value(0)(7 downto 1) report "1+1+0: sum0" severity failure;
    assert valid_of(sum1) = '1' and sum1(7 downto 1) = data_value(1)(7 downto 1) report "1+1+0: sum1" severity failure;
    assert valid_of(sum2) = '1' and sum2(7 downto 1) = data_value(0)(7 downto 1) report "1+1+0: sum2" severity failure;
    assert valid_of(sum3) = '1' and sum3(7 downto 1) = data_value(0)(7 downto 1) report "1+1+0: sum3" severity failure;
    assert valid_of(cout) = '1' and cout(7 downto 1) = data_value(0)(7 downto 1) report "1+1+0: cout" severity failure;

    -- 1 + 1 + 1 = 3, carry 0
    a0 <= data_value(1); a1 <= data_value(0); a2 <= data_value(0); a3 <= data_value(0);
    b0 <= data_value(1); b1 <= data_value(0); b2 <= data_value(0); b3 <= data_value(0);
    cin <= data_value(1);
    wait for 5 ns;
    assert valid_of(sum0) = '1' and sum0(7 downto 1) = data_value(1)(7 downto 1) report "1+1+1: sum0" severity failure;
    assert valid_of(sum1) = '1' and sum1(7 downto 1) = data_value(1)(7 downto 1) report "1+1+1: sum1" severity failure;
    assert valid_of(sum2) = '1' and sum2(7 downto 1) = data_value(0)(7 downto 1) report "1+1+1: sum2" severity failure;
    assert valid_of(sum3) = '1' and sum3(7 downto 1) = data_value(0)(7 downto 1) report "1+1+1: sum3" severity failure;
    assert valid_of(cout) = '1' and cout(7 downto 1) = data_value(0)(7 downto 1) report "1+1+1: cout" severity failure;

    -- 15 + 1 + 0 = 16, carry 1 (all sum bits 0, cout=1)
    a0 <= data_value(1); a1 <= data_value(1); a2 <= data_value(1); a3 <= data_value(1);
    b0 <= data_value(1); b1 <= data_value(0); b2 <= data_value(0); b3 <= data_value(0);
    cin <= data_value(0);
    wait for 5 ns;
    assert valid_of(sum0) = '1' and sum0(7 downto 1) = data_value(0)(7 downto 1) report "15+1+0: sum0" severity failure;
    assert valid_of(sum1) = '1' and sum1(7 downto 1) = data_value(0)(7 downto 1) report "15+1+0: sum1" severity failure;
    assert valid_of(sum2) = '1' and sum2(7 downto 1) = data_value(0)(7 downto 1) report "15+1+0: sum2" severity failure;
    assert valid_of(sum3) = '1' and sum3(7 downto 1) = data_value(0)(7 downto 1) report "15+1+0: sum3" severity failure;
    assert valid_of(cout) = '1' and cout(7 downto 1) = data_value(1)(7 downto 1) report "15+1+0: cout" severity failure;

    -- 15 + 15 + 0 = 30, carry 1 (sum bits 1110, cout=1)
    a0 <= data_value(1); a1 <= data_value(1); a2 <= data_value(1); a3 <= data_value(1);
    b0 <= data_value(1); b1 <= data_value(1); b2 <= data_value(1); b3 <= data_value(1);
    cin <= data_value(0);
    wait for 5 ns;
    assert valid_of(sum0) = '1' and sum0(7 downto 1) = data_value(0)(7 downto 1) report "15+15+0: sum0" severity failure;
    assert valid_of(sum1) = '1' and sum1(7 downto 1) = data_value(1)(7 downto 1) report "15+15+0: sum1" severity failure;
    assert valid_of(sum2) = '1' and sum2(7 downto 1) = data_value(1)(7 downto 1) report "15+15+0: sum2" severity failure;
    assert valid_of(sum3) = '1' and sum3(7 downto 1) = data_value(1)(7 downto 1) report "15+15+0: sum3" severity failure;
    assert valid_of(cout) = '1' and cout(7 downto 1) = data_value(1)(7 downto 1) report "15+15+0: cout" severity failure;

    -- 15 + 15 + 1 = 31, carry 1 (sum bits 1111, cout=1)
    a0 <= data_value(1); a1 <= data_value(1); a2 <= data_value(1); a3 <= data_value(1);
    b0 <= data_value(1); b1 <= data_value(1); b2 <= data_value(1); b3 <= data_value(1);
    cin <= data_value(1);
    wait for 5 ns;
    assert valid_of(sum0) = '1' and sum0(7 downto 1) = data_value(1)(7 downto 1) report "15+15+1: sum0" severity failure;
    assert valid_of(sum1) = '1' and sum1(7 downto 1) = data_value(1)(7 downto 1) report "15+15+1: sum1" severity failure;
    assert valid_of(sum2) = '1' and sum2(7 downto 1) = data_value(1)(7 downto 1) report "15+15+1: sum2" severity failure;
    assert valid_of(sum3) = '1' and sum3(7 downto 1) = data_value(1)(7 downto 1) report "15+15+1: sum3" severity failure;
    assert valid_of(cout) = '1' and cout(7 downto 1) = data_value(1)(7 downto 1) report "15+15+1: cout" severity failure;

    report "bundle_expansion: 8/8 passed" severity note;
    std.env.stop;
  end process;
end sim;