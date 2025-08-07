# file: Makefile
.PHONY: lint test wave
lint:
\tghdl -s --std=08 $(shell find hdl -name '*.vhd')
test:
\texport VUNIT_SIMULATOR=ghdl; python3 sim/run.py -v
wave:
\tgtkwave waves.ghw
