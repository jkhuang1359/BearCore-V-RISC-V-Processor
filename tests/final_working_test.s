.section .text.init
.global _start

_start:
    # 設置UART地址
    li t0, 0x10000000  # UART數據寄存器
    li t5, 0x10000004  # UART狀態寄存器（bit 0 = busy）
    
    # ========== 測試1: UART基本功能 ==========
    # 等待UART空閒，然後發送'S'
uart_wait1:
    lw t1, 0(t5)        # 讀取狀態寄存器
    andi t1, t1, 1      # 檢查busy位
    bnez t1, uart_wait1 # 如果busy=1，繼續等待
    li t2, 'S'
    sw t2, 0(t0)        # 發送字符
    
    # ========== 測試2: 寄存器比較測試 ==========
    li a1, 0x12345678
    li a2, 0x12345678
    
    # 插入nop確保數據可用
    nop
    nop
    nop
    
    # 比較
    beq a1, a2, test_reg_pass
    
test_reg_fail:
    # 等待UART空閒，發送'F'
uart_wait2:
    lw t1, 0(t5)
    andi t1, t1, 1
    bnez t1, uart_wait2
    li t2, 'F'
    sw t2, 0(t0)
    j end_test
    
test_reg_pass:
    # 等待UART空閒，發送'P'
uart_wait3:
    lw t1, 0(t5)
    andi t1, t1, 1
    bnez t1, uart_wait3
    li t2, 'P'
    sw t2, 0(t0)
    
    # ========== 測試3: CSR功能測試 ==========
    li a1, 0x12345678
    
    # 寫入CSR
    csrw mscratch, a1
    
    # 等待幾個周期讓CSR寫入完成
    nop
    nop
    nop
    
    # 讀取CSR
    csrr a2, mscratch
    
    # 等待幾個周期讓CSR讀取完成
    nop
    nop
    
    # 比較
    beq a1, a2, test_csr_pass
    
test_csr_fail:
    # 等待UART空閒，發送'F'
uart_wait4:
    lw t1, 0(t5)
    andi t1, t1, 1
    bnez t1, uart_wait4
    li t2, 'F'
    sw t2, 0(t0)
    j end_test
    
test_csr_pass:
    # 等待UART空閒，發送'P'
uart_wait5:
    lw t1, 0(t5)
    andi t1, t1, 1
    bnez t1, uart_wait5
    li t2, 'P'
    sw t2, 0(t0)
    
    # ========== 測試4: 最終標記 ==========
uart_wait6:
    lw t1, 0(t5)
    andi t1, t1, 1
    bnez t1, uart_wait6
    li t2, '!'
    sw t2, 0(t0)
    
end_test:
    # 發送換行符
uart_wait7:
    lw t1, 0(t5)
    andi t1, t1, 1
    bnez t1, uart_wait7
    li t2, '\n'
    sw t2, 0(t0)
    
    # 無限循環
end_loop:
    j end_loop
