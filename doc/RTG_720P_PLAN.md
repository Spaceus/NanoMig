# RTG on a TV: 720p as the only RTG output mode, and the road to 1280x720 (PLAN, nothing built)

Status of the branch `primer25k-aga-rtg`: a fixed 640x480 8 bit picture is shown inside the
existing 720x480 HDMI frame (see `RTG_PRIMER25K.md`, hardware tested). This note describes the
next steps and what is known / unknown. Numbers are calculated, not measured.

## 1. Requirement: a TV has to accept it

A TV only reliably accepts CEA timings. PC modes such as 800x600 (and a made-up 800x600 at
~52 Hz on the existing 28.4 MHz pixel clock) are not safe on a TV. The CEA modes that matter:

| Mode | Pixel clock | TMDS clock (x5) | Notes |
|---|---|---|---|
| 720x480p 60 Hz (VIC 2/3) | 27 MHz | 135 MHz | already used by the core, works |
| 720x576p 50 Hz (VIC 17) | 27 MHz | 135 MHz | already used by the core |
| 1280x720p 60 Hz (VIC 4) | 74.25 MHz | 371.25 MHz | needs a new video clock |
| 1280x720p 50 Hz (VIC 19) | 74.25 MHz | 371.25 MHz | same clock |

## 2. Proposal: 720p is the only mode the RTG ever outputs

* While RTG is on, HDMI outputs 1280x720p60. Every RTG screen size (640x480, 800x600,
  960x540, ...) is shown **unscaled and centred** in that frame with black borders:
  `x_offset = (1280 - width) / 2`, `y_offset = (720 - height) / 2`.
* `hdmi.sv` needs one extra timing table instead of one per RTG size.
* The picture size comes from the control block in VRAM (it is already read once per
  frame): add `width`, `height`, `pitch`, `base`. No register logic.
* The TV switches mode only when RTG is turned on and off (a second or two of black).
* Amiga video keeps its current timing (28.4 MHz pixel clock). Switching between the two means
  switching the pixel/TMDS clock, see 4.

## 3. Bandwidth (8 bit, 60 Hz)

Current SDRAM controller: one access per 7.08 MHz slot (12 clocks of 85.5 MHz), burst of 4
words = 8 bytes, shared with chipset, CPU and refresh. Peak for scanout alone: ~56 MB/s.
Realistic: about half of that.

| Size | MB/s | share of the current slots |
|---|---|---|
| 640x480 | 18 | 33 % (done) |
| 800x600 | 29 | 51 % |
| 960x540 (16:9) | 31 | 55 % |
| 1024x576 (16:9) | 35 | 63 % |
| 1280x720 | 55 | ~100 %, not possible in the current controller |

So 800x600 and 960x540 fit the existing controller; 1280x720 needs section 5.
CPU writes into VRAM stay slot limited (one 16 bit word per slot, ~14 MB/s at best), no
matter how fast the CPU clock is, so big screens will redraw slowly.

## 4. 720p video path (unknown territory)

Needed:
1. A second PLL (Gowin IP generator, I could not generate it in the cloud session):
   50 MHz in, 371.25 MHz TMDS out, pixel clock = TMDS / 5 = 74.25 MHz.
2. A glitch free clock switch between the Amiga pixel clock (28.4 MHz, tied to
   `clk_28m`) and the RTG pixel clock, or a reset of the HDMI core when switching.
3. HDMI audio: the audio clock regeneration values are derived from the pixel clock
   (`PIXEL_CLOCK` in `top_020.sv`, `AUDIO_RATE` in `hdmi.sv`); they have to match 74.25 MHz.
4. 720p timing table in `hdmi.sv` (1650 x 750 total, 1280 x 720 active, positive syncs, VIC 4).

Unknown / has to be tested first:
* whether the 25K HDMI output (PMOD, `LVCMOS33D` through `ELVDS_OBUF`, 3.3 V bank) is
  good for 742 Mbit/s per channel. Check Sipeed's 720p examples for the 25K or test with a
  plain test picture before building anything else on it.
* whether the TV/monitor locks to it (monitor/TV list).

First experiment (before any RTG work): a 720p test picture (colour bars) with the new PLL,
nothing else. If it fails, 720p is out and the TV safe fallback is 720x480p / 720x576p with
RTG sizes up to 720x480.

## 5. 1280x720 8 bit: restructuring the SDRAM access

Why there is room: the SDRAM has ~171 MB/s raw bandwidth (16 bit x 85.5 MHz), but the
controller only moves data in 4 of the 12 clocks of a slot. 1280x720x8 at 60 Hz needs 55 MB/s.

Idea:
1. **Dedicated bank for VRAM.** The module has 4 banks of 8 MB (word address bits 23:22).
   Put VRAM into bank 2 or 3 (16..32 MB) so scanout can keep its row open while chipset and CPU
   use banks 0/1. (The CPU window then has to reach 16..32 MB: `p2_addr` is only 23 bits
   today, and `ramaddr` in `cpu_wrapper.v` has to be changed.)
2. **Burst of 8 words in the free clocks.** While the main port occupies the data bus for
   4 clocks (bank 0/1), scanout issues a READ to its bank so its 8 data clocks fall into the
   other 8 clocks of the slot: 16 bytes per slot, ~113 MB/s peak, so 55 MB/s is about half.
3. **Open row.** A 1280 byte line is a bit more than one SDRAM row (512 words = 1 KB); only
   row changes need ACTIVE/PRECHARGE.

Hard parts:
* One command per clock: the two accesses have to be interleaved without bus collisions and
  respect tRRD, tRAS, tRCD, tRP, CAS latency 2, and write data turnaround of the main port.
* Refresh closes all rows and interrupts scanout; it has to be scheduled so the line buffer
  never runs dry (line buffer 2 x 1280 bytes, still 2 BSRAM).
* `sdram.sv` is a fixed per slot state machine today; the chipset timing must not change.
* It runs in the 85.5 MHz domain (slack in the last build: +4.1 ns). More logic costs slack.
* Logic: the AGA build is at 100 % CLS; every added cell makes place and route slower
  (the last build took ~9 minutes).

Not worth starting before RTG works at 800x600 / 960x540 with a Picasso96 driver.

## 6. Order of work

1. Extend the control block (width, height, pitch, base) and make `rtg_scanout.v` use them
   instead of the fixed 640x480 parameters. Test with the existing test programs in
   `doc/rtg/` at 640x480, 720x480, 320x240 (pixel doubled).
2. 720p test picture + new PLL + clock switch (section 4). Decide go / no go.
3. If go: 720p RTG output with centred pictures up to 960x540 / 800x600.
4. Picasso96 `.card` driver (not investigated yet: which register set, whether an existing
   driver can be adapted). The control block layout should be chosen to suit it.
5. Optional: section 5, for 1280x720 and 16 bit modes.

## 7. Dependencies and prerequisites

* 28 MHz TG68K variant (no `CPU_SLOW14`, own build): RTG does not need it, VRAM writes are slot
  limited anyway, but the branch should be rebased onto the new `top.sv` + `config_*.vh`
  structure of `primer25k-aga-chipset-fix` before the 720p work, because `top_020.sv`
  is the old layout.
