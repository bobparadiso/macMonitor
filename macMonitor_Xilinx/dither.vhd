library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

use WORK.settings.all;

entity dither is
	Port (
		dither_clk : in std_logic;
		
		camToDither_rst : out STD_LOGIC;
		camToDither_rd_en : out STD_LOGIC;
		camToDither_dout : in unsigned(7 DOWNTO 0);
		camToDither_empty : in STD_LOGIC;

		ditherToRam_din : out STD_LOGIC_VECTOR(31 DOWNTO 0);
		ditherToRam_wr_en : out STD_LOGIC;
		ditherToRam_full : in STD_LOGIC;
		ditherToRam_wr_data_count : in unsigned(7 DOWNTO 0);
		
		camPosRst : in std_logic := '0'
	);
end dither;

architecture Behavioral of dither is
	--ditherBuf
	signal ditherBuf_rsta : STD_LOGIC;
	signal ditherBuf_wea : STD_LOGIC;
	signal ditherBuf_addra : STD_LOGIC_VECTOR(9 DOWNTO 0);
	signal ditherBuf_dina : signed(9 DOWNTO 0);
	signal ditherBuf_douta : signed(9 DOWNTO 0);

	signal brightTable_addra : unsigned(7 DOWNTO 0);
	signal brightTable_douta : unsigned(7 DOWNTO 0);

COMPONENT blockMem
  PORT (
    clka : IN STD_LOGIC;
    rsta : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(9 DOWNTO 0)
  );
END COMPONENT;

COMPONENT btable
  PORT (
    clka : IN STD_LOGIC;
    addra : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
END COMPONENT;

begin

	ditherBuf : blockMem
	PORT MAP (
		clka => dither_clk,
		rsta => ditherBuf_rsta,
		wea(0) => ditherBuf_wea,
		addra => ditherBuf_addra,
		dina => std_logic_vector(ditherBuf_dina),
		signed(douta) => ditherBuf_douta
	);

	brightTable : btable
	PORT MAP (
		clka => dither_clk,
		addra => std_logic_vector(brightTable_addra),
		unsigned(douta) => brightTable_douta
	);

	ditherProcess: process(dither_clk)
		variable bufPos : integer range 0 to VGA_WIDTH:= 0;
		variable bufDst : integer range 0 to VGA_WIDTH*2;
		variable pixelData : std_logic_vector(31 downto 0);
		variable pixelDataUsed : std_logic_vector(31 downto 0) := (others => '0');
		variable pixel : std_logic;
		variable error : signed(9 downto 0);
		variable comp : signed(9 downto 0);

		type STATES is (DITHER, SEND, DIFFUSE1R, DIFFUSE1W, DIFFUSE2R, DIFFUSE2W, DIFFUSE3R, DIFFUSE3W, POSTDITHER, DITHER2, DELAY);
		variable state : STATES := DITHER;
		
		variable postDelay : STATES;
		variable delayCntr : integer range 0 to 255 := 0;

	begin
		if rising_edge(dither_clk) then
			--defaults
			camToDither_rd_en <= '0';
			camToDither_rst <= '0';
			ditherToRam_wr_en <= '0';
			ditherBuf_wea <= '0';
			ditherBuf_rsta <= '0';

			if (camPosRst = '1') then
				bufPos := 0;
				camToDither_rst <= '1';
				pixelDataUsed := (others => '0');
				ditherBuf_addra <= (others => '0');
				ditherBuf_rsta <= '1';
				state := DITHER;
			end if;

			brightTable_addra <= camToDither_dout;
		
			case state is
			
			when DITHER =>
				if (camToDither_empty = '0' and camPosRst = '0') then
					--let brightTable load
					state := DITHER2;
				end if;
				
			when DITHER2 =>
--				if (camToDither_empty = '0' and camPosRst = '0') then

					--perform dither and calc error
					--comp := signed("00" & camToDither_dout);
					--comp := signed("00" & brightTable_douta);
					--comp := signed("00" & camToDither_dout) + ditherBuf_douta;
					comp := signed("00" & brightTable_douta) + ditherBuf_douta;

					if (comp < 128) then
						error := comp;
						pixel := '0';
					else
						error := comp - 255;
						pixel := '1';
					end if;
										
					--package pixel data and send when full
					pixelData := pixelData(30 downto 0) & pixel;
					pixelDataUsed := pixelDataUsed(30 downto 0) & '1';
					if (pixelDataUsed(31) = '1') then
						pixelDataUsed := (others => '0');
						state := SEND;
					else
						state := DIFFUSE1R;
					end if;
					
					camToDither_rd_en <= '1';
					bufPos := bufPos + 1;
					if (bufPos = VGA_WIDTH) then
						bufPos := 0;
					end if;
					
			when SEND =>
				if (ditherToRam_wr_data_count < 50 and ditherToRam_full = '0') then
					ditherToRam_din <= pixelData;
					ditherToRam_wr_en <= '1';
					state := DIFFUSE1R;
				end if;

			when DIFFUSE1R =>
				ditherBuf_addra <= std_logic_vector(to_unsigned(bufPos, ditherBuf_addra'length));
				state := DELAY;
				postDelay := DIFFUSE1W;
				delayCntr := 1;

			when DIFFUSE1W =>
				ditherBuf_dina <= ditherBuf_douta + (error/2);
				ditherBuf_wea <= '1';
				state := DELAY;
				postDelay := DIFFUSE2R;
				delayCntr := 1;

			when DIFFUSE2R =>
				bufDst := bufPos + (VGA_WIDTH-2);
				if (bufDst > (VGA_WIDTH-1)) then
					bufDst := bufDst - VGA_WIDTH;
				end if;
				ditherBuf_addra <= std_logic_vector(to_unsigned(bufDst, ditherBuf_addra'length));
				state := DELAY;
				postDelay := DIFFUSE2W;
				delayCntr := 1;

			when DIFFUSE2W =>
				ditherBuf_dina <= ditherBuf_douta + (error/4);
				ditherBuf_wea <= '1';
				state := DELAY;
				postDelay := DIFFUSE3R;
				delayCntr := 1;
				
			when DIFFUSE3R =>
				bufDst := bufPos + (VGA_WIDTH-1);
				if (bufDst > (VGA_WIDTH-1)) then
					bufDst := bufDst - VGA_WIDTH;
				end if;
				ditherBuf_addra <= std_logic_vector(to_unsigned(bufDst, ditherBuf_addra'length));
				state := DELAY;
				postDelay := DIFFUSE3W;
				delayCntr := 1;

			when DIFFUSE3W =>
				ditherBuf_dina <= error/4;--'new' pixel, so only error, no previous
				ditherBuf_wea <= '1';
				state := DELAY;
				postDelay := POSTDITHER;
				delayCntr := 1;

			when POSTDITHER =>
				ditherBuf_addra <= std_logic_vector(to_unsigned(bufPos, ditherBuf_addra'length));
				state := DELAY;
				postDelay := DITHER;
				delayCntr := 1;

			when DELAY =>
				delayCntr := delayCntr - 1;
				if (delayCntr = 0) then
					state := postDelay;
				end if;

			when others =>
				state := DITHER;
			
		end case;
		
		end if;
	end process;

end Behavioral;

