library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.matterscript_ncl.all;

entity example_12_17_tb is
end example_12_17_tb;

architecture sim of example_12_17_tb is
  signal a0, a1, b0, b1 : ncl_signal := null_value;
  signal ms_0, ms_1 : ncl_signal;
begin
  dut : entity work.or151
    port map (
      a0 => a0, a1 => a1,
      b0 => b0, b1 => b1,
      ms_0 => ms_0, ms_1 => ms_1
    );

  check : process
    alias complete_sig is << signal .example_12_17_tb.dut.complete : std_logic >>;
  begin
    -- All null: complete should be '0'.
    wait for 5 ns;
    assert complete_sig = '0'
      report "complete should be '0' with all inputs null"
      severity failure;

    -- Mutex-valid: A0 + B0.
    a0 <= data_value(0);
    b0 <= data_value(0);
    wait for 5 ns;
    assert complete_sig = '1'
      report "complete should assert with A0 + B0 valid"
      severity failure;

    -- Stubs don't fire for this input combination (see comment
    -- in the .ms.ipl: 3of6 needs 6 valid inputs but mutex allows
    -- at most 2; 2of2 would fire only if a narrow key matched).
    -- So ms_0 and ms_1 should remain null.
    assert valid_of(ms_0) = '0'
      report "ms_0 should be null: stub 2of2 doesn't fire for this input"
      severity failure;
    assert valid_of(ms_1) = '0'
      report "ms_1 should be null: stub 3of6 doesn't fire for this input"
      severity failure;

    -- Mutex-valid: A1 + B1.
    a0 <= null_value; b0 <= null_value;
    a1 <= data_value(1); b1 <= data_value(1);
    wait for 5 ns;
    assert complete_sig = '1'
      report "complete should assert with A1 + B1 valid"
      severity failure;

    -- Reset.
    a1 <= null_value; b1 <= null_value;
    wait for 5 ns;
    assert complete_sig = '0'
      report "complete should deassert after reset"
      severity failure;

    report "example-12.17 structural test passed" severity note;
    std.env.stop;
  end process;
end sim;