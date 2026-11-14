# Tang Primer 20K Dock port (WORK IN PROGRESS, UNTESTED)

Derived from `tang/primer25k` (top.sv, MiSTer SDRAM module on the 40-pin header)
and `tang/nano20k` (GW2A rPLL clocking in `amigaclks.v`, DPB IP).

Status / TODO:
- `nanomig.cst` is only a skeleton: all pin locations must be taken from the
  Sipeed Primer 20K Dock schematic (clock is believed to be H11, 27 MHz).
- Never synthesized. IP (`gowin_dpb`) was generated for GW2AR-18 and may have to
  be regenerated for GW2A-18; `amigaclks.v` uses `DEVICE = "GW2A-18C"`.
- No BL616 on the dock: MCU/companion has to go via the `pmod_companion_*` pins.
- Memory is still the external SDRAM module; DDR3 (128 MB on the core board)
  is a later step, needed for RTG.
- Build: `gw_sh scripts/build_tp20k.tcl` from `src/`.

## DDR3 (see nanomig.cst for the pin block)

The DDR3 pins (14 address, 3 bank, 16 DQ, 2 DQS pairs, DM, CK, CKE, ODT, CS/RAS/CAS/WE,
RESET) were read from the SOM 3961 schematic and are in `nanomig.cst`; they still have to be
checked against the IP generator output. There is **no** controller in the tree yet.

### Big caveat: latency, not size
The Minimig chipset needs its chip RAM data within one 7 MHz bus slot (~140 ns).
`misc/sdram.sv` does that with a tiny 85 MHz SDRAM controller. A DDR3 controller
from the Gowin IP (400 MHz memory clock, 100 MHz user clock) typically has a read latency
of the order of 150-250 ns (not measured here), which is at or over that budget.
The 46 BSRAM blocks (~100 KB) are far too small for chip RAM.
So DDR3 can realistically only host the "slow" parts (Z3 fast RAM, RTG framebuffer), the
same split MiSTer uses (SDRAM for main RAM, DDR for RTG/fast RAM, cf. the table in
`cpu_wrapper.v`). Putting chip RAM into DDR3 would need a custom low-latency controller or
a read-ahead cache, with an uncertain outcome.
