-- VHDL-2008
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- use work.uart_pkg.all;  -- (not needed here; remove or keep if you later use package types)

entity byte_fifo is
  generic (
    WIDTH : natural := 8;
    DEPTH    : natural := 16
  );
  port (
    i_clk      : in  std_logic;
    i_rst_n    : in  std_logic;  -- active-low reset
    i_wr_en   : in  std_logic;
    i_wr_data  : in  std_logic_vector(WIDTH-1 downto 0);
    i_rd_en    : in std_logic;
    o_rd_data  : out std_logic_vector(WIDTH-1 downto 0);
    o_empty    : out std_logic;
    o_full     : out std_logic
  );
end entity;

architecture rtl of byte_fifo is
 
  type FIFO_DATA is array (0 to DEPTH-1) of std_logic_vector(WIDTH-1 downto 0);
  signal r_FIFO_DATA : FIFO_DATA := (others => (others => '0'));
 
  signal r_WR_INDEX   : integer range 0 to DEPTH-1 := 0;
  signal r_RD_INDEX   : integer range 0 to DEPTH-1 := 0;
 
  signal r_FIFO_COUNT : natural range 0 to DEPTH-1 := 0;
 
  signal w_FULL  : std_logic;
  signal w_EMPTY : std_logic;
   
begin
 
  p_CONTROL : process (i_clk) is
  begin
    if rising_edge(i_clk) then