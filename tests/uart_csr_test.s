.section .text.init
.global _start

_start:
    li t0, 0x10000000  # UART數據地址
    li t3, 0x10000004  # UART狀態地址
    
    # 等待UART空閒
wait_uart_ready:
    lw t4, 0(t3)       # 讀取狀態寄存器
    andi t4, t4, 1     # 檢查busy位 (bit0)
    bnez t4, wait_uart_ready  # 如果busy=1，等待
    
    # 測試開始標記
    li t1, 'S'
    sw t1, 0(t0)
    
    # ========== 測試1: 基本CSR寫入/讀取 ==========
    li a1, 0x12345678
    
    # 等待數據可用（多個nop確保寫回）
    nop
    nop
    nop
    nop
    nop
    nop
    
    # 寫入 CSR (CSRRW)
    csrw mscratch, a1
    
    # 等待CSR寫入完成
    nop
    nop
    nop
    
    # 讀取 CSR (CSRRS)
    csrr a2, mscratch
    
    # 等待讀取完成
    nop
    nop
    
    # 等待UART空閒
wait1:
    lw t4, 0(t3)
    andi t4, t4, 1
    bnez t4, wait1
    
    # 發送測試1結果標記
    li t1, '1'
    sw t1, 0(t0)
    
    # 比較結果
    beq a1, a2, test1_pass
    
    # 測試1失敗
wait2:
    lw t4, 0(t3)
    andi t4, t4, 1
    bnez t4, wait2
    
    li t1, 'F'
    sw t1, 0(t0)
    j end
    
test1_pass:
    # 等待UART空閒
wait3:
    lw t4, 0(t3)
    andi t4, t4, 1
    bnez t4, wait3
    
    li t1, 'P'
    sw t1, 0(t0)
    
    # ========== 測試2: 立即數寫入 ==========
    # 等待UART空閒
wait4:
    lw t4, 0(t3)
    andi t4, t4, 1
    bnez t4, wait4
    
    # 寫入立即數 (CSRRWI)
    csrwi mscratch, 0x1F
    
    # 等待
    nop
    nop
    
    # 讀取驗證
    csrr a3, mscratch
    li t2, 0x1F
    
    # 發送測試2開始標記
    li t1, '2'
    sw t1, 0(t0)
    
    # 等待UART空閒
wait5:
    lw t4, 0(t3)
    andi t4, t4, 1
    bnez t4, wait5
    
    # 比較
    beq a3, t2, test2_pass
    
    # 測試2失敗
    li t1, 'F'
    sw t1, 0(t0)
    j end
    
test2_pass:
    # 等待UART空閒
wait6:
    lw t4, 0(t3)
    andi t4, t4, 1
    bnez t4, wait6
    
    li t1, 'P'
    sw t1, 0(t0)
    
    # 最終成功標記
wait7:
    lw t4, 0(t3)
    andi t4, t4, 1
    bnez t4, wait7
    
    li t1, '!'
    sw t1, 0(t0)
    
end:
    # 等待UART空閒
wait8:
    lw t4, 0(t3)
    andi t4, t4, 1
    bnez t4, wait8
    
    li t1, '\n'
    sw t1, 0(t0)
    
final_wait:
    j final_wait
    