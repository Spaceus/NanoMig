#!/bin/sh
# Compare DENISE_SCROLL_BRAM (scroll history in block ram) with the
# distributed ram version. Needs iverilog.
S=../../src/minimig-aga

iverilog -g2012 -DDENISE_EBR -s tb -o tb_scroll tb_scroll_bram.v \
  $S/denise_bitplanes.v $S/denise_bitplane_shifter.v $S/bitplane_ram.v || exit 1

echo "== mode changes on a fixed grid"
vvp -n tb_scroll | grep -v "finish"
echo "== mode changes at random clocks"
vvp -n tb_scroll +midline_mode | grep -v "finish"
rm -f tb_scroll

# With GOWIN defined the block ram version is two SDPB primitives. Needs the
# Gowin simulation library, e.g.
# GOWIN_SIMLIB=/mnt/c/Gowin/Gowin_V1.9.11.03_Education_x64/IDE/simlib/gw5a sh run.sh
if [ -n "$GOWIN_SIMLIB" ]; then
  iverilog -g2012 -DDENISE_EBR -DGOWIN -s tb -o tb_scroll_sdpb tb_scroll_bram.v     $S/denise_bitplanes.v $S/denise_bitplane_shifter.v $S/bitplane_ram.v     "$GOWIN_SIMLIB/prim_sim.v" 2>&1 | grep -v "no sensitivities"
  [ -f tb_scroll_sdpb ] || exit 1
  echo "== Gowin SDPB primitive: mode changes on a fixed grid"
  vvp -n tb_scroll_sdpb | grep -v "finish"
  echo "== Gowin SDPB primitive: mode changes at random clocks"
  vvp -n tb_scroll_sdpb +midline_mode | grep -v "finish"
  rm -f tb_scroll_sdpb
fi
