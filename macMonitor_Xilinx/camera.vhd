library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

use WORK.settings.all;

entity camera is
	Port (
		cam_href : in std_logic;
		cam_clk : in std_logic;
		cam_vsync : in std_logic;
		cam_d : in unsigned(7 downto 0);
		
		camPosRst : out std_logic;
		camToDither_din : out unsigned(7 DOWNTO 0);
		camToDither_wr_en : out std_logic
	);
end camera;

architecture Behavioral of camera is

begin
	camProcess: process(cam_clk)

		type STATES is (WAIT_VSYNC, WAIT_VSYNC_OFF, WAIT_HREF, SKIP_PIXEL, READ_PIXEL);
		variable state : STATES := WAIT_VSYNC;

		constant testBoarder : integer := 4;
		constant testBoarderX : integer := (VGA_WIDTH-MAC_WIDTH)/2 + testBoarder;
		constant testBoarderY : integer := (VGA_HEIGHT-MAC_HEIGHT)/2 + testBoarder;
		
		variable vpos : integer := 0;
		variable hpos : integer := 0;
		variable scratch : std_logic;
		variable scratch1 : std_logic_vector(15 downto 0);
		variable scratch2 : std_logic_vector(15 downto 0);
	begin
		if rising_edge(cam_clk) then
			
			--defaults
			camToDither_wr_en <= '0';
			camPosRst <= '0';
			
			case state is
			
			when WAIT_VSYNC =>
				if (cam_vsync = '1') then
					state := WAIT_VSYNC_OFF;
				end if;

			when WAIT_VSYNC_OFF =>
				if (cam_vsync = '0') then
					state := WAIT_HREF;
					hpos := 0;
					vpos := 0;
				end if;

			when WAIT_HREF =>
				if (cam_href = '1') then
					state := READ_PIXEL;
				end if;

			when SKIP_PIXEL =>
				if (cam_href = '1') then
					state := READ_PIXEL;
				else
					hpos := 0;
					vpos := vpos + 1;
					if (vpos = VGA_HEIGHT) then
						state := WAIT_VSYNC;
						camPosRst <= '1';
					else
						state := WAIT_HREF;
					end if;
				end if;
				
			when READ_PIXEL =>
				if (cam_href = '1') then
--					scratch1 := std_logic_vector(to_unsigned(vpos, scratch1'length));
--					scratch2 := std_logic_vector(to_unsigned(hpos, scratch2'length));
--					if (vpos < 256) then
--						scratch := scratch2(6) xor scratch1(6);
--					else
--						scratch := scratch2(3) xor scratch1(3);
--					end if;

					--if (vpos > testBoarderY and vpos < VGA_HEIGHT - testBoarderY and hpos > testBoarderX and hpos < VGA_WIDTH - testBoarderX) then
						camToDither_din <= cam_d;
					--else
					--	camToDither_din <= (others => scratch);
					--end if;
					
					camToDither_wr_en <= '1';
					hpos := hpos + 1;
					state := SKIP_PIXEL;
				else
					hpos := 0;
					vpos := vpos + 1;
					if (vpos = VGA_HEIGHT) then
						state := WAIT_VSYNC;
						camPosRst <= '1';
					else
						state := WAIT_HREF;
					end if;
				end if;
				
			when others =>
				state := WAIT_VSYNC;
			
			end case;
			
		end if;
	end process;

end Behavioral;
