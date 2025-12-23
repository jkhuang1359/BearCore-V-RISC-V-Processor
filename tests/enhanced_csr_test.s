.section .text.init
.global _start

_start:
    li t0, 0x10000000  # UART地址
    
    # 開始標記
    li t1, 'S'
    sw t1, 0(t0)
    
    # 測試1: 寫入寄存器後立即使用（測試前推）
    li a1, 0x12345678
    
    # 插入更多的nop確保數據可用
    nop
    nop
    nop
    nop
    nop
    nop
    
    # 寫入CSR
    csrw 0x340, a1
    
    # 寫入標記
    li t1, 'W'
    sw t1, 0(t0)
    
    # 讀取CSR
    csrr a2, 0x340
    
    # 讀取標記
    li t1, 'R'
    sw t1, 0(t0)
    
    # 比較
    beq a1, a2, test1_pass
    
test1_fail:
    li t1, '1'
    sw t1, 0(t0)
    li t1, 'F'
    sw t1, 0(t0)
    j test2
    
test1_pass:
    li t1, '1'
    sw t1, 0(t0)
    li t1, 'P'
    sw t1, 0(t0)
    
test2:
    # 測試2: 使用csrwi寫入小立即數（0-31）
    csrwi 0x340, 0x1F  # 5位立即數的最大值
    
    # 寫入標記
    li t1, 'W'
    sw t1, 0(t0)
    
    # 讀取並驗證
    csrr a3, 0x340
    li t2, 0x1F
    beq a3, t2, test2_pass
    
    li t1, '2'
    sw t1, 0(t0)
    li t1, 'F'
    sw t1, 0(t0)
    j test3
    
test2_pass:
    li t1, '2'
    sw t1, 0(t0)
    li t1, 'P'
    sw t1, 0(t0)
    
test3:
    # 測試3: 使用寄存器寫入大數
    li t3, 0x89ABCDEF
    csrw 0x340, t3
    
    # 寫入標記
    li t1, 'W'
    sw t1, 0(t0)
    
    # 讀取並驗證
    csrr a4, 0x340
    li t4, 0x89ABCDEF
    beq a4, t4, test3_pass
    
    li t1, '3'
    sw t1, 0(t0)
    li t1, 'F'
    sw t1, 0(t0)
    j end
    
test3_pass:
    li t1, '3'
    sw t1, 0(t0)
    li t1, 'P'
    sw t1, 0(t0)
    
end:
    li t1, '\n'
    sw t1, 0(t0)
    j end
    