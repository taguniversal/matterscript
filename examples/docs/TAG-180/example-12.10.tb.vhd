-- testbench for TAG-180 Example 12.10: bus
--
-- Reads example-12.10.tb.vec. Each row drives selector_in, selector_out,
-- q1..q4 and checks that the outM selected by selector_out equals the
-- qN selected by selector_in; the other three outN must be null_value.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.matterscript_ncl.all;

entity example_12_10_tb is
end example_12_10_tb;

architecture sim of example_12_10_tb is
  signal selector_in  : ncl_signal := null_value;
  signal selector_out : ncl_signal := null_value;
  signal q1 : ncl_signal := null_value;
  signal q2 : ncl_signal := null_value;
  signal q3 : ncl_signal := null_value;
  signal q4 : ncl_signal := null_value;
  signal out1 : ncl_signal;
  signal out2 : ncl_signal;
  signal out3 : ncl_signal;
  signal out4 : ncl_signal;
begin

  dut : entity work.ms_bus
    port map (
      selector_in  => selector_in,
      selector_out => selector_out,
      q1 => q1, q2 => q2, q3 => q3, q4 => q4,
      out1 => out1, out2 => out2, out3 => out3, out4 => out4
    );

  stimulus : process
    file vec : text open read_mode is "examples/docs/TAG-180/example-12.10.tb.vec";
    variable line_buf     : line;
    variable row_num      : integer := 0;
    variable si, so       : character;
    variable vq1, vq2, vq3, vq4 : character;
    variable expected     : ncl_signal;
    variable selected_m   : integer;
    -- Parse buffer for the comma-separated tokens.
    variable token        : string(1 to 8);
    variable token_len    : integer;

    -- Encode a selector letter to the ncl_signal's symbol payload.
    -- The emitter's symbol encoding for `select` is A=0, B=2, C=4, D=6
    -- (see fanout's case labels).
    function sel_value(letter : character) return ncl_signal is
    begin
      case letter is
        when 'A' => return data_value(0);
        when 'B' => return data_value(2);
        when 'C' => return data_value(4);
        when 'D' => return data_value(6);
        when others => return null_value;
      end case;
    end function;

    -- Encode a payload digit to a data_value.
    function payload_value(d : character) return ncl_signal is
    begin
      case d is
        when '0' => return data_value(0);
        when '1' => return data_value(1);
        when others => return null_value;
      end case;
    end function;

    -- Which output should be selected by a given selector_out letter?
    function selected_out(letter : character) return integer is
    begin
      case letter is
        when 'A' => return 1;
        when 'B' => return 2;
        when 'C' => return 3;
        when 'D' => return 4;
        when others => return 0;
      end case;
    end function;

    -- Read one comma-separated token from `line_buf`, advancing past
    -- the comma. Return the token as a single character.
    procedure next_char(
        variable l    : inout line;
        variable idx  : inout integer;
        variable c    : out character
        ) is
        begin
        -- Skip commas and whitespace. VHDL lines are 1-based; `idx` starts
        -- at 1 and advances past each consumed character.
        while idx <= l'right loop
            if l(idx) = ',' or l(idx) = ' ' or l(idx) = HT then
            idx := idx + 1;
            else
            exit;
            end if;
        end loop;
        if idx > l'right then
            c := ' ';  -- end of line
            return;
        end if;
        c := l(idx);
        idx := idx + 1;
  end procedure;
  begin
    while not endfile(vec) loop
      readline(vec, line_buf);
      row_num := row_num + 1;

      -- Skip blank lines and comments.
      if line_buf'length = 0 or line_buf(line_buf'left) = '#' then
        next;
      end if;

      -- Parse the six tokens.
      token_len := 1;
      next_char(line_buf, token_len, si);
      next_char(line_buf, token_len, so);
      next_char(line_buf, token_len, vq1);
      next_char(line_buf, token_len, vq2);
      next_char(line_buf, token_len, vq3);
      next_char(line_buf, token_len, vq4);

      -- Drive the inputs.
      selector_in  <= sel_value(si);
      selector_out <= sel_value(so);
      q1 <= payload_value(vq1);
      q2 <= payload_value(vq2);
      q3 <= payload_value(vq3);
      q4 <= payload_value(vq4);

      wait for 10 ns;

      -- Compute the expected value: the qN selected by selector_in.
      case si is
        when 'A' => expected := payload_value(vq1);
        when 'B' => expected := payload_value(vq2);
        when 'C' => expected := payload_value(vq3);
        when 'D' => expected := payload_value(vq4);
        when others => expected := null_value;
      end case;

      -- Compute which output selector_out selects.
      selected_m := selected_out(so);

      -- Check the selected output.
      case selected_m is
        when 1 =>
          assert out1 = expected
            report "row " & integer'image(row_num) & ": out1 mismatch"
            severity error;
        when 2 =>
          assert out2 = expected
            report "row " & integer'image(row_num) & ": out2 mismatch"
            severity error;
        when 3 =>
          assert out3 = expected
            report "row " & integer'image(row_num) & ": out3 mismatch"
            severity error;
        when 4 =>
          assert out4 = expected
            report "row " & integer'image(row_num) & ": out4 mismatch"
            severity error;
        when others => null;
      end case;

      -- Check the unselected outputs are null.
      if selected_m /= 1 then
        assert out1 = null_value
          report "row " & integer'image(row_num) & ": out1 should be null"
          severity error;
      end if;
      if selected_m /= 2 then
        assert out2 = null_value
          report "row " & integer'image(row_num) & ": out2 should be null"
          severity error;
      end if;
      if selected_m /= 3 then
        assert out3 = null_value
          report "row " & integer'image(row_num) & ": out3 should be null"
          severity error;
      end if;
      if selected_m /= 4 then
        assert out4 = null_value
          report "row " & integer'image(row_num) & ": out4 should be null"
          severity error;
      end if;
    end loop;

    report "bus_tb: " & integer'image(row_num) & " rows processed" severity note;
    std.env.stop;
  end process;

end sim;