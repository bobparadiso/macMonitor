library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ov7670_controller is
    Port (
		clk   : in    STD_LOGIC;
		resend :in    STD_LOGIC;
		config_finished : out std_logic;
		sioc  : out   STD_LOGIC;
		siod  : inout STD_LOGIC;
		
		--display
		LED   : out STD_LOGIC_VECTOR(7 downto 0);

		--ADC control
		channel : out std_logic_vector(3 downto 0);
		new_sample : in std_logic;
		sample : in std_logic_vector(9 downto 0);
		sample_channel : in std_logic_vector(3 downto 0)
	);
end ov7670_controller;

architecture Behavioral of ov7670_controller is
   COMPONENT ov7670_registers
   PORT(
      clk      : IN std_logic;
      advance  : IN std_logic;          
      resend   : in STD_LOGIC;
      command  : OUT std_logic_vector(15 downto 0);
      finished : OUT std_logic
      );
   END COMPONENT;

   COMPONENT i2c_sender
   PORT(
      clk   : IN std_logic;
      send  : IN std_logic;
      taken : out std_logic;
      id    : IN std_logic_vector(7 downto 0);
      reg   : IN std_logic_vector(7 downto 0);
      val : IN std_logic_vector(7 downto 0);    
      siod  : INOUT std_logic;
      sioc  : OUT std_logic
      );
   END COMPONENT;

   signal reg : std_logic_vector(7 downto 0);
   signal val : std_logic_vector(7 downto 0);    

   signal command  : std_logic_vector(15 downto 0);
   signal finished : std_logic := '0';
   signal taken    : std_logic := '0';
   signal send     : std_logic;

	signal exposure : unsigned(7 downto 0) := x"80";

   constant camera_address : std_logic_vector(7 downto 0) := x"42"; -- 42"; -- Device write ID - see top of page 11 of data sheet
begin
   config_finished <= finished;
	
	process(clk)
		type STATES is (IDLE, TAKE_SAMPLE);
		variable state : STATES := TAKE_SAMPLE;

		variable target_channel : std_logic_vector(3 downto 0) := x"5";
		variable sampleCount : integer := 0;

		constant NUM_SAMPLES : integer := 3;--we get 'noise' if we use first sample

	begin

		if rising_edge(clk) then
			
			--defaults
			channel <= target_channel;
			
			LED(3 downto 0) <= target_channel;      
			
			if (finished /= '1') then
				reg <= command(15 downto 8);
				val <= command(7 downto 0);
				send <= '1';
			else
				case state is
					--wait for last command to have been sent
					when IDLE =>
						if (taken = '1') then
							state := TAKE_SAMPLE;
							sampleCount := 0;
							send <= '0';
						end if;
					
					--wait for sample, then send
					when TAKE_SAMPLE =>
						if (new_sample = '1') then
							
							if (sample_channel = target_channel) then
								sampleCount := sampleCount + 1;
							else
								sampleCount := 0;
							end if;
							
							if (sampleCount = NUM_SAMPLES) then
								case sample_channel is
								
									when x"5" =>
										reg <= x"10";
										target_channel := x"4";
								
									when x"4" =>
										reg <= x"6a";
										target_channel := x"1";
								
									when x"1" =>
										reg <= x"01";
										target_channel := x"0";
								
									when x"0" =>
										reg <= x"02";
										target_channel := x"5";
								
									when others =>
										null;
								
								end case;
								
								LED(7 downto 4) <= (others => '1');
								val <= sample(9 downto 2);
								send <= '1';
								state := IDLE;
							
							end if;
						end if;
					
					when others =>
						state := TAKE_SAMPLE;
					
				end case;
			end if;
		end if;
	end process;
	
   Inst_i2c_sender: i2c_sender PORT MAP(
      clk   => clk,
      taken => taken,
      siod  => siod,
      sioc  => sioc,
      send  => send,
      id    => camera_address,
      reg   => reg,
      val => val
   );

   Inst_ov7670_registers: ov7670_registers PORT MAP(
      clk      => clk,
      advance  => taken,
      command  => command,
      finished => finished,
      resend   => resend
   );

end Behavioral;

