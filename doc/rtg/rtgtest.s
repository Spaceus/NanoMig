        .text
        .globl _start
_start:
        lea     0x023ff400,%a0
        moveq   #0,%d0
1:      move.l  %d0,%d1
        lsl.l   #8,%d1
        move.b  %d0,%d2
        not.b   %d2
        move.b  %d2,%d1
        lsl.l   #8,%d1
        move.b  %d0,%d2
        eori.b  #0x55,%d2
        move.b  %d2,%d1
        move.l  %d1,(%a0)+
        addq.b  #1,%d0
        bne.s   1b

        lea     0x02000000,%a0
        moveq   #0,%d1
2:      moveq   #0,%d0
3:      move.l  %d0,%d2
        add.l   %d2,%d2
        add.l   %d0,%d2
        add.l   %d1,%d2
        move.b  %d2,(%a0)+
        addq.w  #1,%d0
        cmp.w   #640,%d0
        bne.s   3b
        addq.w  #1,%d1
        cmp.w   #480,%d1
        bne.s   2b

        move.w  #0x5254,0x023ff000
        rts
