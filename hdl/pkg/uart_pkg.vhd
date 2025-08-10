-- VHDL-2008
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package uart_pkg is
  -- Simple byte subtype
  subtype byte_t is std_logic_vector(7 downto 0);

  -- TB record (extend later if needed)
  type tb_input_t is record
    data : byte_t;
  end record tb_input_t;

  constant C_DEFAULT_TB_INPUT : tb_input_t := (data => (others => '0'));

  -- Component example (for generate)
  component dummy_generate_example is
    port(
      clk : in  std_logic;
      i   : in  std_logic_vector(7 downto 0);
      o   : out std_logic_vector(7 downto 0)
    );
  end component dummy_generate_example;
end package uart_pkg;

-- Dummy entity/arch (for completeness)
library ieee;
use ieee.std_logic_1164.all;

entity dummy_generate_example is
  port(
    clk : in  std_logic;
    i   : in  std_logic_vector(7 downto 0);
    o   : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of dummy_generate_example is
begin
  g_regs : for idx in 0 to 7 generate
    process(clk)
    begin
      if rising_edge(clk) then
        o(idx) <= i(idx);
      end if;
    end process;
  end generate;
end architecture;
