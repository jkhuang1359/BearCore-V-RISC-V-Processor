.section .text
.globl _start
_start:
    # 測試1: 加載立即數到寄存器
    lui t0, 0x10000       # t0 = 0x10000000
    addi t1, zero, 0x42   # t1 = 0x42 ('B')
    
    # 測試2: 存儲到內存（UART地址）
    sw t1, 0(t0)          # 存儲到 UART
    
    # 測試3: 無窮循環（停止）
end:
    j end
