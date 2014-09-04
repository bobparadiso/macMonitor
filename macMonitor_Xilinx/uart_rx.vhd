----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:03:18 08/31/2014 
-- Design Name: 
-- Module Name:    uart_rx - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity uart_rx is
    Port (
		clk : in  STD_LOGIC;
		rx : in  STD_LOGIC;

		fifo_in : out std_logic_vector(7 downto 0);
		fifo_we : out std_logic;
		fifo_full : in std_logic
		);
end uart_rx;

architecture Behavioral of uart_rx is

type RECEIVE_MSG_STATES is (IDLE, SAMPLING, STOPBIT);
signal receiveMsgState : RECEIVE_MSG_STATES := IDLE;

type FIFO_STATES is (IDLE, WRITING);
signal fifoState : FIFO_STATES := IDLE;

signal rx_counter : std_logic_vector(12 downto 0) := (others => '0');
signal oversample_counter : std_logic_vector(2 downto 0) := (others => '0');
signal bit_filter : std_logic_vector(1 downto 0) := (others => '1');
signal rx_bit : std_logic := '1';
signal oversample : std_logic := '0';
signal sampleNow : std_logic := '0';
signal rx_data : std_logic_vector(7 downto 0) := (others => '0');
signal rx_busyshiftreg : std_logic_vector(7 downto 0) := (others => '0');

begin

--for one clock during the STOPBIT, push data into fifo
fillFifo: process(clk)
begin
if (rising_edge(clk)) then

	case fifoState is
		when IDLE =>
			if ((receiveMsgState = STOPBIT) and (rx_counter = 0) and (oversample_counter = 0)) then
				fifo_in <= rx_data;
				fifo_we <= '1';
				fifoState <= WRITING;
			end if;
		
		when WRITING =>
			fifoState <= IDLE;
			fifo_we <= '0';
			
		when others =>
			fifoState <= IDLE;
			fifo_we <= '0';
			
	end case;
	
end if;
end process;

createOversampleTick: process(clk)
begin
if (rising_edge(clk)) then

	--16MHz / (9600bps * 8oversample) = 208 clocks
	--16MHz / (19200bps * 8oversample) = 104 clocks
	--16MHz / (38400bps * 8oversample) = 52 clocks
	--16MHz / (57600bps * 8oversample) = 34 clocks
	--16MHz / (115200bps * 8oversample) = 16 clocks
	if (rx_counter = 15) then
		rx_counter <= rx_counter+1;

		if (oversample_counter = 4) then
			sampleNow <= '1';
		else
			sampleNow <= '0';
		end if;
		
		if (receiveMsgState = IDLE) then
			oversample_counter <= (others => '0');
		else
			oversample_counter <= oversample_counter + 1;--wrap around will bring back to 0
		end if;
	elsif (rx_counter = 16) then
		rx_counter <= (others => '0');
		oversample <= '1';
	else
		rx_counter <= rx_counter+1;
		oversample <= '0';
	end if;
	
end if;
end process;

receiveBit: process(oversample)
begin
if rising_edge(oversample) then

	if (bit_filter = "11") then
		rx_bit <= '1';
	elsif (bit_filter = "00") then
		rx_bit <= '0';
	end if;

	if (rx = '1' and bit_filter /= "11") then
		bit_filter <= bit_filter + 1;
	elsif (rx = '0' and bit_filter /= "00") then
		bit_filter <= bit_filter - 1;
	end if;

end if;
end process;

receiveMsg: process(oversample)
begin
if rising_edge(oversample) then
	case receiveMsgState is
		
		when IDLE =>
			if (rx_bit = '0') then
				receiveMsgState <= SAMPLING;
				rx_busyshiftreg <= (others => '0');
				rx_data <= (others => '0');
			end if;
		
		when SAMPLING =>
			if (sampleNow = '1') then
				rx_data <= rx_bit & rx_data(7 downto 1);
				rx_busyshiftreg <= '1' & rx_busyshiftreg(7 downto 1);
				if (rx_busyshiftreg(0) = '1') then
					receiveMsgState <= STOPBIT;
				end if;
			end if;
		
		when STOPBIT =>
			if (sampleNow = '1') then
				receiveMsgState <= IDLE;
			end if;
			
		when others =>
			receiveMsgState <= IDLE;

	end case;
end if;	
end process;

end Behavioral;

