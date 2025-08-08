-- VHDL-2008
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Use the package we created earlier for any shared types if needed.
use work.uart_pkg.all;

entity uart_tx is 
    generic (
        -- How many clock cycles to hold each bit for.
        -- (System Clock Frequency / Baud Rate)

        CLKS_PER_BIT : natural := 100;

        -- How many data bits to send.
        DATA_BITS : natural := 8
    );
    port (
        -- System Clock
        i_clk   : in std_logic;
        -- Active-Low Asynchronous Reset
        i_rst_n : in std_logic;

        -- A 1-cycle pulse to begin transmission
        i_tx_start  : in std_logic;
        -- The parallel data to be transmitted
        i_tx_data   : in std_logic_vector(DATA_BITS - 1 downto 0);

        -- '1' when a transmission is in progress, '0' otherwise
        o_tx_busy   : out std_logic;
        -- The serial output line (idles high)
        o_txd   : out std_logic
    );
end entity uart_tx;

architecture rtl of uart_tx is
  -- Design Decision: If i_tx_start is pulsed while the module is
  -- busy, the new request is ignored. The user must wait for
  -- o_tx_busy to go low before starting a new transmission.

  -----------------------------------------------------------------------------
  -- Type and Signal Declarations
  -----------------------------------------------------------------------------
  -- FSM states
  type state_t is (S_IDLE, S_START_BIT, S_DATA_BITS, S_STOP_BIT);

  -- Internal registers for the FSM and counters
  signal state_reg       , state_next        : state_t;
  signal clk_count_reg   , clk_count_next    : natural range 0 to CLKS_PER_BIT - 1;
  signal bit_count_reg   , bit_count_next    : natural range 0 to DATA_BITS - 1;
  signal tx_shift_reg    , tx_shift_next     : std_logic_vector(DATA_BITS + 1 downto 0);


begin
  -----------------------------------------------------------------------------
  -- Process 1: Synchronous Logic (Registers)
  -- This process handles the reset and updates all registers on the clock edge.
  -----------------------------------------------------------------------------
  p_sync : process (i_clk, i_rst_n) is
  begin
    if i_rst_n = '0' then
      state_reg      <= S_IDLE;
      clk_count_reg  <= 0;
      bit_count_reg  <= 0;
      tx_shift_reg   <= (others => '1'); -- Idle high
    elsif rising_edge(i_clk) then
      state_reg      <= state_next;
      clk_count_reg  <= clk_count_next;
      bit_count_reg  <= bit_count_next;
      tx_shift_reg   <= tx_shift_next;
    end if;
  end process p_sync;


  -----------------------------------------------------------------------------
  -- Process 2: Combinatorial Logic (FSM & Next-State Logic)
  -- This process calculates the next state and all outputs based on the
  -- current state and inputs.
  -----------------------------------------------------------------------------
  p_comb : process (all) is
  begin
    -- Default assignments to avoid inferring latches
    state_next     <= state_reg;
    clk_count_next <= clk_count_reg;
    bit_count_next <= bit_count_reg;
    tx_shift_next  <= tx_shift_reg;
    o_txd          <= tx_shift_reg(0); -- Always output the LSB
    o_tx_busy      <= '1'; -- Default to busy, override in IDLE

    case state_reg is

      when S_IDLE =>
        o_tx_busy <= '0';
        o_txd     <= '1'; -- Idle line is high

        if i_tx_start = '1' then
          -- Latch the data and load the shift register with start/stop bits
          tx_shift_next  <= '1' & i_tx_data & '0'; -- [Stop Bit | Data | Start Bit]
          clk_count_next <= 0;
          bit_count_next <= 0;
          state_next     <= S_START_BIT;
        end if;

      when S_START_BIT =>
        if clk_count_reg = CLKS_PER_BIT - 1 then
          clk_count_next <= 0;
          tx_shift_next  <= '1' & tx_shift_reg(DATA_BITS + 1 downto 1); -- Shift right
          state_next     <= S_DATA_BITS;
        else
          clk_count_next <= clk_count_reg + 1;
        end if;

      when S_DATA_BITS =>
        if clk_count_reg = CLKS_PER_BIT - 1 then
          clk_count_next <= 0;
          tx_shift_next  <= '1' & tx_shift_reg(DATA_BITS + 1 downto 1); -- Shift right

          if bit_count_reg < DATA_BITS - 1 then
            bit_count_next <= bit_count_reg + 1;
            state_next     <= S_DATA_BITS; -- Stay in this state
          else
            state_next <= S_STOP_BIT; -- Last data bit sent
          end if;
        else
          clk_count_next <= clk_count_reg + 1;
        end if;

      when S_STOP_BIT =>
        if clk_count_reg = CLKS_PER_BIT - 1 then
          clk_count_next <= 0;
          tx_shift_next  <= (others => '1'); -- Shift right, not strictly needed but good practice
          state_next     <= S_IDLE;
        else
          clk_count_next <= clk_count_reg + 1;
        end if;

    end case;
  end process p_comb;

end architecture rtl;