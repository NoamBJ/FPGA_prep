-- VHDL-2008
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.uart_pkg.all;

entity uart_tx is 
  generic (
    CLKS_PER_BIT : natural := 100;
    DATA_BITS    : natural := 8
  );
  port (
    i_clk      : in  std_logic;
    i_rst_n    : in  std_logic;
    i_tx_start : in  std_logic;
    i_tx_data  : in  std_logic_vector(DATA_BITS-1 downto 0);
    o_tx_busy  : out std_logic;
    o_txd      : out std_logic
  );
end entity;

architecture rtl of uart_tx is
  type state_t is (S_IDLE, S_SEND);

  signal shift_reg : std_logic_vector(DATA_BITS+1 downto 0);
  signal tick_cnt  : natural range 0 to (CLKS_PER_BIT-1);
  signal bit_idx   : natural range 0 to (DATA_BITS+1);
  signal state     : state_t;

  signal txd_reg   : std_logic;
  signal busy_reg  : std_logic;
begin
  o_txd     <= txd_reg;
  o_tx_busy <= busy_reg;

  p_tx : process(i_clk, i_rst_n)
  begin
    if i_rst_n = '0' then
      state     <= S_IDLE;
      shift_reg <= (others => '1');
      tick_cnt  <= 0;
      bit_idx   <= 0;
      txd_reg   <= '1';
      busy_reg  <= '0';
    elsif rising_edge(i_clk) then
      case state is
        when S_IDLE =>
          busy_reg <= '0';
          txd_reg  <= '1';
          tick_cnt <= 0;
          bit_idx  <= 0;

          if i_tx_start = '1' then
            shift_reg <= '1' & i_tx_data & '0';
            txd_reg   <= '0';   -- start bit
            busy_reg  <= '1';
            tick_cnt  <= 0;
            bit_idx   <= 0;
            state     <= S_SEND;
          end if;

        when S_SEND =>
          busy_reg <= '1';

          if tick_cnt = CLKS_PER_BIT - 1 then
            tick_cnt <= 0;

            txd_reg   <= shift_reg(1);                            -- next bit
            shift_reg <= '1' & shift_reg(shift_reg'high downto 1); -- shift right, fill with '1'

            if bit_idx = DATA_BITS + 1 then
              state    <= S_IDLE;   -- done (stop bit just completed)
              busy_reg <= '0';
              txd_reg  <= '1';
              bit_idx  <= 0;
            else
              bit_idx <= bit_idx + 1;
            end if;
          else
            tick_cnt <= tick_cnt + 1;
          end if;
      end case;
    end if;
  end process;

  assert CLKS_PER_BIT > 0
    report "uart_tx: CLKS_PER_BIT must be > 0" severity failure;
  assert DATA_BITS > 0
    report "uart_tx: DATA_BITS must be > 0" severity failure;
end architecture;