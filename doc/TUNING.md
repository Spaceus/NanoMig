# NanoMig 25K – tuning- og idéliste

Noter fra gennemgang af koden. Intet af det er bygget eller målt endnu
(ingen Gowin-syntese kørt) – rækkefølgen er en vurdering.

## Status
- 68020 (TG68K) er lavet.
- Primer 25K har kun SDRAM (MiSTer SDRAM-modul, 16 bit, 85 MHz). `fastram_addr[22:1]` = 8 MB i dag.
- CPU-valg er fjernet i nyt build (kun én CPU) – gav ca. 230 LUT'er.

## Tuning (rækkefølge)
1. **Fjern `CPU_SLOW14`** (`src/minimig-aga/cpu_wrapper.v` ca. linje 368).
   Holder TG68K på 14 MHz effektivt på 28 MHz clock for timing closure.
   Hvis timing lukker uden, bliver CPU'en op til dobbelt så hurtig. Tjek timingrapport.
2. **Bekræft cache er slået til**: `ENABLE_CACHE` og `CHIPRAM_CACHE`
   (er sat i `src/mistle/gw5a_25/top.sv`; ingen defines set i `src/tang/primer25k/top.sv`).
3. **SDRAM-timing**: 85 MHz og CAS-latency. Kickstart ligger i SDRAM og går via turbo-stien.
4. **Chip RAM er ofte flaskehalsen** (DMA). Hold kode/data i Fast RAM. `FASTCHIP` er forældet.

## Zorro III (næste store punkt)
- Delvist på plads i `cpu_wrapper.v`: `z3ram_base0/1`, `z3ram_ena0/1`, `sel_z3ram0/1`.
- Mangler: autoconfig og SDRAM-kortlægning til de sidste 16 MB.

## Andre idéer
- Toccata-lydkort (`ENABLE_TOCCATA` findes).
- Netværk: Roadshow / PPP-tunnel via BL616.
- RTG: frarådes på SDRAM-only (deler båndbredde med CPU/chipset, ingen hastighedsgevinst).
  `sel_rtg` er slået fra bag `MISTER_DEPRECATED`.
- IDE/HDF-forbedringer, RTC.

## Åbne spørgsmål
- Bygges der fra `src/tang/primer25k` eller `src/mistle/gw5a_25`?
- Hvilken størrelse har SDRAM-modulet (typisk 32 MB)?
