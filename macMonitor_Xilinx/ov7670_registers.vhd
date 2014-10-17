library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ov7670_registers is
    Port (
			--	LED   : out STD_LOGIC_VECTOR(7 downto 0);
				clk      : in  STD_LOGIC;
           resend   : in  STD_LOGIC;
           advance  : in  STD_LOGIC;
           command  : out  std_logic_vector(15 downto 0);
           finished : out  STD_LOGIC
			  );
end ov7670_registers;

architecture Behavioral of ov7670_registers is

	constant config_size : integer := 157;
	type config_arr is array(0 to config_size - 1) of std_logic_vector(15 downto 0);
	constant config_mem : config_arr := (
		x"1280", --reset
		x"1280", --reset
--		x"3a04", --
		x"1713", --hstart
		x"1801", --hstop
		x"32b6", --href
		x"1902", --vstart
		x"1a7a", --vstop
		x"030a", --vref
		x"0c00", --com3
		x"3e00", --com14
		x"703a", --?
		x"7135", --?
		x"7211", --?
		x"73f0", --? goes gray
		x"a202", --?

		x"1500", --com10
		x"7a20", --gamma curve
		x"7b10", --gamma curve
		x"7c1e", --gamma curve
		x"7d35", --gamma curve
		x"7e5a", --gamma curve
		x"7f69", --gamma curve
		x"8076", --gamma curve
		x"8180", --gamma curve
		x"8288", --gamma curve
		x"838f", --gamma curve
		x"8496", --gamma curve
		x"85a3", --gamma curve
		x"86af", --gamma curve
		x"87c4", --gamma curve
		x"88d7", --gamma curve
		x"89e8", --gamma curve
		x"13e0", --com8 disable AGC AEC
		x"0000", --AGC AEC
		x"0700", --AGC AEC
		x"0d40", --AGC AEC
		x"1418", --AGC AEC
		x"a505", --AGC AEC
		x"ab07", --AGC AEC
		x"2495", --AGC AEC
		x"2533", --AGC AEC
		x"26e3", --AGC AEC
		x"9f78", --AGC AEC
		x"a068", --AGC AEC
		x"a103", --AGC AEC
		x"a6d8", --AGC AEC
		x"a7d8", --AGC AEC
		x"a8f0", --AGC AEC
		x"a990", --AGC AEC
		x"aa94", --AGC AEC
		x"13e5", --com8 enable AGC AEC
		x"0e61", --com5
		x"0f4b", --com6
		x"1602", --
		x"1e07", --mvfp
		x"2102", --
		x"2291", --
		x"2907", --
		x"330b", --
		x"350b", --
		x"371d", --
		x"3871", --
		x"392a", --
		x"3c78", --com12
		x"4d40", --
		x"4e20", --
		x"6900", --gfix
		--x"6b4a", --
		x"7410", --
		x"8d4f", --
		x"8e00", --
		x"8f00", --
		x"9000", --
		x"9100", --
		x"9600", --
		x"9a00", --
		x"b084", --
		x"b10c", --
		x"b20e", --
		x"b382", --
		x"b80a", --
		x"430a", --
		x"44f0", --
		x"4534", --
		x"4658", --
		x"4728", --
		x"483a", --
		x"5988", --
		x"5a88", --
		x"5b44", --
		x"5c67", --
		x"5d49", --
		x"5e0e", --
		x"6c0a", --
		x"6d55", --
		x"6e11", --
		x"6f9f", --
		x"6a40", --
		x"0140", --
		x"0260", --
		x"13e7", --com8 enable auto-white-balance
		x"4f80", --matrix coefficients
		x"5080", --matrix coefficients
		x"5100", --matrix coefficients
		x"5222", --matrix coefficients
		x"535e", --matrix coefficients
		x"5480", --matrix coefficients
		x"589e", --matrix coefficients
		x"4108", --
		x"3f00", --
		x"7505", --
		x"76e1", --
		x"4c00", --
		x"7701", --
		x"3dc3", --
		x"4b09", --
		x"c960", --
		x"4138", --
		x"5640", --
		x"3411", --
		x"3b12", --
		x"a488", --
		x"9600", --
		x"9730", --
		x"9820", --
		x"9930", --
		x"9a84", --
		x"9b29", --
		x"9c03", --
		x"9d4c", --
		x"9e3f", --
		x"7804", --
		x"7901", --extra-weird
		x"c8f0", --extra-weird
		x"790f", --extra-weird
		x"c800", --extra-weird
		x"7910", --extra-weird
		x"c87e", --extra-weird
		x"790a", --extra-weird
		x"c880", --extra-weird
		x"790b", --extra-weird
		x"c801", --extra-weird
		x"790c", --extra-weird
		x"c80f", --extra-weird
		x"790d", --extra-weird
		x"c820", --extra-weird
		x"7909", --extra-weird
		x"c880", --extra-weird
		x"7902", --extra-weird
		x"c8c0", --extra-weird
		x"7903", --extra-weird
		x"c840", --extra-weird
		x"7905", --extra-weird
		x"c830", --extra-weird
		x"7926", --extra-weird
		
		x"13e0", --disable AEC
		x"1080", --manually set EC
		
		x"ffff");

   signal sreg   : std_logic_vector(15 downto 0);
	
begin
   command <= sreg;
	
   with sreg select finished  <= '1' when x"FFFF", '0' when others;
   
   process(clk)
		variable address : integer := 0;
		variable tmp : std_logic_vector(7 downto 0);
   begin
      if rising_edge(clk) then

			tmp := std_logic_vector(to_unsigned(address, tmp'length));
			--LED <= tmp;      
			
			if resend = '1' then
            address := 0;
         elsif ((advance = '1') and (address /= config_size - 1)) then
            address := address + 1;
         end if;

			sreg <= config_mem(address);
      end if;
   end process;
end Behavioral;

