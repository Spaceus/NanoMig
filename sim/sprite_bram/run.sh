#!/bin/sh
# denise_sprites: sprite buffers in RAM16 vs block ram must give the same video
# 1) sprite data written by DMA, CPU/copper write POS/CTL during the line -> identical
# 2) +midline_data: CPU/copper also write DATA/DATB during the line -> counts the
#    known one-clock read-during-write difference (information, not a failure)
cd "$(dirname "$0")"; S=../../src/minimig-aga
iverilog -g2012 -DDENISE_EBR -o tb_sprite_bram tb_sprite_bram.v \
  $S/denise_sprites.v $S/denise_sprites_shifter.v $S/sprite_ram.v || exit 1
echo "== DMA data, POS/CTL during the line"
vvp -n tb_sprite_bram | grep -v "VCD info\|finish"; r=$?
echo "== also DATA/DATB during the line (information)"
vvp -n tb_sprite_bram +midline_data | grep -v "VCD info\|finish\|MISMATCH"
rm -f tb_sprite_bram

# 3) Gowin: with GOWIN defined the block ram version is one SDPB primitive
#    (sprite_ram.v). Needs the Gowin simulation library, e.g.
#    GOWIN_SIMLIB=/mnt/c/Gowin/Gowin_V1.9.11.03_Education_x64/IDE/simlib/gw5a sh run.sh
if [ -n "$GOWIN_SIMLIB" ]; then
  echo "== Gowin SDPB primitive: DMA data, POS/CTL during the line"
  iverilog -g2012 -DDENISE_EBR -DGOWIN -s tb -o tb_sprite_sdpb tb_sprite_bram.v \
    $S/denise_sprites.v $S/denise_sprites_shifter.v $S/sprite_ram.v \
    "$GOWIN_SIMLIB/prim_sim.v" || exit 1
  vvp -n tb_sprite_sdpb | grep -v "VCD info\|finish"
  echo "== Gowin SDPB primitive: also DATA/DATB during the line (information)"
  vvp -n tb_sprite_sdpb +midline_data | grep -v "VCD info\|finish\|MISMATCH"
  rm -f tb_sprite_sdpb
fi
