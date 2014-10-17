library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use WORK.settings.all;

entity printer is
	Port (
		clk : in  std_logic;
		tx : out std_logic;
		imageFifo_wr_clk : in STD_LOGIC;
		imageFifo_wr_en : in STD_LOGIC;
		imageFifo_din : in STD_LOGIC_VECTOR(7 DOWNTO 0);
		imageFifo_full : out STD_LOGIC;
		imageFifo_wr_data_count : out unsigned(7 DOWNTO 0)
	);
end printer;

architecture Behavioral of printer is

--uart
signal uart_tx_din : unsigned(7 DOWNTO 0);
signal uart_tx_wr_en : STD_LOGIC;
signal uart_tx_full : STD_LOGIC;
signal uart_tx_data_count : unsigned(4 DOWNTO 0);

--image data
signal imageFifo_rst : STD_LOGIC := '0';
signal imageFifo_rd_en : STD_LOGIC;
signal imageFifo_dout : STD_LOGIC_VECTOR(7 DOWNTO 0);
signal imageFifo_empty : STD_LOGIC;

component uart_tx is
    Port (
		clk : in  STD_LOGIC;
		tx : out STD_LOGIC;
		din : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		wr_en : IN STD_LOGIC;
		full : OUT STD_LOGIC;
		data_count : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
		);
end component;

--TODO: fix the duplication here, setup a project level library
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

begin
	--data <= mem(address);

inst_uart_tx : uart_tx
port map (
	clk => clk,
	tx => tx,
	din => std_logic_vector(uart_tx_din),
	wr_en => uart_tx_wr_en,
	full => uart_tx_full,
	unsigned(data_count) => uart_tx_data_count
);

imageFifo : fifo1
PORT MAP (
	rst => imageFifo_rst,
	wr_clk => imageFifo_wr_clk,
	rd_clk => clk,
	din => imageFifo_din,
	wr_en => imageFifo_wr_en,
	rd_en => imageFifo_rd_en,
	dout => imageFifo_dout,
	full => imageFifo_full,
	empty => imageFifo_empty,
	unsigned(wr_data_count) => imageFifo_wr_data_count
);

--=--=-=-=-=-=-=-=-=-=-=-=-=-=--=-=--=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=   
--384 pixel width max
--screen is 512x342, will send a row of 342 at a time, and do 2 'chunks' for the 'width'
--=--=-=-=-=-=-=-=-=-=-=-=-=-=--=-=--=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=   
mainProcess: process(clk)
	
	constant config_size : integer := 9;
	type config_arr is array(0 to config_size - 1) of integer range 0 to 255;
	constant config_mem : config_arr := (27, 55, 10, 200, 250, 18, 35, 138, 0);

	constant reset_size : integer := 2;
	type reset_arr is array(0 to reset_size - 1) of integer range 0 to 255;
	constant reset_mem : reset_arr := (27, 64);

	constant startChunk_size : integer := 4;
	type startChunk_arr is array(0 to startChunk_size - 1) of integer range 0 to 255;
	constant startChunk_mem : startChunk_arr := (18, 42, CHUNK_HEIGHT, CHUNK_WIDTH);

	constant test_size : integer := 2;
	type test_arr is array(0 to test_size - 1) of integer range 0 to 255;
	constant test_mem : test_arr := (18, 84);

	constant testx_size : integer := 7;
	type testx_arr is array(0 to testx_size - 1) of integer range 0 to 255;
	constant testx_mem : testx_arr := (10,82,69,65,68,89,10);

	constant eject_size : integer := 11;
	type eject_arr is array(0 to eject_size - 1) of integer range 0 to 255;
	constant eject_mem : eject_arr := (10,10,10,10,10,10,10,10,10,10,10);

	type STATES is (IDLE, DO_INIT, START_SEQ, SEND_SEQ,
		DELAY, WAKE1, WAKE2, START_CHUNK, CHUNK_SEND, POST_PRINT);
	variable state : STATES := DO_INIT;
	variable postDelay, postWake, postSeq : STATES;

	type SEQS is (SEQ_CONFIG, SEQ_RESET, SEQ_TEST, SEQ_TESTX, SEQ_START_CHUNK, SEQ_EJECT);
	variable seq :SEQS;

	variable delayCntr : integer := 0;

	--TODO: have these based on generics
	constant init_delay : integer := 12500000;--1/2 second
	--constant byte_delay : integer := 14322;--25000000(clk)/19200(baud)*11(bits+padding)
	constant byte_delay : integer := 50000;
	constant wake_delay : integer := 1250000;--50 ms
	constant chunk_delay : integer := 1250000;

	variable seq_idx : integer;
	variable seq_size : integer;
	
	variable wake_idx : integer;
	variable init_idx : integer := 0;
	variable chunk_idx : integer;
	
	variable bc: integer;
	
begin
	if rising_edge(clk) then

		--defaults
		uart_tx_wr_en <= '0';
		imageFifo_rd_en <= '0';

		case state is
			
			when IDLE => --check if image is queued up
				if (imageFifo_empty /= '1') then
					state := START_CHUNK;
					chunk_idx := 0;
				end if;
			
			when START_CHUNK =>
				state := START_SEQ;
				seq := SEQ_START_CHUNK;
				postSeq := CHUNK_SEND;
				bc := 0;
				
			when CHUNK_SEND =>
				if (imageFifo_empty /= '1' and uart_tx_data_count < 12) then
					imageFifo_rd_en <= '1';
					uart_tx_din <= not unsigned(imageFifo_dout);
					uart_tx_wr_en <= '1';
					bc := bc + 1;
					
					if (bc = CHUNK_HEIGHT * CHUNK_WIDTH) then
						chunk_idx := chunk_idx + 1;
						if (chunk_idx = 2) then
							postDelay := POST_PRINT;
						else
							postDelay := START_CHUNK;
						end if;
						delayCntr := chunk_delay;
					else
						postDelay := CHUNK_SEND;
						delayCntr := byte_delay;
					end if;
					state := DELAY;
				end if;

			when POST_PRINT =>
				state := START_SEQ;
				seq := SEQ_EJECT;
				postSeq := IDLE;

			when DO_INIT =>
				case init_idx is
					when 0 => --initial delay
						state := DELAY;
						delayCntr := init_delay;
						postDelay := DO_INIT;

					when 1 => --wake
						state := WAKE1;
						postWake := DO_INIT;
						
					when 2 => --reset 
						state := START_SEQ;
						seq := SEQ_RESET;
						postSeq := DO_INIT;
						
					when 3 => --config
						state := START_SEQ;
						seq := SEQ_CONFIG;
						postSeq := DO_INIT;
					
					when 4 => --test
						state := START_SEQ;
						seq := SEQ_TESTX;
						postSeq := IDLE;

					when others =>
						init_idx := -1; --will inc to 0
				end case;
				init_idx := init_idx + 1;
			
			--start of wake routine
			when WAKE1 =>
				if (uart_tx_data_count < 12) then
					state := DELAY;
					delayCntr := byte_delay;
					uart_tx_din <= to_unsigned(255, uart_tx_din'length);
					uart_tx_wr_en <= '1';
					wake_idx := 0;
					postDelay := WAKE2;
				end if;
			
			--repetitive part of wake routine
			when WAKE2 =>
				if (uart_tx_data_count < 12) then
					if (wake_idx = 10) then
						state := postWake;
					else
						state := DELAY;
						uart_tx_din <= to_unsigned(27, uart_tx_din'length);
						uart_tx_wr_en <= '1';
						delayCntr := wake_delay;
						postDelay := WAKE2;
					end if;
					wake_idx := wake_idx + 1;
				end if;
			
			when START_SEQ =>
				state := SEND_SEQ;
				seq_idx := 0;
				case seq is
					when SEQ_CONFIG => seq_size := config_size;
					when SEQ_RESET => seq_size := reset_size;
					when SEQ_START_CHUNK => seq_size := startChunk_size;
					when SEQ_TEST => seq_size := test_size;
					when SEQ_TESTX => seq_size := testx_size;
					when SEQ_EJECT => seq_size := eject_size;
					when others => seq_size := 0;
				end case;
			
			when SEND_SEQ =>
				if (uart_tx_data_count < 12) then
					case seq is
						when SEQ_CONFIG =>
							uart_tx_din <= to_unsigned(config_mem(seq_idx), uart_tx_din'length);
						when SEQ_RESET =>
							uart_tx_din <= to_unsigned(reset_mem(seq_idx), uart_tx_din'length);
						when SEQ_START_CHUNK =>
							uart_tx_din <= to_unsigned(startChunk_mem(seq_idx), uart_tx_din'length);
						when SEQ_TEST =>
							uart_tx_din <= to_unsigned(test_mem(seq_idx), uart_tx_din'length);
						when SEQ_TESTX =>
							uart_tx_din <= to_unsigned(testx_mem(seq_idx), uart_tx_din'length);
						when SEQ_EJECT =>
							uart_tx_din <= to_unsigned(eject_mem(seq_idx), uart_tx_din'length);
						when others =>
							uart_tx_din <= to_unsigned(0, uart_tx_din'length);
					end case;
					
					uart_tx_wr_en <= '1';
					seq_idx := seq_idx + 1;
					if (seq_idx = seq_size) then
						postDelay := postSeq;
					else
						postDelay := SEND_SEQ;
					end if;
					delayCntr := byte_delay;
					state := DELAY;
				end if;
				
			when DELAY =>
				delayCntr := delayCntr - 1;
				if (delayCntr = 0) then
					state := postDelay;
				end if;
			
			when others =>
				state := DO_INIT;
				
		end case;
			
	end if;
end process;
--=--=-=-=-=-=-=-=-=-=-=-=-=-=--=-=--=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=   
--=--=-=-=-=-=-=-=-=-=-=-=-=-=--=-=--=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=   

end Behavioral;

