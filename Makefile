# VHDL source files in compilation order
VHDL_FILES = \
  hdl/pkg/uart_pkg.vhd \
  hdl/src/uart_tx.vhd  \
  hdl/src/uart_rx.vhd  \
  hdl/tb/uart_tx_tb.vhd	\
  hdl/tb/uart_rx_tb.vhd

# Name of the top-level testbench entity
# TB_ENTITY = uart_tx_tb
TB_ENTITY = uart_rx_tb


# Default target when you just type "make"
all: run

# Target to compile all VHDL files
compile:
	ghdl -a --std=08 $(VHDL_FILES)

# Target to elaborate the testbench
elaborate: compile
	ghdl -e --std=08 $(TB_ENTITY)

# Target to run the simulation and generate a waveform
run: elaborate
	ghdl -r $(TB_ENTITY) --fst=waves.fst # <--- UPDATED

# Target to open the waveform in GTKWave
wave:
	gtkwave waves.fst # <--- UPDATED

# Target to clean up all generated files
clean:
	rm -f $(TB_ENTITY) work-obj08.cf waves.fst # <--- UPDATED

.PHONY: all compile elaborate run wave clean