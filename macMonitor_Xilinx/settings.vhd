library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package settings is

constant VGA_WIDTH : integer := 640;
constant VGA_HEIGHT : integer := 480;
constant MAC_WIDTH : integer := 512;
constant MAC_HEIGHT : integer := 480;

constant CHUNK_HEIGHT : integer := 255;
constant CHUNK_WIDTH : integer := 43;--MAC_HEIGHT pixels + 2 unused
constant PRINTER_WIDTH : integer := CHUNK_WIDTH * 8;
constant PRINTER_HEIGHT : integer := 510;--255*2 = 2 chunks = 510 = MAC_WIDTH-2(close enough)

end package settings;
