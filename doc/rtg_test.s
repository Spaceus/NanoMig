; RTG test for the primer25k-aga-rtg branch (vasm, Motorola syntax, 68020).
; Fills the palette with a colour ramp and the frame buffer with (x*3+y) & 255,
; then switches RTG on. Run as a normal executable from CLI. To switch off again
; write a word other than $5254 to $023ff000.
;
;   vasmm68k_mot -Fhunkexe -m68020 -o rtgtest rtg_test.s
;
VRAM    equ     $02000000
CTRL    equ     VRAM+$3ff000
PAL     equ     VRAM+$3ff400

        section code,code
start:
        ; palette: 256 longwords $00RRGGBB
        lea     PAL,a0
        moveq   #0,d0
.pal:   move.l  d0,d1
        lsl.l   #8,d1              ; R = i
        move.b  d0,d2
        not.b   d2
        move.b  d2,d1
        lsl.l   #8,d1              ; G = 255-i
        move.b  d0,d2
        eor.b   #$55,d2
        move.b  d2,d1              ; B = i ^ $55
        move.l  d1,(a0)+
        addq.b  #1,d0
        bne.s   .pal

        ; frame buffer 640x480, pixel = (x*3 + y) & 255
        lea     VRAM,a0
        moveq   #0,d1              ; y
.line:  moveq   #0,d0              ; x
.px:    move.l  d0,d2
        add.l   d2,d2
        add.l   d0,d2              ; x*3
        add.l   d1,d2
        move.b  d2,(a0)+
        addq.w  #1,d0
        cmp.w   #640,d0
        bne.s   .px
        addq.w  #1,d1
        cmp.w   #480,d1
        bne.s   .line

        move.w  #$5254,CTRL        ; RTG on
        rts
