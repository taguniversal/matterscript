library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package matterscript_ncl is
	constant DATA_WIDTH : positive := 7;
	constant SIGNAL_WIDTH : positive := DATA_WIDTH + 1;

	subtype ncl_signal is std_logic_vector(SIGNAL_WIDTH - 1 downto 0);
	subtype ncl_payload is std_logic_vector(DATA_WIDTH - 1 downto 0);

	function is_null(signal_value : ncl_signal) return boolean;
	function is_data(signal_value : ncl_signal) return boolean;
	function payload(signal_value : ncl_signal) return ncl_payload;
	function null_value return ncl_signal;
	function data_value(value : natural) return ncl_signal;
end package matterscript_ncl;

package body matterscript_ncl is
	function is_null(signal_value : ncl_signal) return boolean is
	begin
		return signal_value(0) = '0';
	end function;

	function is_data(signal_value : ncl_signal) return boolean is
	begin
		return signal_value(0) = '1';
	end function;

	function payload(signal_value : ncl_signal) return ncl_payload is
	begin
		return signal_value(SIGNAL_WIDTH - 1 downto 1);
	end function;

	function null_value return ncl_signal is
	begin
		return (others => '0');
	end function;

	function data_value(value : natural) return ncl_signal is
	begin
		return std_logic_vector(to_unsigned(value, DATA_WIDTH)) & '1';
	end function;
end package body matterscript_ncl;
