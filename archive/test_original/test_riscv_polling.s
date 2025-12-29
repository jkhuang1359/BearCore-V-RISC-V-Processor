.section .text
.globl _start
_start:
    # UART 數據寄存器地址: 0x10000000
    # UART 狀態寄存器地址: 0x10000004 (bit 0: 1=busy, 0=idle)
    li a0, 0x10000000     # UART 數據地址
    li a1, 0x10000004     # UART 狀態地址
    
    # 發送 "R"
    li a2, 0x52           # 'R'
polling_1:
    lw a3, 0(a1)          # 讀取狀態寄存器
    andi a3, a3, 1        # 檢查 bit 0 (busy)
    bnez a3, polling_1    # 如果 busy=1，繼續等待
    sw a2, 0(a0)          # 寫入數據寄存器，觸發發送
    
    # 發送 "I"
    li a2, 0x49           # 'I'
polling_2:
    lw a3, 0(a1)
    andi a3, a3, 1
    bnez a3, polling_2
    sw a2, 0(a0)
    
    # 發送 "S"
    li a2, 0x53           # 'S'
polling_3:
    lw a3, 0(a1)
    andi a3, a3, 1
    bnez a3, polling_3
    sw a2, 0(a0)
    
    # 發送 "C"
    li a2, 0x43           # 'C'
polling_4:
    lw a3, 0(a1)
    andi a3, a3, 1
    bnez a3, polling_4
    sw a2, 0(a0)
    
    # 發送 "V"
    li a2, 0x56           # 'V'
polling_5:
    lw a3, 0(a1)
    andi a3, a3, 1
    bnez a3, polling_5
    sw a2, 0(a0)
    
    # 發送 "!"
    li a2, 0x21           # '!'
polling_6:
    lw a3, 0(a1)
    andi a3, a3, 1
    bnez a3, polling_6
    sw a2, 0(a0)
    
    # 發送換行
    li a2, 0x0A           # '\n'
polling_7:
    lw a3, 0(a1)
    andi a3, a3, 1
    bnez a3, polling_7
    sw a2, 0(a0)
    
stop:
    j stop                # 無限循環
