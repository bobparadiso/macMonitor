library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2c_sender is
    Port ( clk   : in  STD_LOGIC;    
           siod  : inout  STD_LOGIC;
           sioc  : out  STD_LOGIC;
           taken : out  STD_LOGIC;
           send  : in  STD_LOGIC;
           id    : in  STD_LOGIC_VECTOR (7 downto 0);
           reg   : in  STD_LOGIC_VECTOR (7 downto 0);
           val : in  STD_LOGIC_VECTOR (7 downto 0));
end i2c_sender;

architecture Behavioral of i2c_sender is
begin

   clk_process: process(clk)
		constant clk_divider : integer := 250;
		constant command_delay : integer := 250000;
		
		variable bitCntr : integer range 0 to 31 := 31;
		--variable delayCntr : integer range 0 to 1000 := 0;
		variable delayCntr : integer := 0;

		type STATES is (IDLE, START, SEND1, SEND2, SEND3, ACK1, ACK2, ACK3,
			STOP1, STOP2, STOP3, DELAY);
		variable state : STATES := IDLE;

		type PARTS is (P_ID, P_REG, P_VAL);
		variable part : PARTS;
		
		variable postDelay, postByte : STATES;

		variable busy_sr  : std_logic_vector(7 downto 0) := (others => '1');
		variable data_sr  : std_logic_vector(7 downto 0) := (others => '0');

   begin
      if rising_edge(clk) then

			--defaults
			taken <= '0';

			case state is
			
				when IDLE =>
					sioc <= '1';
					siod <= '1';

					--start first byte of command
					if (send = '1') then
						state := START;
						part := P_ID;
						data_sr := id;
					end if;
				
				when DELAY =>
					delayCntr := delayCntr - 1;
					if (delayCntr = 0) then
						state := postDelay;
					end if;
				
				when START =>
					siod <= '0';--pull data low first
					state := DELAY;
					delayCntr := clk_divider;
					postDelay := SEND1;
					
				when SEND1 =>
					sioc <= '0';--pull clock low
					siod <= data_sr(7);--set data
					
					state := DELAY;
					delayCntr := clk_divider / 4;
					postDelay := SEND2;
					
				when SEND2 =>
					sioc <= '1';--let clock go hi
					state := DELAY;
					delayCntr := clk_divider / 2;
					postDelay := SEND3;

				when SEND3 =>
					sioc <= '0';--pull clock low
					
					--shift next
					busy_sr := busy_sr(6 downto 0) & '0';
					data_sr := data_sr(6 downto 0) & '1';

					--next bit
					if (busy_sr(7) = '1') then
						postDelay := SEND1;
					--next part
					else
						postDelay := ACK1;
					end if;
					
					state := DELAY;
					delayCntr := clk_divider / 4;

				when ACK1 =>
					sioc <= '0';--pull clock low
					siod <= 'Z';
					
					state := DELAY;
					delayCntr := clk_divider / 4;
					postDelay := ACK2;

				when ACK2 =>
					sioc <= '1';--let clock go hi
					state := DELAY;
					delayCntr := clk_divider / 2;
					postDelay := ACK3;

				when ACK3 =>
					sioc <= '0';--pull clock low
					case part is
						when P_ID =>
							part := P_REG;
							data_sr := reg;
							postDelay := SEND1;
							
						when P_REG =>
							part := P_VAL;
							data_sr := val;
							postDelay := SEND1;
						
						when P_VAL =>
							postDelay := STOP1;
						
						when others =>
							postDelay := STOP1;
					
					end case;
					busy_sr := (others => '1');
					state := DELAY;
					delayCntr := clk_divider / 4;

				when STOP1 =>
					sioc <= '0';--clock low
					siod <= '0';--data low
					postDelay := STOP2;
					state := DELAY;
					delayCntr := clk_divider;

				when STOP2 =>
					sioc <= '1';--clock hi first
					postDelay := STOP3;
					state := DELAY;
					delayCntr := clk_divider;

				when STOP3 =>
					siod <= '1';--now data hi
					taken <= '1';
					state := DELAY;
					delayCntr := command_delay;
					postDelay := IDLE;
				
			end case;
	   
		end if;
   end process;
end Behavioral;

