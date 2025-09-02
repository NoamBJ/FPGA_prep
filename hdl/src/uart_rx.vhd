-- VHDL-2008
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- use work.uart_pkg.all;  -- (not needed here; remove or keep if you later use package types)

entity uart_rx is
  generic (
    CLKS_PER_BIT : natural := 100;
    DATA_BITS    : natural := 8
  );
  port (
    i_clk      : in  std_logic;
    i_rst_n    : in  std_logic;  -- active-low reset
    i_rxd      : in  std_logic;  -- async serial in, idle = '1'
    o_rx_data  : out std_logic_vector(DATA_BITS - 1 downto 0);
    o_rx_valid : out std_logic   -- 1-cycle pulse when a byte completes
  );
end entity;

architecture rtl of uart_rx is
  type state_t is (S_IDLE, S_START, S_DATA, S_STOP);

  signal state     : state_t := S_IDLE;

  -- RX data path
  signal shift_reg : std_logic_vector(DATA_BITS-1 downto 0) := (others => '1');
  signal bit_idx   : natural range 0 to DATA_BITS := 0;

  -- Bit-time counter
  signal tick_cnt  : natural range 0 to CLKS_PER_BIT-1 := 0;
  constant HALF_BIT : natural := CLKS_PER_BIT/2;

  -- 2-FF synchronizer for i_rxd (avoids metastability)
  signal rxd_meta, rxd_sync, rxd_prev : std_logic := '1';
begin

  ---------------------------------------------------------------------------
  -- Synchronize the asynchronous RX input (edge detection uses rxd_prev→rxd_sync)
  ---------------------------------------------------------------------------
  p_sync : process(i_clk, i_rst_n)
  begin
    if i_rst_n = '0' then
      rxd_meta <= '1';
      rxd_sync <= '1';
      rxd_prev <= '1';
    elsif rising_edge(i_clk) then
      rxd_meta <= i_rxd;
      rxd_sync <= rxd_meta;
      rxd_prev <= rxd_sync;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Main FSM
  -- Notes on fixes vs. your previous attempt:
  --  * Start detection must be on a FALLING edge (idle '1' → start '0').
  --  * In S_START, sample at HALF_BIT, then reset tick_cnt when entering S_DATA.
  --  * In S_DATA, increment bit_idx ONCE per sampled bit (you had a double ++).
  --  * Pulse o_rx_valid for exactly one cycle (clear it every clock by default).
  ---------------------------------------------------------------------------
  p_rx : process(i_clk, i_rst_n)
  begin
    if i_rst_n = '0' then
      state      <= S_IDLE;
      shift_reg  <= (others => '1');
      tick_cnt   <= 0;
      bit_idx    <= 0;
      o_rx_data  <= (others => '0');
      o_rx_valid <= '0';
    elsif rising_edge(i_clk) then
      -- default: deassert valid every cycle; assert only when a byte finishes
      o_rx_valid <= '0';

      case state is
        ---------------------------------------------------------------------
        when S_IDLE =>
          tick_cnt <= 0;
          bit_idx  <= 0;

          -- Correct start condition: detect FALLING edge on the synchronized RX
          if (rxd_prev = '1') and (rxd_sync = '0') then
            state    <= S_START;
            tick_cnt <= 0;
          end if;

        ---------------------------------------------------------------------
        when S_START =>
          -- Wait to the MIDDLE of the start bit, then re-check it's still '0'
          if tick_cnt = HALF_BIT then
            if rxd_sync = '0' then
              state    <= S_DATA;
              tick_cnt <= 0;        -- important: realign for full-bit cadence
              bit_idx  <= 0;
            else
              state <= S_IDLE;      -- false start/glitch
            end if;
          else
            tick_cnt <= tick_cnt + 1;
          end if;

        ---------------------------------------------------------------------
        when S_DATA =>
          -- Sample each data bit at the end of its bit period
          if tick_cnt = CLKS_PER_BIT - 1 then
            shift_reg(bit_idx) <= rxd_sync;  -- LSB first storage
            tick_cnt           <= 0;

            if bit_idx = DATA_BITS - 1 then
              state   <= S_STOP;
            else
              bit_idx <= bit_idx + 1;        -- NOTE: increment ONCE per bit
            end if;
          else
            tick_cnt <= tick_cnt + 1;
          end if;

        ---------------------------------------------------------------------
        when S_STOP =>
          -- After one stop bit duration, you could check rxd_sync='1'.
          if tick_cnt = CLKS_PER_BIT - 1 then
            tick_cnt   <= 0;
            o_rx_data  <= shift_reg;
            o_rx_valid <= '1';                 -- one-cycle "byte ready" pulse
            state      <= S_IDLE;
          else
            tick_cnt <= tick_cnt + 1;
          end if;
      end case;
    end if;
  end process;

  ----------------------------------------------------------------------------
  -- Simple sanity checks
  ----------------------------------------------------------------------------
  assert CLKS_PER_BIT > 0
    report "uart_rx: CLKS_PER_BIT must be > 0" severity failure;

  assert DATA_BITS > 0
    report "uart_rx: DATA_BITS must be > 0" severity failure;

  -- Optional (uncomment if you require exact mid-bit sample with integer HALF_BIT)
  -- assert (CLKS_PER_BIT mod 2 = 0)
  --   report "uart_rx: CLKS_PER_BIT should be even for exact mid-bit sampling"
  --   severity warning;

end architecture;
