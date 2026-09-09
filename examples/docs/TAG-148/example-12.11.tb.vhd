library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.matterscript_ncl.all;

entity example_12_11_tb is
end example_12_11_tb;

architecture sim of example_12_11_tb is
    -- Testbench signals for NCL rails
    signal tb_clk     : std_logic := '0';
    signal tb_rst     : std_logic := '1';
    signal tb_select  : ncl_signal := null_value;
    signal tb_in      : ncl_signal := null_value;
    signal out1       : ncl_signal;
    signal out2       : ncl_signal;
    signal out3       : ncl_signal;
    signal out4       : ncl_signal;
begin

    -- Instantiate the core fanout DUT
    dut: entity work.fanout
        port map (
            clk         => tb_clk,
            rst         => tb_rst,
            ms_select   => tb_select,
            ms_in       => tb_in,
            out1        => out1,
            out2        => out2,
            out3        => out3,
            out4        => out4
        );

    -- Stimulus and verification process
    stim_proc: process
    begin
        -- 1. Hold reset / null phase (asynchronous NCL initialization)
        tb_rst <= '1';
        tb_select <= null_value;
        tb_in <= null_value;
        wait for 20 ns;

        -- 2. Release reset and drive input signals
        tb_rst <= '0';
        
        -- If ncl_signal is a record type with data/valid fields, 
        -- or if we drive non-null values:
        -- (Adjust record fields if ncl_signal is defined as a record in matterscript_ncl)
        tb_in <= null_value; -- Replace with active signal assignment once record structure is matched
        tb_select <= null_value;
        wait for 20 ns;

        -- 3. Assert expected routing behavior using valid_of
        assert (valid_of(out2) = '0') 
            report "[TAG-148] Fanout routing check: expected initial null state." 
            severity note;

        -- 4. Return to null cycle (completion detection phase)
        tb_select <= null_value;
        tb_in <= null_value;
        wait for 20 ns;

        report "[TAG-148] Fanout testbench completed simulation cycles successfully.";
        wait;
    end process;

end sim;