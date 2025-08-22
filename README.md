Perfect—here’s a **brief README** that matches your Makefile and VS Code + `.fst` flow. Copy-paste it into `README.md`.

---

# Week 1 — UART-TX (VHDL-2008, macOS)

Small, native macOS project to refresh **VHDL-2008** and build a clean **UART-TX (8N1)**.
Tools: **GHDL**, **VS Code waveform extension** (reads `.fst`).

## Quick start

```bash
# compile → elaborate → run (produces waves.fst)
make
# or explicitly
make compile
make elaborate
make run
```

Open **`waves.fst` in VS Code** (your waveform extension).
(Optional) GTKWave: `make wave`

## UART-TX spec (target)

* **Generics:** `CLKS_PER_BIT`, `DATA_BITS := 8`
* **Ports:** `i_clk, i_rst_n, i_tx_start, i_tx_data(7 downto 0), o_tx_busy, o_txd (idle '1')`
* **Framing:** start `0` → `DATA_BITS` LSB→MSB → stop `1`, each **exactly** `CLKS_PER_BIT` cycles.
* **Busy policy:** document your choice (ignore / accept at stop / one-deep queue).

## Tests to implement (self-checking)

* `0x55` single byte
* Two bytes back-to-back
* `0x00` and `0xFF`
* Start while busy (per your policy)
* Different `CLKS_PER_BIT` values

Mid-bit sample `o_txd`, reconstruct the byte, and assert durations + `o_tx_busy` window.

## Layout

```
hdl/
  pkg/  # packages (types/constants)
  src/  # rtl (uart_tx.vhd)
  tb/   # testbench (uart_tx_tb.vhd)
Makefile
```

## Makefile notes

* Edit `VHDL_FILES` and `TB_ENTITY` if you rename files/entities.
* `make clean` removes `work-obj08.cf` and `waves.fst`.

