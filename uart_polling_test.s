.section .text
.globl _start
_start:
    # 設置 UART 地址
    li a0, 0x10000000     # UART 數據寄存器
    li a1, 0x10000004     # UART 狀態寄存器
    
    # 發送 'R' (0x52)
    li t0, 0x52
poll_1:
    lw t1, 0(a1)          # 讀取狀態寄存器
    andi t1, t1, 1        # 檢查 bit0 (busy)
    bnez t1, poll_1       # 如果 busy，繼續等待
    sw t0, 0(a0)          # 發送數據
    
    # 發送 'I' (0x49)
    li t0, 0x49
poll_2:
    lw t1, 0(a1)
    andi t1, t1, 1
    bnez t1, poll_2
    sw t0, 0(a0)
    
    # 發送 'S' (0x53)
    li t0, 0x53
poll_3:
    lw t1, 0(a1)
    andi t1, t1, 1
    bnez t1, poll_3
    sw t0, 0(a0)
    
    # 發送 'C' (0x43)
    li t0, 0x43
poll_4:
    lw t1, 0(a1)
    andi t1, t1, 1
    bnez t1, poll_4
    sw t0, 0(a0)
    
    # 發送 'V' (0x56)
    li t0, 0x56
poll_5:
    lw t1, 0(a1)
    andi t1, t1, 1
    bnez t1, poll_5
    sw t0, 0(a0)
    
    # 發送 '!' (0x21)
    li t0, 0x21
poll_6:
    lw t1, 0(a1)
    andi t1, t1, 1
    bnez t1, poll_6
    sw t0, 0(a0)
    
    # 無限循環
done:
    j done
