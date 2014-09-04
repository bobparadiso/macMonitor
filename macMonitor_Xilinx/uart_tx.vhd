----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:41:34 08/31/2014 
-- Design Name: 
-- Module Name:    uart_tx - Behavioral 
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

entity uart_tx is
    Port (
		clk : in  STD_LOGIC;
		tx : out STD_LOGIC;
		
		fifo_out : in std_logic_vector(7 downto 0);
		fifo_re : out std_logic;
		fifo_empty : in std_logic
		);
end uart_tx;

architecture Behavioral of uart_tx is

signal busyshiftreg : std_logic_vector(9 downto 0) := (others => '0');
signal datashiftreg : std_logic_vector(9 downto 0) := (others => '1');
signal tx_counter : std_logic_vector(12 downto 0) := (others => '0');

type SEND_MSG_STATES is (IDLE, SENDING);
signal sendMsgState : SEND_MSG_STATES := IDLE;

begin

tx <= datashiftreg(0);

--grabs from fifo and actually sends data
sendMsg: process(clk)
begin
if rising_edge(clk) then
case sendMsgState is
	
	--check for data in fifo to send
	when IDLE =>
		if (fifo_empty /= '1') then
			fifo_re <= '1';
			datashiftreg <= '1' & fifo_out & '0';
			busyshiftreg <= (others => '1');
			tx_counter <= (others => '0');
			sendMsgState <= SENDING;
		else
			fifo_re <= '0';
		end if;

	--send it
	when SENDING =>
		fifo_re <= '0';
		--finished
		if busyshiftreg(0) = '0' then
			sendMsgState <= IDLE;
		--processing
		else
			--16MHz / 9600bps = 1667 clocks
			if tx_counter = 1666 then
				datashiftreg <= '1' & datashiftreg(9 downto 1);
				busyshiftreg <= '0' & busyshiftreg(9 downto 1);
				tx_counter <= (others => '0');
			else
				tx_counter <= tx_counter+1;
			end if;
		end if;
	
	--catch all
	when others =>
		sendMsgState <= IDLE;
	
end case;
end if;
end process;

end Behavioral;

