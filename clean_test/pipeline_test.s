.text
.globl _start
_start:
    # 简单线性程序，验证指令读取
    addi x1, x0, 1    # 0x00: 00008093
    addi x2, x0, 2    # 0x04: 00200113
    addi x3, x0, 3    # 0x08: 00300193
    addi x4, x0, 4    # 0x0c: 00400213
    addi x5, x0, 5    # 0x10: 00500293
    addi x6, x0, 6    # 0x14: 00600313
    addi x7, x0, 7    # 0x18: 00700393
    addi x8, x0, 8    # 0x1c: 00800413
    j _start          # 0x20: fe1ff06f
