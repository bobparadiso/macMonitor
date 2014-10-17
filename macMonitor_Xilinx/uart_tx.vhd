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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity uart_tx is
    Port (
		clk : in  STD_LOGIC;
		tx : out STD_LOGIC;
		din : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		wr_en : IN STD_LOGIC;
		full : OUT STD_LOGIC;
		data_count : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
		);
end uart_tx;

architecture Behavioral of uart_tx is
	signal busyshiftreg : std_logic_vector(9 downto 0) := (others => '0');
	signal datashiftreg : std_logic_vector(9 downto 0);

	COMPONENT fifoPrinterTx
	  PORT (
		 clk : IN STD_LOGIC;
		 rst : IN STD_LOGIC;
		 din : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		 wr_en : IN STD_LOGIC;
		 rd_en : IN STD_LOGIC;
		 dout : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		 full : OUT STD_LOGIC;
		 empty : OUT STD_LOGIC;
		 data_count : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
	  );
	END COMPONENT;
	
	--fifoPrinterTx
	signal fifoPrinterTx_rd_en : std_logic;
	signal fifoPrinterTx_empty : std_logic;
	signal fifoPrinterTx_dout : std_logic_vector(7 downto 0);
begin

	inst_fifoPrinterTx : fifoPrinterTx
	PORT MAP (
		clk => clk,
		rst => '0',
		din => din,
		wr_en => wr_en,
		rd_en => fifoPrinterTx_rd_en,
		dout => fifoPrinterTx_dout,
		full => full,
		empty => fifoPrinterTx_empty,
		data_count => data_count
	);

	tx <= datashiftreg(0);

	--grabs from fifo and actually sends data
	sendMsg: process(clk)
		variable tx_counter : integer := 0;

		type STATES is (IDLE, SENDING);
		variable state : STATES := IDLE;
	begin
		if rising_edge(clk) then
		
			--defaults
			fifoPrinterTx_rd_en <= '0';
		
			case state is
				
				--check for data in fifo to send
				when IDLE =>
					if (fifoPrinterTx_empty /= '1') then
						fifoPrinterTx_rd_en <= '1';
						datashiftreg <= '1' & fifoPrinterTx_dout & '0';
						busyshiftreg <= (others => '1');
						tx_counter := 0;
						state := SENDING;
					end if;

				--send it
				when SENDING =>
					--finished
					if busyshiftreg(0) = '0' then
						state := IDLE;
					--processing
					else
						--16MHz / 9600bps = 1667 clocks
						--25MHz / 9600bps = 2604 clocks
						--25MHz / 19200bps = 1302 clocks
						--25MHz / 57600bps = 434 clocks
						--25MHz / 115200bps = 216 clocks
						if tx_counter = 1302 then
							datashiftreg <= '1' & datashiftreg(9 downto 1);
							busyshiftreg <= '0' & busyshiftreg(9 downto 1);
							tx_counter := 0;
						else
							tx_counter := tx_counter + 1;
						end if;
					end if;
				
				--catch all
				when others =>
					state := IDLE;
				
			end case;
		end if;
	end process;

end Behavioral;

