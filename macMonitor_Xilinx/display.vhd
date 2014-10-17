library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

use WORK.settings.all;

entity display is
	Port (
		HSYNC : out std_logic;
		VSYNC : out std_logic;
		VID : out  std_logic;

		ramToDisplay_rd_en : out std_logic;
		displayPosRst : out std_logic;
		
		ramToDisplay_dout : in STD_LOGIC_VECTOR(31 DOWNTO 0);
		ramToDisplay_empty : in std_logic;
		
		display_clk : in std_logic
		);
end display;

architecture Behavioral of display is

begin

	displayProcess: process(display_clk)
		variable hcount : integer := 0;
		variable vcount : integer := 0;
		variable scratch1 : std_logic_vector(15 downto 0);
		variable scratch2 : std_logic_vector(15 downto 0);
		variable pixelData : std_logic_vector(31 downto 0);
		variable pixelDataUsed : std_logic_vector(31 downto 0) := (others => '1');
	
		constant TOTAL_DOTS : integer := 704;
		constant H_BLANK_DOTS : integer := 192;
		constant H_SYNC_DOTS : integer := 178+110;
		constant H_FRONT_PORCH_DOTS : integer := 14;

		constant TOTAL_LINES : integer := 370;
		constant V_BACK_PORCH_LINES : integer := 24;
		constant V_SYNC_LINES : integer := 4;
		constant MID_V_BLANK : integer := 20;

	begin
	
		if rising_edge(display_clk) then

			--defaults
			ramToDisplay_rd_en <= '0';
			displayPosRst <= '0';

			if hcount = TOTAL_DOTS then
				 hcount := 0;
				 
				 if vcount = TOTAL_LINES then
					vcount := 0;
				 else
					if (vcount = MID_V_BLANK) then
						displayPosRst <= '1';
					end if;
					vcount := vcount + 1;
				 end if;
			  else
				 hcount := hcount + 1;
			end if;

			if vcount < V_SYNC_LINES then
			  vsync <= '0';
			else
			  vsync <= '1';
			end if;	

			if (hcount >= H_FRONT_PORCH_DOTS and hcount < H_FRONT_PORCH_DOTS+H_SYNC_DOTS) then
			  hsync <= '0';
			else
				hsync <= '1';
			end if;

			if (hcount >= H_BLANK_DOTS and hcount < H_BLANK_DOTS+MAC_WIDTH and
				vcount >= V_BACK_PORCH_LINES+V_SYNC_LINES and vcount < V_BACK_PORCH_LINES+V_SYNC_LINES+MAC_HEIGHT) then
				if (ramToDisplay_empty = '0') then
				
					if (pixelDataUsed(31) = '1') then
						pixelData := ramToDisplay_dout;
						pixelDataUsed := (others => '0');
						ramToDisplay_rd_en <= '1';
					end if;
					
					VID <= pixelData(31);
					
					pixelData := pixelData(30 downto 0) & '0';
					pixelDataUsed := pixelDataUsed(30 downto 0) & '1';
				
				else
					scratch1 := std_logic_vector(to_unsigned(vcount, scratch1'length));
					scratch2 := std_logic_vector(to_unsigned(hcount, scratch2'length));
					VID <= scratch1(4) xor scratch2(4);
				end if;
			else
				VID <= '0';
			end if;	
		
		end if;
	end process;

end Behavioral;

