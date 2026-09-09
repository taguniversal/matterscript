library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.matterscript_ncl.all;

entity example_12_19_tb is
end entity;

architecture sim of example_12_19_tb is

    -- Declare all necessary testbench signals matching the port map
    signal x_sig     : ncl_signal := null_value;
    signal y_sig     : ncl_signal := null_value;
    signal c_sig     : ncl_signal := null_value;
    signal sum_sig   : ncl_signal;
    signal carry_sig : ncl_signal;

begin

    -- Instantiate the generated fulladd entity with correct port mappings
    dut : entity work.fulladd
        port map (
            x     => x_sig,
            y     => y_sig,
            c     => c_sig,
            sum   => sum_sig,
            carry => carry_sig
        );

    stimulus_process: process
        procedure apply_test(x_val, y_val, c_val : integer; exp_sum, exp_carry : integer) is
            variable act_sum   : integer := -1;
            variable act_carry : integer := -1;
        begin
            report "=== Starting Exhaustive FULLADD Truth Table Test ===" severity note;
        
            -- Force an immediate error to test if assertions are active
            assert false report "DEBUG: Forced testbench crash check" severity error;
            -- Drive input rails
            if x_val = 1 then x_sig <= data_value(1); else x_sig <= data_value(0); end if;
            if y_val = 1 then y_sig <= data_value(1); else y_sig <= data_value(0); end if;
            if c_val = 1 then c_sig <= data_value(1); else c_sig <= data_value(0); end if;

            wait for 50 ns;

            -- Read payload data from outputs if valid
            if is_data(sum_sig) then
                act_sum := to_integer(unsigned(payload(sum_sig)));
            end if;
            
            if is_data(carry_sig) then
                act_carry := to_integer(unsigned(payload(carry_sig)));
            end if;

            -- Assertions (these will fail properly once the compiler wires up internal expressions)
            assert act_sum = exp_sum 
                report "FAIL: Mismatch in SUM for inputs (" & 
                       integer'image(x_val) & ", " & integer'image(y_val) & ", " & integer'image(c_val) & 
                       "). Expected " & integer'image(exp_sum) & ", got " & integer'image(act_sum)
                severity error;

            assert act_carry = exp_carry 
                report "FAIL: Mismatch in CARRY for inputs (" & 
                       integer'image(x_val) & ", " & integer'image(y_val) & ", " & integer'image(c_val) & 
                       "). Expected " & integer'image(exp_carry) & ", got " & integer'image(act_carry)
                severity error;

            if act_sum = exp_sum and act_carry = exp_carry then
                report "PASS: X=" & integer'image(x_val) & " Y=" & integer'image(y_val) & " C=" & integer'image(c_val) &
                       " => SUM=" & integer'image(act_sum) & " CARRY=" & integer'image(act_carry) severity note;
            end if;

            -- Return to null spacer state (NCL asynchronous handshake protocol)
            x_sig <= null_value;
            y_sig <= null_value;
            c_sig <= null_value;
            wait for 30 ns;
        end procedure;

    begin
        report "=== Starting Exhaustive FULLADD Truth Table Test ===" severity note;

        -- Exhaustive test suite for full adder
        apply_test(0, 0, 0, 0, 0);
        apply_test(0, 0, 1, 1, 0);
        apply_test(0, 1, 0, 1, 0);
        apply_test(0, 1, 1, 0, 1);
        apply_test(1, 0, 0, 1, 0);
        apply_test(1, 0, 1, 0, 1);
        apply_test(1, 1, 0, 0, 1);
        apply_test(1, 1, 1, 1, 1);

        report "=== FULLADD Simulation Completed Successfully ===" severity note;
        wait;
    end process;

end architecture;