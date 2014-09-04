----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:44:53 08/28/2014 
-- Design Name: 
-- Module Name:    macMonitor - Behavioral 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity macMonitor is
    Port (
				clk   : in STD_LOGIC;
				HSYNC : out std_logic;
				VSYNC : out std_logic;
				VID : out std_logic;
				RX : out STD_LOGIC;
				TX : in STD_LOGIC;
				rst_n : in STD_LOGIC
	 );
end macMonitor;

architecture Behavioral of macMonitor is

component pixelClock
port
 (-- Clock in ports
  CLK_IN1           : in     std_logic;
  -- Clock out ports
  CLK_OUT1          : out    std_logic
 );
end component;

COMPONENT mem
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    clkb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
  );
END COMPONENT;

COMPONENT fifo8bit
  PORT (
    clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC
  );
END COMPONENT;

COMPONENT uart_tx
  PORT (
		clk : in  STD_LOGIC;
		tx : out STD_LOGIC;
		
		fifo_out : in std_logic_vector(7 downto 0);
		fifo_re : out std_logic;
		fifo_empty : in std_logic
	);
END COMPONENT;

COMPONENT uart_rx
  PORT (
		clk : in  STD_LOGIC;
		rx : in STD_LOGIC;

		fifo_in : out std_logic_vector(7 downto 0);
		fifo_we : out std_logic;
		fifo_full : in std_logic
	);
END COMPONENT;	

	signal pcOut : std_logic;
	signal hcount : std_logic_vector(9 downto 0);
	signal vcount : std_logic_vector(9 downto 0);

	signal cntr : std_logic_vector(29 downto 0) := (others => '0');
	signal scratch : std_logic_vector(7 downto 0);
	
	--mem
    signal wea : STD_LOGIC_VECTOR(0 DOWNTO 0);
    signal addra : STD_LOGIC_VECTOR(17 DOWNTO 0);
    signal dina : STD_LOGIC_VECTOR(0 DOWNTO 0);
    signal addrb : STD_LOGIC_VECTOR(17 DOWNTO 0);
    signal doutb : STD_LOGIC_VECTOR(0 DOWNTO 0);

--tx
signal tx_fifo_in : std_logic_vector(7 downto 0);
signal tx_fifo_out : std_logic_vector(7 downto 0);
signal tx_fifo_we : std_logic := '0';
signal tx_fifo_re : std_logic := '0';
signal tx_fifo_full : std_logic;
signal tx_fifo_empty : std_logic;
signal prevSwitch : std_logic_vector(7 downto 0) := (others => '0');

--rx
signal rx_fifo_in : std_logic_vector(7 downto 0);
signal rx_fifo_out : std_logic_vector(7 downto 0);
signal rx_fifo_we : std_logic := '0';
signal rx_fifo_re : std_logic := '0';
signal rx_fifo_full : std_logic;
signal rx_fifo_empty : std_logic;
signal light : std_logic_vector(7 downto 0) := "00000000";

type RX_DATA_STATES is (INIT,WAIT1,POST1,WAIT2,POST2,WAIT3,POST3,WAIT_PIXELS,POST_PIXELS,SET_PIXEL);
signal rxDataState : RX_DATA_STATES := INIT;
signal rxData : std_logic_vector(7 downto 0);

--setting pixel mem
signal busyshiftreg : std_logic_vector(7 downto 0);

signal negativeImage : std_logic := '0';
signal btnDownCntr : std_logic_vector(29 downto 0) := (others => '0');
signal btnUpCntr : std_logic_vector(29 downto 0) := (others => '0');
signal btnDown : std_logic := '0';

constant char0 : std_logic_vector(7 downto 0) := "00110000";
constant charA : std_logic_vector(7 downto 0) := "01000001";
constant zero : std_logic_vector(7 downto 0) := "00000000";
	
begin

fifoTx : fifo8bit PORT MAP (
    clk => pcOut,
    din => tx_fifo_in,
    wr_en => tx_fifo_we,
    rd_en => tx_fifo_re,
    dout => tx_fifo_out,
    full => tx_fifo_full,
    empty => tx_fifo_empty
  );

fifoRx : fifo8bit PORT MAP (
    clk => pcOut,
    din => rx_fifo_in,
    wr_en => rx_fifo_we,
    rd_en => rx_fifo_re,
    dout => rx_fifo_out,
    full => rx_fifo_full,
    empty => rx_fifo_empty
  );

uart_tx_comp : uart_tx PORT MAP (
    clk => pcOut,
    tx => RX,
    fifo_out => tx_fifo_out,
    fifo_re => tx_fifo_re,
    fifo_empty => tx_fifo_empty
  );

uart_rx_comp : uart_rx PORT MAP (
    clk => pcOut,
    rx => TX,
    fifo_in => rx_fifo_in,
    fifo_we => rx_fifo_we,
    fifo_full => rx_fifo_full
	);

	pc : pixelClock port map
   (-- Clock in ports
    CLK_IN1 => clk,
    -- Clock out ports
    CLK_OUT1 => pcOut);
	 
	mem1 : mem PORT MAP (
    clka => pcOut,
    wea => wea,
    addra => addra,
    dina => dina,
    clkb => pcOut,
    addrb => addrb,
    doutb => doutb
  );

--process reset btn
resetBtn: process(pcOut)
begin
if rising_edge(pcOut) then
	if (rst_n = '0') then
		btnUpCntr <= (others => '0');
		if (btnDownCntr < 1000) then
			btnDownCntr <= btnDownCntr + 1;
		end if;
	else
		btnDownCntr <= (others => '0');
		if (btnUpCntr < 1000) then
			btnUpCntr <= btnUpCntr + 1;
		end if;
	end if;
	
	if (btnDown = '0' and btnDownCntr = 1000) then
		negativeImage <= not(negativeImage);
		btnDown <= '1';
	end if;

	if (btnDown = '1' and btnUpCntr = 1000) then
		btnDown <= '0';
	end if;
	
end if;
end process;
	
--receive data for screen mem 
rxScreenData: process(pcOut)
begin
if rising_edge(pcOut) then
	case rxDataState is
	
	--check for start sequence
	when INIT =>
		addra <= (others => '1');
		wea(0) <= '0';
		rxDataState <= WAIT1;

	when WAIT1 =>
		if (rx_fifo_empty /= '1') then
			rx_fifo_re <= '1';
			rxData <= rx_fifo_out;
			rxDataState <= POST1;
		end if;
	
	when POST1 =>
		--B
		if (rxData = zero+66) then
			rxDataState <= WAIT2;
		else
			rxDataState <= WAIT1;
		end if;
		rx_fifo_re <= '0';

	when WAIT2 =>
		if (rx_fifo_empty /= '1') then
			rx_fifo_re <= '1';
			rxData <= rx_fifo_out;
			rxDataState <= POST2;
		end if;
		
	when POST2 =>
		--O
		if (rxData = zero+79) then
			rxDataState <= WAIT3;
		else
			rxDataState <= WAIT1;
		end if;
		rx_fifo_re <= '0';

	when WAIT3 =>
		if (rx_fifo_empty /= '1') then
			rx_fifo_re <= '1';
			rxData <= rx_fifo_out;
			rxDataState <= POST3;
		end if;
		
	when POST3 =>
		--B
		if (rxData = zero+66) then
			rxDataState <= WAIT_PIXELS;
		else
			rxDataState <= WAIT1;
		end if;
		rx_fifo_re <= '0';

	when WAIT_PIXELS =>
		wea(0) <= '0';
		if (rx_fifo_empty /= '1') then
			rx_fifo_re <= '1';
			rxData <= rx_fifo_out;
			--rxData <= (others => '1');
			rxDataState <= POST_PIXELS;
		end if;

	when POST_PIXELS =>
		rxDataState <= SET_PIXEL;
		rx_fifo_re <= '0';
		busyshiftreg <= (others => '1');

	when SET_PIXEL =>
		dina(0) <= rxData(7);
		if (addra = 175104) then
			rxDataState <= INIT;
		else
			if (busyshiftreg(0) = '0') then
				wea(0) <= '0';
				rxDataState <= WAIT_PIXELS;
			else
				wea(0) <= '1';
				addra <= addra + 1;
				busyshiftreg <= '0' & busyshiftreg(7 downto 1);
				rxData <= rxData(6 downto 0) & '0';
				rxDataState <= SET_PIXEL;
			end if;
		end if;

	--catch all
	when others =>
		rxDataState <= INIT;
		
	end case;	
end if;
end process;
	
--clock pixels out to CRT 
clockPixels: process(pcOut)
begin
if rising_edge(pcOut) then

	cntr <= cntr + 1;

	--update counters		
	if hcount = 704 then --total pixel clock count of line
		 hcount <= (others => '0');
		 if vcount = 370 then --total line count of frame
			vcount <= (others => '0');
			addrb <= (others => '0');
		 else
			vcount <= vcount + 1;
		 end if;
	else
		 hcount <= hcount + 1;
	end if;

	--vertical sync pulse
	if vcount >= 342 and vcount < 346 then
	  vsync <= '0';
	else
	  vsync <= '1';
	end if;	

	--horizontal sync pulse
	if (hcount >= 0 and hcount < 110) or (hcount >= 526 and hcount < 704) then
	  hsync <= '0';
	else
		hsync <= '1';
	end if;

	--visible area
	if hcount < 512 and vcount < 342 then
		--scratch <= vcount(7 downto 0) + cntr(17 downto 10);
		--VID <= scratch(4) xor hcount(4);
		addrb <= addrb + 1;
		if (negativeImage = '0') then
			VID <= doutb(0);
		else
			VID <= not(doutb(0));
		end if;
	else
		VID <= '0';
	end if;	
		
end if;
end process;

end Behavioral;

