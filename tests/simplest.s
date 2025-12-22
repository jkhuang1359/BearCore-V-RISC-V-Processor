.section .text.init
.global _start

_start:
    # 不使用棧，直接寫UART
    lui a5, 0x10000       # a5 = 0x10000000 (UART地址)
    
    # 寫入字符 'H' (0x48)
    addi a4, zero, 0x48   # a4 = 'H'
    sw a4, 0(a5)
    
    # 寫入字符 'i' (0x69)
    addi a4, zero, 0x69   # a4 = 'i'
    sw a4, 0(a5)
    
    # 寫入換行 (0x0a)
    addi a4, zero, 0x0a   # a4 = '\n'
    sw a4, 0(a5)
    
    # 無限循環
    j .
