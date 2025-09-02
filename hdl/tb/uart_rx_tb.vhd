-- VHDL-2008
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;                 -- for finish
use work.uart_pkg.all;           -- for byte_t

entity uart_rx_tb is
end entity;

architecture tb of uart_rx_tb is
  constant CLK_PERIOD       : time    := 10 ns;
  constant CLKS_PER_BIT_VAL : natural := 8;  -- TB-side divider (fast sim)

  signal s_clk      : std_logic := '0';
  signal s_rst_n    : std_logic := '0';
  signal s_rxd      : std_logic := '1';      -- UART line idles high
  signal s_rx_valid : std_logic := '0';
  signal s_rx_data  : byte_t;
begin
  ---------------------------------------------------------------------------
  -- Clock
  ---------------------------------------------------------------------------
  s_clk <= not s_clk after CLK_PERIOD/2;

  ---------------------------------------------------------------------------
  -- DUT (direct entity instantiation)
  ---------------------------------------------------------------------------
  i_dut : entity work.uart_rx
    generic map (
      CLKS_PER_BIT => CLKS_PER_BIT_VAL,
      DATA_BITS    => s_rx_data'length
    )
    port map (
      i_clk      => s_clk,
      i_rst_n    => s_rst_n,
      i_rxd      => s_rxd,
      o_rx_data  => s_rx_data,
      o_rx_valid => s_rx_valid
    );

  -----------------------------------------------------------------------------
  -- Stimulus
  -----------------------------------------------------------------------------
  p_stimulus : process
    -- clock-based wait (keeps TB correct if clock/divider change)
    procedure wait_cycles(n: natural) is
    begin
      for i in 1 to n loop
        wait until rising_edge(s_clk);
      end loop;
    end procedure;

    -- use TB constant for bit timing
    procedure send_bit(b: std_logic) is
    begin
      s_rxd <= b;
      wait_cycles(CLKS_PER_BIT_VAL);
    end procedure;

    -- LSB-first byte sender (note: 'label' is reserved → use 'msg')
    procedure send_byte(constant v : in byte_t; constant msg : in string) is
    begin
      report "TEST: " & msg severity note;

      wait until rising_edge(s_clk);  -- small sync; lets RX sync settle

      send_bit('0');                  -- start bit

      for i in 0 to 7 loop            -- data bits, LSB first
        send_bit(v(i));
      end loop;

      send_bit('1');                  -- stop bit
    end procedure;
  begin
    -- reset & settle
    s_rst_n <= '0';
    wait_cycles(10);
    s_rst_n <= '1';
    wait_cycles(8);  -- keep idle '1' a few clocks for RX synchronizer

    -- tests
    send_byte(x"55", "Pattern 0x55");
    send_byte(x"AA", "Back-to-back #1 (0xAA)");
    send_byte(x"55", "Back-to-back #2 (0x55)");
    send_byte(x"00", "Edge case 0x00");
    send_byte(x"FF", "Edge case 0xFF");

    report "SIMULATION FINISHED SUCCESSFULLY" severity note;
    finish;
  end process;

  -----------------------------------------------------------------------------
  -- Mid-bit sampler/checker
  -- Fixes: no extra bit wait after stop sample; robust 1-cycle valid check.
  -----------------------------------------------------------------------------
  -- Mid-bit sampler/checker (race-safe)
-- Mid-bit sampler/checker (edge-safe: sample at +CLK_PERIOD/2, not on edges)
p_sampler : process
  variable v_received_frame : std_logic_vector(9 downto 0); -- [start][8 data][stop]
  variable data_bits        : std_logic_vector(7 downto 0);
  variable cycles_high      : natural;
begin
  while true loop
    -- Wait for falling edge (start)
    wait until s_rxd'event and s_rxd = '0';

    -- Move to the middle of the start bit:
    --   1) advance CLKS_PER_BIT_VAL/2 clock edges
    --   2) nudge half a clock so we sample between edges, not on them
    for i in 1 to CLKS_PER_BIT_VAL/2 loop
      wait until rising_edge(s_clk);
    end loop;
    wait for CLK_PERIOD/2;

    -- Sample start + 8 data + stop at bit centers
    for i in 0 to 9 loop
      v_received_frame(i) := s_rxd;

      -- Between samples, advance exactly one bit period to the NEXT center:
      if i < 9 then
        for j in 1 to CLKS_PER_BIT_VAL loop
          wait until rising_edge(s_clk);
        end loop;
        wait for CLK_PERIOD/2;  -- stay at mid-bit, not on the edge
      end if;
    end loop;

    -- Framing checks
    assert v_received_frame(0) = '0'
      report "Start bit not '0' at mid-bit." severity error;
    assert v_received_frame(9) = '1'
      report "Stop bit not '1' at mid-bit." severity error;

    -- Compare sampled data to DUT output when valid pulses
    data_bits := v_received_frame(8 downto 1);
    wait until s_rx_valid = '1';
    assert s_rx_data = data_bits
      report "o_rx_data mismatch vs sampled data." severity error;

    -- Robust one-cycle valid check: count clock cycles while high
    cycles_high := 0;
    loop
      wait until rising_edge(s_clk);
      -- no need for extra delay now; we aren’t sampling the line level here
      exit when s_rx_valid = '0';
      cycles_high := cycles_high + 1;
    end loop;

    assert cycles_high = 1
      report "o_rx_valid is not a one-cycle pulse (saw "
             & integer'image(cycles_high) & " cycles high)."
      severity error;
  end loop;
end process;
end architecture;
