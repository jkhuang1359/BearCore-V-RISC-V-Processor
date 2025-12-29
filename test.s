.global _start
_start:
    # lui t0, 0x10000
    .word 0x100002b7
    
    # li t1, '!'
    .word 0x02100313
    
    # sw t1, 0(t0)
    .word 0x0062a023
    
    # 死循環
    # j .
    .word 0x0000006f
