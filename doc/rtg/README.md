# RTG test programs (untested on real hardware)

* `rtgtest` - Amiga executable (hand wrapped hunk): fills the palette with a colour ramp,
  draws the pattern (x*3+y)&255 into the 640x480 8 bit frame buffer and switches RTG on.
* `rtgoff`  - switches RTG off again (writes 0 to the control word).
* `rtgtest.s`, `rtgoff.s` are the sources in GNU as syntax, `mkhunk.py` wraps the raw code
  into an AmigaOS hunk file. Rebuild with:

      m68k-linux-gnu-as -m68020 --register-prefix-optional -o rtgtest.o rtgtest.s
      m68k-linux-gnu-objcopy -O binary -j .text rtgtest.o rtgtest.bin
      python3 mkhunk.py rtgtest.bin rtgtest

The programs write directly to $02000000 ... $023ff000 (see misc/rtg_scanout.v) and need
the 68020/AGA build with ENABLE_RTG. `doc/rtg_test.s` is the same test in vasm syntax.
