library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library UNISIM;  
use UNISIM.Vcomponents.all;

use WORK.settings.all;

entity photoBooth is
   Port (
				--misc
				LED     : out STD_LOGIC_VECTOR(7 downto 0);
				clk      : in STD_LOGIC;
				cclk      : in STD_LOGIC;--from AVR, hi when ready
				rst_n		: in std_logic;

				-- AVR SPI connections
				spi_miso : out std_logic;
				spi_ss : in std_logic;
				spi_mosi : in std_logic;
				spi_sck : in std_logic;
				-- AVR ADC channel select
				spi_channel : out std_logic_vector(3 downto 0);
				-- AVR Serial connections
				avr_tx : in std_logic; -- AVR Tx => FPGA Rx
				avr_rx : out std_logic; -- AVR Rx => FPGA Tx
				avr_rx_busy : in std_logic; -- AVR Rx buffer full

				--VGA
				HSYNC : out std_logic;
				VSYNC : out std_logic;
				VID : out  std_logic;
				
				--SDRAM
			  sdram_clk : out std_logic;
			  sdram_cle : out std_logic;
			  sdram_dqm : out std_logic;
			  sdram_cs : out std_logic;
			  sdram_we : out std_logic;
			  sdram_cas : out std_logic;
			  sdram_ras : out std_logic;
			  sdram_ba : out  STD_LOGIC_VECTOR(1 downto 0);
			  sdram_a : out  STD_LOGIC_VECTOR(12 downto 0);
			  sdram_dq : inout  STD_LOGIC_VECTOR(7 downto 0);
        
				--cam
			  cam_href : in std_logic;
			  cam_vsync : in std_logic;
			  cam_xclk : out std_logic;
			  cam_pclk : in std_logic;
			  cam_d : in  unsigned(7 downto 0);
			  cam_sioc : out std_logic;
			  cam_siod : inout std_logic;
			  
			  --printer
			  printer_tx : out std_logic
		  );
end photoBooth;

architecture Behavioral of photoBooth is
	--clocks
	signal cam_clk : STD_LOGIC;
	signal display_clk : std_logic;
	signal ram_clk : STD_LOGIC;
	signal dither_clk : std_logic;
	
	signal ram_addr : unsigned(22 downto 0);
	signal ram_rw : std_logic;
	signal ram_data_in, ram_data_out : std_logic_vector(31 downto 0);
	signal ram_busy : std_logic;
	signal ram_in_valid, ram_out_valid : std_logic;
	
	signal rst : std_logic;

	--cam
   signal camToDither_rst : STD_LOGIC;
   signal camToDither_din : unsigned(7 DOWNTO 0);
   signal camToDither_wr_en : STD_LOGIC;
   signal camToDither_rd_en : STD_LOGIC;
   signal camToDither_dout : unsigned(7 DOWNTO 0);
   signal camToDither_full : STD_LOGIC;
   signal camToDither_empty : STD_LOGIC;
   signal camToDither_wr_data_count : unsigned(7 DOWNTO 0);

	--dither
   signal ditherToRam_rst : STD_LOGIC;
   signal ditherToRam_din : STD_LOGIC_VECTOR(31 DOWNTO 0);
   signal ditherToRam_wr_en : STD_LOGIC;
   signal ditherToRam_rd_en : STD_LOGIC;
   signal ditherToRam_dout : STD_LOGIC_VECTOR(31 DOWNTO 0);
   signal ditherToRam_full : STD_LOGIC;
   signal ditherToRam_empty : STD_LOGIC;
   signal ditherToRam_wr_data_count : unsigned(7 DOWNTO 0);
	
	--display
   signal ramToDisplay_rst : STD_LOGIC;
   signal ramToDisplay_din : STD_LOGIC_VECTOR(31 DOWNTO 0);
   signal ramToDisplay_wr_en : STD_LOGIC;
   signal ramToDisplay_rd_en : STD_LOGIC;
   signal ramToDisplay_dout : STD_LOGIC_VECTOR(31 DOWNTO 0);
   signal ramToDisplay_full : STD_LOGIC;
   signal ramToDisplay_empty : STD_LOGIC;
   signal ramToDisplay_wr_data_count : unsigned(7 DOWNTO 0);

	signal brightTable_addra : unsigned(7 DOWNTO 0);
	signal brightTable_douta : unsigned(7 DOWNTO 0);
	
	signal displayPosRst, camPosRst : std_logic := '0';

	signal ov7670_config_finished : std_logic;

	signal ramToPrinter_wr_en : STD_LOGIC;
	signal ramToPrinter_din : STD_LOGIC_VECTOR(7 DOWNTO 0);
	signal ramToPrinter_full : STD_LOGIC;
	signal ramToPrinter_wr_data_count : unsigned(7 DOWNTO 0);

	--reset btn
	signal btnDown : std_logic := '0';

	--ADC
   signal channel : std_logic_vector(3 downto 0);
   signal new_sample : std_logic;
   signal sample : std_logic_vector(9 downto 0);
   signal sample_channel : std_logic_vector(3 downto 0);

component printer is
	Port (
		clk : in  std_logic;
		tx : out std_logic;
		imageFifo_wr_clk : in STD_LOGIC;
		imageFifo_wr_en : in STD_LOGIC;
		imageFifo_din : in STD_LOGIC_VECTOR(7 DOWNTO 0);
		imageFifo_full : out STD_LOGIC;
		imageFifo_wr_data_count : out unsigned(7 DOWNTO 0)
	);
end component;

component ov7670_controller is
port
( 
	clk   : in    STD_LOGIC;
	resend :in    STD_LOGIC;
	config_finished : out std_logic;
	sioc  : out   STD_LOGIC;
	siod  : inout STD_LOGIC;
	led   : out std_logic_vector(7 downto 0);
	channel : out std_logic_vector(3 downto 0);
	new_sample : in std_logic;
	sample : in std_logic_vector(9 downto 0);
	sample_channel : in std_logic_vector(3 downto 0)
);
end component;
	
component clkGenerator
port
 (-- Clock in ports
  CLK_IN1           : in     std_logic;
  -- Clock out ports
  CLK_OUT1          : out    std_logic;
  CLK_OUT2          : out    std_logic;
  CLK_OUT3          : out    std_logic;
  CLK_OUT4          : out    std_logic
 );
end component;

component sdram
port (
        clk : in std_logic;
        rst : in std_logic;

        -- these signals go directly to the IO pins
		  sdram_clk : out std_logic;
		  sdram_cle : out std_logic;
		  sdram_dqm : out std_logic;
		  sdram_cs : out std_logic;
		  sdram_we : out std_logic;
		  sdram_cas : out std_logic;
		  sdram_ras : out std_logic;
		  sdram_ba : out  STD_LOGIC_VECTOR(1 downto 0);
		  sdram_a : out  STD_LOGIC_VECTOR(12 downto 0);
		  sdram_dq : inout  STD_LOGIC_VECTOR(7 downto 0);

        -- User interface
			addr : in std_logic_vector(22 downto 0);
			rw : in std_logic;
			data_in : in std_logic_vector(31 downto 0);
			data_out : out std_logic_vector(31 downto 0);
			busy : out std_logic;
			in_valid : in std_logic;
			out_valid : out std_logic
    );

end component;
	
COMPONENT fifo1
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    wr_data_count : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
END COMPONENT;

COMPONENT fifo2
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    wr_data_count : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
END COMPONENT;

--TODO: is fifo3 just a copy of fifo2...?	
COMPONENT fifo3
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    wr_data_count : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
END COMPONENT;
	
component avr_interface
	generic (
		CLK_RATE : integer := 50000000;
		SERIAL_BAUD_RATE : integer := 500000
	);
	port (
    clk : in std_logic;
    rst : in std_logic;

    -- cclk, or configuration clock is used when the FPGA is begin configured.
    -- The AVR will hold cclk high when it has finished initializing.
    -- It is important not to drive the lines connecting to the AVR
    -- until cclk is high for a short period of time to avoid contention.
    cclk : in std_logic;

    -- AVR SPI Signals
    spi_miso : out std_logic;
    spi_mosi : in std_logic;
    spi_sck : in std_logic;
    spi_ss : in std_logic;
    spi_channel : out std_logic_vector(3 downto 0);

    -- AVR Serial Signals
    tx : out std_logic;
    rx : in std_logic;

    -- ADC Interface Signals
    channel : in std_logic_vector(3 downto 0);
    new_sample : out std_logic;
    sample : out std_logic_vector(9 downto 0);
    sample_channel : out std_logic_vector(3 downto 0);

    -- Serial TX User Interface
    tx_data : in std_logic_vector(7 downto 0);
    new_tx_data : in std_logic;
    tx_busy : out std_logic;
    tx_block : in std_logic;

    -- Serial Rx User Interface
    rx_data : out std_logic_vector(7 downto 0);
    new_rx_data : out std_logic
);
end component;

component display
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
end component;

component dither
	port (
		dither_clk : IN std_logic;
		camToDither_dout : IN unsigned(7 downto 0);
		camToDither_empty : IN std_logic;
		ditherToRam_full : IN std_logic;
		ditherToRam_wr_data_count : IN unsigned(7 downto 0);
		camPosRst : IN std_logic;          
		camToDither_rst : OUT std_logic;
		camToDither_rd_en : OUT std_logic;
		ditherToRam_din : OUT std_logic_vector(31 downto 0);
		ditherToRam_wr_en : OUT std_logic
	);
end component;

component camera is
	port (
		cam_href : in std_logic;
		cam_clk : in std_logic;
		cam_vsync : in std_logic;
		cam_d : in unsigned(7 downto 0);
		
		camPosRst : out std_logic;
		camToDither_din : out unsigned(7 DOWNTO 0);
		camToDither_wr_en : out std_logic
	);
end component;
	
begin

	inst_camera: camera port map (
		cam_href => cam_href,
		cam_clk => cam_clk,
		cam_vsync => cam_vsync,
		cam_d => cam_d,
		camPosRst => camPosRst,
		camToDither_din => camToDither_din,
		camToDither_wr_en => camToDither_wr_en
	);

	inst_dither: dither port map (
		dither_clk => dither_clk,
		camToDither_rst => camToDither_rst,
		camToDither_rd_en => camToDither_rd_en,
		camToDither_dout => camToDither_dout,
		camToDither_empty => camToDither_empty,
		ditherToRam_din => ditherToRam_din,
		ditherToRam_wr_en => ditherToRam_wr_en,
		ditherToRam_full => ditherToRam_full,
		ditherToRam_wr_data_count => ditherToRam_wr_data_count,
		camPosRst => camPosRst
	);

	inst_display: display
	port map(
		 HSYNC => HSYNC,
		 VSYNC => VSYNC,
		 VID => VID,
		 ramToDisplay_rd_en => ramToDisplay_rd_en,
		 displayPosRst => displayPosRst,
		 ramToDisplay_dout => ramToDisplay_dout,
		 ramToDisplay_empty => ramToDisplay_empty,
		 display_clk => display_clk
	);

	inst_avr_interface: avr_interface
	generic map(
		clk_rate => 25000000
	)
	port map(
		 clk => cam_clk,
		 rst => rst,
		 cclk => cclk,
		 spi_miso => spi_miso,
		 spi_mosi => spi_mosi,
		 spi_sck => spi_sck,
		 spi_ss => spi_ss,
		 spi_channel => spi_channel,
		 tx => avr_rx,
		 rx => avr_tx,
		 channel => channel,
		 new_sample => new_sample,
		 sample => sample,
		 sample_channel => sample_channel,
		 tx_data => x"00",
		 new_tx_data => '0',
		 tx_block => avr_rx_busy
	);

	rst <= not rst_n;
	
	--drive cam clock
    ODDR2_inst: ODDR2
	 generic map(
        DDR_ALIGNMENT => "NONE",
        INIT => '0',
        SRTYPE => "SYNC"
    ) 
	 port map (
        Q => cam_xclk, -- 1-bit DDR output data
        C0 => cam_clk, -- 1-bit clock input
        C1 => not cam_clk, -- 1-bit clock input
        CE => '1', -- 1-bit clock enable input
        D0 => '1', -- 1-bit data input (associated with C0)
        D1 => '0', -- 1-bit data input (associated with C1)
        R => '0', -- 1-bit reset input
        S => '0' -- 1-bit set input
    );
	
	thermalPrinter : printer
	port map (
		clk => cam_clk,
		tx => printer_tx,
		imageFifo_wr_clk => ram_clk,
		imageFifo_wr_en => ramToPrinter_wr_en,
		imageFifo_din => ramToPrinter_din,
		imageFifo_full => ramToPrinter_full,
		imageFifo_wr_data_count => ramToPrinter_wr_data_count
	);
	
	ov7670 : ov7670_controller
	port map (
		clk => cam_clk,
		resend => '0',
		config_finished => ov7670_config_finished,
		sioc => cam_sioc,
		siod => cam_siod,
		led => led,
		channel => channel,
		new_sample => new_sample,
		sample => sample,
		sample_channel => sample_channel
	);	
		
	camToDitherFifo : fifo1
	PORT MAP (
		rst => camToDither_rst,
		wr_clk => cam_clk,
		rd_clk => dither_clk,
		din => std_logic_vector(camToDither_din),
		wr_en => camToDither_wr_en,
		rd_en => camToDither_rd_en,
		unsigned(dout) => camToDither_dout,
		full => camToDither_full,
		empty => camToDither_empty,
		unsigned(wr_data_count) => camToDither_wr_data_count
	);

	ditherToRamFifo : fifo2
	PORT MAP (
		rst => ditherToRam_rst,
		wr_clk => dither_clk,
		rd_clk => ram_clk,
		din => ditherToRam_din,
		wr_en => ditherToRam_wr_en,
		rd_en => ditherToRam_rd_en,
		dout => ditherToRam_dout,
		full => ditherToRam_full,
		empty => ditherToRam_empty,
		unsigned(wr_data_count) => ditherToRam_wr_data_count
	);

	ramToDisplayFifo : fifo3
	PORT MAP (
		rst => ramToDisplay_rst,
		wr_clk => ram_clk,
		rd_clk => display_clk,
		din => ramToDisplay_din,
		wr_en => ramToDisplay_wr_en,
		rd_en => ramToDisplay_rd_en,
		dout => ramToDisplay_dout,
		full => ramToDisplay_full,
		empty => ramToDisplay_empty,
		unsigned(wr_data_count) => ramToDisplay_wr_data_count
	);

	clocking : clkGenerator
	port map
   (-- Clock in ports
		CLK_IN1 => clk,
		-- Clock out ports
		CLK_OUT1 => cam_clk,
		CLK_OUT2 => dither_clk,
		CLK_OUT3 => ram_clk,
		CLK_OUT4 => display_clk
	);

	mem : sdram
	port map
	(
		clk => ram_clk,
		rst => rst,
		sdram_clk => sdram_clk,
		sdram_cle => sdram_cle,
		sdram_cs => sdram_cs,
		sdram_cas => sdram_cas,
		sdram_ras => sdram_ras,
		sdram_we => sdram_we,
		sdram_dqm => sdram_dqm,
		sdram_ba => sdram_ba,
		sdram_a => sdram_a,
		sdram_dq => sdram_dq,
		addr => std_logic_vector(ram_addr),
		rw => ram_rw,
		data_in => ram_data_in,
		data_out => ram_data_out,
		busy => ram_busy,
		in_valid => ram_in_valid,
		out_valid => ram_out_valid
    );

--=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-==-=-
--=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-==-=-

	--shuttle data in/out of SDRAM
	runRam: process(ram_clk)
		type STATES is (IDLE, WAIT_DISPLAY_READ, WAIT_PRINTER_READ1, WAIT_PRINTER_READ2, WAIT_WRITE);
		variable state : STATES := IDLE;
		
		variable write_addr : unsigned(22 downto 0) := (others => '0');

		--note we're rotating 90 degrees so screenXY is not the same as printerXY
		variable toPrinter : std_logic := '0';
		variable printerX, printerY : integer;
		variable printerBit : integer;
		variable screen2X, screen2Y : integer;--for printing
		variable screenBit : integer;

		variable tmp : std_logic_vector(31 downto 0);

		--for display
		variable screen1X : integer range 0 to MAC_WIDTH;
		variable screen1Y : integer range 0 to MAC_HEIGHT;

		variable scratch1,scratch2 : std_logic_vector(31 downto 0);
		
		constant V_OFFSET : integer := (VGA_HEIGHT-MAC_HEIGHT)/2;
		constant VGA_H_WORDS : integer := VGA_WIDTH / 32;
		constant MAC_H_WORDS : integer := MAC_WIDTH / 32;
		constant H_OFFSET : integer := (VGA_H_WORDS-MAC_H_WORDS)/2;
		
	begin
		if rising_edge(ram_clk) then

			--defaults
			ram_in_valid <= '0';
			ram_rw <= '0';
			ramToDisplay_wr_en <= '0';
			ramToDisplay_rst <= '0';
			ditherToRam_rd_en <= '0';
			ditherToRam_rst <= '0';
			ramToPrinter_wr_en <= '0';

			if (displayPosRst = '1' and toPrinter = '0') then
				screen1X := 0;
				screen1Y := 0;
				ramToDisplay_rst <= '1';
				if (btnDown = '1') then
					toPrinter := '1';
					printerX := 0;
					printerY := 0;
					screen2X := 0;
					screen2Y := 0;
					printerBit := 0;
					screenBit := 0;
				end if;
			end if;

			if (camPosRst = '1') then
				write_addr := (others => '0');
				ditherToRam_rst <= '1';
			end if;

			case state is
			
			when IDLE =>
				if (ram_busy = '0') then
					if (ditherToRam_empty = '0') then
						ram_addr <= write_addr;
						ram_rw <= '1';

						--lock image if streaming over serial
						if (toPrinter = '0') then
							ram_in_valid <= '1';
						end if;
						
						ram_data_in <= ditherToRam_dout;
						--ram_data_in <= (others => '1');

						ditherToRam_rd_en <= '1';

						write_addr := write_addr + 1;
						state := WAIT_WRITE;
					else
						if (toPrinter = '0' and ramToDisplay_wr_data_count < 100 and ramToDisplay_full = '0' and displayPosRst = '0') then
							ram_addr <= to_unsigned((screen1Y + V_OFFSET) * VGA_H_WORDS + (H_OFFSET + screen1X), ram_addr'length);
							ram_rw <= '0';
							ram_in_valid <= '1';
							state := WAIT_DISPLAY_READ;
						elsif (toPrinter = '1' and ramToPrinter_wr_data_count < 100 and ramToPrinter_full = '0') then
							ram_addr <= to_unsigned((screen2Y + V_OFFSET) * VGA_H_WORDS + (H_OFFSET + screen2X), ram_addr'length);
							ram_rw <= '0';
							ram_in_valid <= '1';
							state := WAIT_PRINTER_READ1;
						end if;

					end if;
				end if;

			when WAIT_WRITE =>
				state := IDLE;
				
			when WAIT_DISPLAY_READ =>
				if (ram_out_valid = '1') then

					scratch1 := std_logic_vector(to_unsigned(screen1X, scratch1'length));
					scratch2 := std_logic_vector(to_unsigned(screen1Y, scratch2'length));

					ramToDisplay_din <= ram_data_out;
					--ramToDisplay_din <= (others => '1');
					--ramToDisplay_din <= std_logic_vector("11110" & ram_addr & "0111");
					
--					if (scratch2(0) = '0') then
--						ramToDisplay_din <= "11110000110010100000111100110101";
--					else
--						ramToDisplay_din <= "00001111001101011111000011001010";
--					end if;

--					if (scratch2(1) = '0') then
--						ramToDisplay_din <= "11111111111111110000000000000000";
--					else
--						ramToDisplay_din <= "10101010101010101010101010101010";
--					end if;
					
					ramToDisplay_wr_en <= '1';

					screen1X := screen1X + 1;
					if (screen1X = MAC_WIDTH/32) then
						screen1X := 0;
						screen1Y := screen1Y + 1;
						if (screen1Y = MAC_HEIGHT) then
							screen1Y := 0;
						end if;
					end if;
		
					state := IDLE;
				end if;

			when WAIT_PRINTER_READ1 =>
				if (ram_out_valid = '1') then

					scratch1 := std_logic_vector(to_unsigned(screen2X, scratch1'length));
					scratch2 := std_logic_vector(to_unsigned(screen2Y, scratch2'length));
					
					if (screen2Y < MAC_HEIGHT) then
						ramToPrinter_din(7-printerBit) <= ram_data_out(31-screenBit);
					else
						ramToPrinter_din(7-printerBit) <= '1';
					end if;
					
					--ramToPrinter_din(7-printerBit) <= (scratch1(0) xor scratch2(4));
					--ramToPrinter_din(7-printerBit) <= scratch1(0);
					
					--another byte ready to send
					printerBit := printerBit + 1;
					if (printerBit = 8) then
						printerBit := 0;
						ramToPrinter_wr_en <= '1';
						printerX := printerX + 1;
						if (printerX = CHUNK_WIDTH) then
							printerX := 0;
							printerY := printerY + 1;
							if (printerY = PRINTER_HEIGHT) then
								toPrinter := '0';
							end if;
						end if;
					end if;
					
					screen2Y := screen2Y + 1;
					if (screen2Y = PRINTER_WIDTH) then
						screen2Y := 0;
						screenBit := screenBit + 1;
						if (screenBit = 32) then
							screenBit := 0;
							screen2X := screen2X + 1;
						end if;
					end if;

					state := IDLE;
				end if;
			
			when others =>
				state := IDLE;
			
			end case;
		end if;
	end process;

--=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-==-=-
--=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-==-=-

--process reset btn
resetBtn: process(cam_clk)
	variable btnDownCntr : integer := 0;
	variable btnUpCntr : integer := 0;
	constant btnStateThreshold : integer := 250000;
begin
if rising_edge(cam_clk) then
	if (rst_n = '0') then
		btnUpCntr := 0;
		if (btnDownCntr < btnStateThreshold) then
			btnDownCntr := btnDownCntr + 1;
		end if;
	else
		btnDownCntr := 0;
		if (btnUpCntr < btnStateThreshold) then
			btnUpCntr := btnUpCntr + 1;
		end if;
	end if;
	
	if (btnDown = '0' and btnDownCntr = btnStateThreshold) then
		btnDown <= '1';
	end if;

	if (btnDown = '1' and btnUpCntr = btnStateThreshold) then
		btnDown <= '0';
	end if;
	
	--LED <= (others => btnDown);
	
end if;
end process;

end Behavioral;
