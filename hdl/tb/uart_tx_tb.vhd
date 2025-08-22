-- VHDL-2008
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.uart_pkg.all;

entity uart_tx_tb is
end entity;

architecture tb of uart_tx_tb is
  constant CLK_PERIOD       : time    := 10 ns;
  constant CLKS_PER_BIT_VAL : natural := 8;

  component uart_tx is
    generic (
      CLKS_PER_BIT : natural;
      DATA_BITS    : natural
    );
    port (
      i_clk      : in  std_logic;
      i_rst_n    : in  std_logic;
      i_tx_start : in  std_logic;
      i_tx_data  : in  std_logic_vector(DATA_BITS - 1 downto 0);
      o_tx_busy  : out std_logic;
      o_txd      : out std_logic
    );
  end component;

  signal s_clk      : std_logic := '0';
  signal s_rst_n    : std_logic;
  signal s_tx_start : std_logic;
  signal s_tx_data  : byte_t;

  signal s_tx_busy  : std_logic;
  signal s_txd      : std_logic;
begin
  -- Clock
  s_clk <= not s_clk after CLK_PERIOD/2;

  -- DUT
  i_dut : component uart_tx
    generic map (
      CLKS_PER_BIT => CLKS_PER_BIT_VAL,
      DATA_BITS    => s_tx_data'length
    )
    port map (
      i_clk      => s_clk,
      i_rst_n    => s_rst_n,
      i_tx_start => s_tx_start,
      i_tx_data  => s_tx_data,
      o_tx_busy  => s_tx_busy,
      o_txd      => s_txd
    );

  -----------------------------------------------------------------------------
  -- Stimulus
  -----------------------------------------------------------------------------
  p_stimulus : process
    procedure send_and_check_byte (
      constant data_to_send : byte_t;
      constant message      : string) is
    begin
      report "TEST: " & message severity note;

      -- If currently busy, wait for idle on clock; if already idle, don't hang.
      while s_tx_busy = '1' loop
        wait until rising_edge(s_clk);
      end loop;

      -- Align to a clean edge before pulsing start
      wait until rising_edge(s_clk);

      -- One-cycle start pulse with data
      s_tx_data  <= data_to_send;
      s_tx_start <= '1';
      wait until rising_edge(s_clk);
      s_tx_start <= '0';

      -- Wait for the actual transaction window (busy high then low)
      wait until s_tx_busy = '1';
      wait until s_tx_busy = '0';

      -- Small gap
      wait for CLK_PERIOD * 5;
    end procedure;
  begin
    -- Reset
    s_tx_start <= '0';
    s_tx_data  <= (others => '0');
    s_rst_n    <= '0';
    wait for CLK_PERIOD * 10;
    s_rst_n    <= '1';
    wait until rising_edge(s_clk);

    -- Tests
    send_and_check_byte(x"55", "Send patterned bits 0x55");
    send_and_check_byte(x"AA", "Send back-to-back byte 1 0xAA");
    send_and_check_byte(x"55", "Send back-to-back byte 2 0x55");
    send_and_check_byte(x"00", "Send edge case 0x00");
    send_and_check_byte(x"FF", "Send edge case 0xFF");

    -- Start-while-busy should be ignored
    report "TEST: Attempt start while busy" severity note;
    s_tx_data  <= x"C0";
    s_tx_start <= '1';
    wait until rising_edge(s_clk);
    s_tx_start <= '0';

    wait until s_tx_busy = '1';
    s_tx_data  <= x"DE";
    s_tx_start <= '1';
    wait until rising_edge(s_clk);
    s_tx_start <= '0';
    wait until s_tx_busy = '0';
    report "TEST: Start-while-busy test complete." severity note;

    report "SIMULATION FINISHED SUCCESSFULLY" severity note;
    std.env.finish;
  end process;

  -----------------------------------------------------------------------------
  -- Mid-bit sampler/checker (loops for every frame)
  -----------------------------------------------------------------------------
  p_sampler : process
    variable v_received_frame : std_logic_vector(9 downto 0);
  begin
    while true loop
      -- Wait for a transmission to begin
      wait until s_tx_busy = '1';

      -- Middle of the start bit
      for i in 1 to CLKS_PER_BIT_VAL/2 loop
        wait until rising_edge(s_clk);
      end loop;

      -- Sample start + 8 data + stop (LSB first)
      for i in 0 to 9 loop
        v_received_frame(i) := s_txd;
        for j in 1 to CLKS_PER_BIT_VAL loop
          wait until rising_edge(s_clk);
        end loop;
      end loop;

      -- Checks
      assert v_received_frame(0) = '0'
        report "Check failed: Start bit was not '0'." severity error;
      assert v_received_frame(9) = '1'
        report "Check failed: Stop bit was not '1'." severity error;
      assert v_received_frame(8 downto 1) = s_tx_data
        report "Check failed: Received data does not match sent data." severity error;

      -- Wait for end before next loop
      wait until s_tx_busy = '0';
    end loop;
  end process;
end architecture;