# RTG sketch for the Tang Primer 25K port (DESIGN SKETCH - nothing here is built or tested)

Goal: a small Picasso96-style RTG screen (8 bit CLUT first, 16 bit later) for the
Primer 25K port (`src/tang/primer25k`, MiSTer SDRAM module, HDMI), without a second
memory and with as little logic as possible.

## 1. What is already in the tree

| Piece | Where | Relevance |
|---|---|---|
| 32 MB 16 bit SDRAM @ 85.5 MHz | `misc/sdram.sv`, `tang/primer25k/top.sv` | VRAM can live in the unused upper part of the module |
| One access per 7 MHz slot, 3 users: port 1 (chipset/CPU main RAM), port 2 (CPU fast RAM), refresh | `sdram.sv` state machine (`STATE_RAS..STATE_READ_3`, `sync_i`) | scanout needs a 4th user |
| `sel_rtg` window `$02xxxxxx` with byte swap | `minimig-aga/cpu_wrapper.v` | disabled via `ifdef MISTER_DEPRECATED`; CPU side of VRAM |
| `sel_rtg` `$B8xxxxx` | `minimig-aga/gary.v` | possible register block address (`minimig.v` leaves it open) |
| HDMI generator with fixed PAL/NTSC tables, takes 6 bit RGB | `hdmi/hdmi.sv`, `top.sv` | RTG picture must either fit its timing or the timing needs a new table |
| PLL with dynamic reconfiguration (`pll_init.v`, `mdclk`) | `tang/primer25k/gowin_pll` | possible later for non-Amiga pixel clocks (nano20k's `amigaclks.v` already has a `vidmode` port for "RTG" clocks) |

## 2. Bandwidth budget (the real constraint)

`sdram.sv` starts exactly one access per `sync` pulse (7.08 MHz, 12 SDRAM clocks);
9 of those 12 clocks are used by the state machine. One burst of 4 words
(`CHIP48_BURST`-style, 8 bytes) per slot fits, a burst of 8 does not (the read data would
end after the next slot starts). So the **best case for scanout is 8 bytes x 7.08 M = ~56 MB/s
if it owned every slot**, and it shares slots with the chipset, the CPU and refresh.

| Mode | MB/s | slots/s needed (burst 4) | share of all slots |
|---|---|---|---|
| 640x480 8 bpp 60 Hz | 18.4 | 2.3 M | 33 % |
| 800x600 8 bpp 60 Hz | 28.8 | 3.6 M | 51 % |
| 640x480 16 bpp 60 Hz | 36.9 | 4.6 M | 65 % |
| 1024x768 8 bpp 60 Hz | 47.2 | 5.9 M | 83 % |

Realistic first target: **640x480 or 800x480 at 8 bpp**, 800x600 8 bpp if the chipset is idle
(RTG screen on top, no Amiga DMA besides refresh/audio/disk). 16 bpp and 1024x768 need a
faster arrangement (see "later").

## 3. Proposed blocks

```
 CPU (TG68K, 32 bit) --$02xxxxxx--> cpu_wrapper sel_rtg --> port 2 --> SDRAM (VRAM @ 16..32 MB)
 CPU --$B8xxxxx--> rtg_regs (mode, base, pitch, palette, status/irq)
                      |
 rtg_scanout:  clk_85m: line fetcher --port 3 (burst 4)--> SDRAM
                  |  dual-clock FIFO / 2 line buffers (BRAM)
                  v  clk_pixel
               byte -> CLUT (256 x 24, 1 BRAM) -> RGB --> mux --> hdmi.sv
```

### 3.1 `rtg_regs` (new, tiny)
Registers (all 32 bit, big endian from the CPU side): `CTRL` (enable, bpp, double-scan),
`BASE` (VRAM byte address), `PITCH`, `HACTIVE/VACTIVE`, `PAL_INDEX/PAL_DATA`
(write-only 8-8-8), `STATUS` (vblank, frame counter), `IRQ_ACK`. Optional vblank interrupt
into `paula_intcontroller` (INT2/6) so the driver can wait for vblank.

### 3.2 `rtg_scanout` (new)
* Timing: simplest is to **reuse the existing HDMI timing** (720x480 / 720x576 area) and
  centre the RTG picture with borders; 640x480 8 bpp then needs no PLL change.
  Non-standard sizes (800x600) would need a new timing table in `hdmi.sv` and a 40 MHz-ish
  pixel clock via the dynamic PLL.
* Fetcher (85 MHz domain): when the line FIFO is below a watermark and a slot is granted,
  request 8 bytes at `base + y*pitch + x`; push 4 words into the FIFO.
* Two 1 KB line buffers (or one async FIFO) so a missed slot does not break the picture:
  at 640 px per 31.8 us line the fetcher needs 80 slots out of ~225 available.
* Pixel side: byte -> CLUT BRAM -> 6 bit RGB (the existing `hdmi` takes 6 bits per
  channel, 8 bit needs `{r,2'b00}` style widening already used in `top.sv`).
* Output mux: `rtg_enable ? rtg_rgb : amiga_rgb` right in front of `hdmi`. Sync/`vreset`
  must come from the RTG timing while enabled, so HDMI does not follow the Amiga display.

### 3.3 `sdram.sv` changes
* Add **port 3** (`p3_cs/p3_addr/p3_dout` + valid strobe) and make it start only when
  port 1 and refresh do not need the slot; keep chipset > refresh > scanout > port 2
  (otherwise Amiga DMA breaks). Because scanout is time critical but the FIFO gives
  slack, the CPU fast-RAM port 2 can be starved briefly; if that hurts, raise scanout
  priority only when the FIFO is below a low watermark.
* Burst length: `CHIP48_BURST` already sets burst 4 for the module; port 3 uses
  words 0..3 of that burst. Needs checking that `CHIP48_BURST=1` works with the 16 bit
  module (it is only exercised on the 32 bit TN20k RAM today).
* Extend address width: `addr`/`p2_addr` are 22/23 bit word addresses (8/16 MB). VRAM must
  go to the 16..32 MB half, so `p2_addr` and the new port need 24 bit word addresses
  (`RAS_WIDTH+CAS_WIDTH+2 = 24`, no change needed inside for the 13/9/2 module).

### 3.4 CPU side
* Enable the `sel_rtg` window outside `MISTER_DEPRECATED` and route it to port 2 at physical
  `0x1000000 + (addr & 0x7fffff)` (8 MB VRAM is plenty), keeping the existing byte swap so
  the driver can use native Amiga pixel formats later.
* TG68K must run in 32 bit address mode (the 68020 build); the 24 bit `TG68K_A24`
  build cannot reach `$02xxxxxx`.
* The fast-RAM cache (`nanomig.v`, 64 bit line fills) must not cache RTG addresses
  or it must be coherent for writes; simplest: mark `$02xxxxxx` uncached.

### 3.5 Software
A Picasso96/CGX card driver (`.card`) has to be written or ported. I have not checked which
register set the MiSTer Minimig driver expects, so step 1 is reading its sources
and deciding whether to match its registers (re-use) or define our own (see 3.1).
For first tests a small Amiga program that pokes the registers and a test pattern into
the VRAM window is enough and needs no driver.

## 4. Logic cost estimate (to be measured)
Registers + palette write path + counters: a few hundred LUT4; line FIFO + CLUT: ~3 BRAM;
`sdram.sv` port 3: ~100-200 LUT4. Given the worry that the 68020/AGA build is already close to
the 23,040 LUT4 of the GW5A-25, **measure first** (Gowin resource report of the current
`primer25k-68020-aga` build) before spending time here. If it does not fit, drop AGA
(or use fx68k) when RTG is built.

## 5. Suggested order
1. Resource report of the current build (go/no-go).
2. Free CPU window + a hardcoded 640x480 8 bpp scanout reading VRAM from SDRAM (no registers,
   fixed palette) and a CPU test that fills VRAM. Verifier: picture on HDMI.
3. Register block, palette, mode/base/pitch.
4. vblank interrupt, double buffering via `BASE`.
5. P96 driver; then 16 bpp with a second burst per slot or a faster SDRAM clock.

## 6. Later / alternatives
* **Two accesses per slot**: restructure `sdram.sv` so scanout can use the 3 idle clocks plus
  the READ states (open-row reads with auto-precharge off) - doubles the scanout bandwidth.
* A 32 bit SDRAM or a second 16 bit module would double the bandwidth; not possible on this
  board with only the 40-pin header already taken by the module.
* On boards whose hardware has DDR3 (the Tang Console/Mega boards have it on the core
  board; the current NanoMig ports do not use it), VRAM + scanout could live in DDR3 and
  leave SDRAM to the chipset (same split as MiSTer). Needs a DDR3 controller first.
