-- VHDL-2008
library ieee;
use ieee.std_logic_1164.all;
-- Requirement: Use numeric_std for any math.
use ieee.numeric_std.all;

-- This package holds shared types and constants for the UART project.
package uart_pkg is

 -- Requirement: a byte_t subtype (std_logic_vector(7 downto 0))
    subtype byte_t is std_logic_vector(7 downto 0);
    
-- Requirement: a simple record type you’ll use in the TB
    type tb_input_t is record
        data : byte_t;
        -- You could add more fields here later, like 'is_valid'.
    end record tb_input_t;

-- A default value for the record, which is good practice.
constant  C_DEFAULT_TB_INPUT : tb_input_t := (data => (others => '0'));

-- A component to satisfy the "generate" block requirement.
component dummy_generate_example is 
    port(
        clk : in std_logic;
        i   : in std_logic_vector(7 downto 0);
        o   : in std_logic_vector(7 downto 0)
    );
    end component dummy_generate_example;

end package uart_pkg;

-- =============================================================================
-- The dummy entity is defined in the same file for convenience.
-- Its only purpose is to contain the required 'generate' block.
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity  dummy_generate_example is 
    port (
        clk : in std_logic;
        i   : in  std_logic_vector(7 downto 0);
        o   : out std_logic_vector(7 downto 0)
    );
    end entity dummy_generate_example;

architecture rtl of dummy_generate_example is
begin

-- Requirement: Add one generate block somewhere.
-- This block creates a simple 8-bit register. It generates 8
-- individual flip-flops, one for each bit of the input vector.

    g_regs : for idx in 0 to 7 generate
        process (clk) is
        begin 
            if rising_edge(clk) then
                o(idx) <= i(idx);
            end if;
        end process;
    end generate g_regs;

end architecture rtl;