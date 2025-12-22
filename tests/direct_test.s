.section .text.init
.global _start

_start:
    # 不使用任何函數調用，直接寫UART
    lui a5, 0x10000       # 加載UART地址
    
    # 寫 'D'
    li a4, 0x44
    sw a4, 0(a5)
    
    # 寫 'i'
    li a4, 0x69
    sw a4, 0(a5)
    
    # 寫 'r'
    li a4, 0x72
    sw a4, 0(a5)
    
    # 寫 'e'
    li a4, 0x65
    sw a4, 0(a5)
    
    # 寫 'c'
    li a4, 0x63
    sw a4, 0(a5)
    
    # 寫 't'
    li a4, 0x74
    sw a4, 0(a5)
    
    # 寫 '\n'
    li a4, 0x0a
    sw a4, 0(a5)
    
    # 無限循環
    j .
