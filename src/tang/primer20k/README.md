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
