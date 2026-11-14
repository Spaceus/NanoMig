
---

# Status: step 2 is in this branch (`primer25k-aga-rtg`, UNTESTED ON HARDWARE)

Built on top of `primer25k-68020-aga`. Everything is behind ``ENABLE_RTG`` (defined in
`src/tang/primer25k/top_020.sv`), the other boards are not affected.

What is there:

| File | Change |
|---|---|
| `src/misc/sdram.sv` | new read-only burst-4 port 3 (`p3_*`), lowest slot priority after chipset and refresh but before CPU port 2. `sdram_port` is now 3 bits wide. 16 bit modules only. |
| `src/misc/rtg_scanout.v` | line fetcher, 2 line buffers, 256 x 24 bit palette, pixel pipeline. Simulated with `sim/rtg_scanout_tb.v` (iverilog), 0 errors over ~1.5 frames. |
| `src/minimig-aga/cpu_wrapper.v` | RTG window `$02000000-$023fffff` (4 MiB, byte swapped) mapped to SDRAM 12-16 MiB. `TG68K_A24` is **not** defined with RTG (needs the full 32 bit address). |
| `src/hdmi/hdmi.sv` | `cx_o`/`cy_o` outputs (RTG only) |
| `src/tang/primer25k/top_020.sv` | wiring, video mux, HDMI timing forced to 720x480 NTSC while RTG is on |
| `src/scripts/build_tp25k_020.tcl` | adds `misc/rtg_scanout.v` |

## How to use it (no registers yet)
All offsets are from `$02000000`:

* `0x000000..0x04afff`: 640x480 pixels, 1 byte per pixel, 640 bytes per line.
* `0x3ff000`: write the 16 bit word `$5254` to switch RTG on; anything else switches it off.
* `0x3ff400..0x3ff7ff`: palette, 256 longwords `$00RRGGBB`.

The control word and the palette are re-read once per frame (during vertical blanking), so
a change shows up one to two frames later. While RTG is on the picture is centred in the
720x480 HDMI frame and the Amiga video is not shown.

Minimal test (68020 code, run from Workbench/CLI as a normal executable):
fill the palette with a ramp, fill 307200 bytes of the window with `(x+y)&255`, then
`move.w #$5254,$023ff000`.

## Known risks / things to check when building
* Resource and timing report of the complete AGA build with ``ENABLE_RTG`` (it needs
  32 bit address bits in the TG68K path, the scanout and 2 BSRAM + palette).
* The 32 bit address mode of TG68K in this configuration was never used with this build.
* The SDRAM port 3 handshake (`p3_go`/`p3_taken`) only exists in the 16 bit data
  branch of `sdram.sv`.
* HDMI sinks have to accept the switch from PAL/NTSC Amiga timing to fixed 720x480.
* The fast RAM cache sees the RTG window as cacheable fast RAM; that is only correct because
  only the CPU writes VRAM (the cache is write through). CPU reads of VRAM are fine, but
  heavy RTG drawing competes with the scanout for SDRAM slots.
