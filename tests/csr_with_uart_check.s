# tests/csr_with_uart_check.s
.section .text.init
.global _start

_start:
    # UART 地址
    li t0, 0x10000000  # 數據寄存器
    li t2, 0x10000004  # 狀態寄存器
    
    # 等待 UART 空閒並輸出 'S'
wait1:
    lw t3, 0(t2)
    andi t3, t3, 1
    bnez t3, wait1
    li t1, 'S'
    sw t1, 0(t0)
    
    # 設置堆疊
    li sp, 0x8000
    
    # 加載測試值到 a1
    li a1, 0x12345678
    
    # 執行 CSR 寫入
    csrw 0x340, a1
    
    # 等待 UART 空閒並輸出 'D'
wait2:
    lw t3, 0(t2)
    andi t3, t3, 1
    bnez t3, wait2
    li t1, 'D'
    sw t1, 0(t0)
    
    # 讀取 CSR
    csrr a2, 0x340
    
    # 比較
    beq a1, a2, pass
    
    # 失敗：輸出 'F'
wait3:
    lw t3, 0(t2)
    andi t3, t3, 1
    bnez t3, wait3
    li t1, 'F'
    sw t1, 0(t0)
    j end
    
pass:
    # 成功：輸出 'P'
wait4:
    lw t3, 0(t2)
    andi t3, t3, 1
    bnez t3, wait4
    li t1, 'P'
    sw t1, 0(t0)
    
end:
    # 輸出換行
wait5:
    lw t3, 0(t2)
    andi t3, t3, 1
    bnez t3, wait5
    li t1, '\n'
    sw t1, 0(t0)
    
    j end