from pathlib import Path
from vunit import VUnit

root = Path(__file__).resolve().parents[1]
ui = VUnit.from_argv()
lib = ui.add_library("lib")

for p in (root/"hdl"/"pkg").glob("*.vhd"):
    lib.add_source_file(p)
for p in (root/"hdl"/"src").glob("*.vhd"):
    lib.add_source_file(p)
for p in (root/"hdl"/"tb").glob("*_tb.vhd"):
    lib.add_source_file(p)

ui.main()
