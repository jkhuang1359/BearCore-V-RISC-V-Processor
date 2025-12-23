.section .text.init
.global _start

_start:
    li t0, 0x10000000  # UART地址
    
    # 測試開始標記
    li t1, 'S'
    sw t1, 0(t0)
    
    # ========== 測試1: 基本CSR寫入/讀取 ==========
    li a1, 0x12345678
    
    # 等待數據可用
    nop
    nop
    nop
    nop
    
    # 寫入 CSR (CSRRW)
    csrw mscratch, a1
    
    # 讀取 CSR (CSRRS)
    csrr a2, mscratch
    
    # 比較結果
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
    
    # ========== 測試2: 立即數寫入 ==========
test2:
    # 寫入立即數 (CSRRWI)
    csrwi mscratch, 0x1F
    
    # 讀取驗證
    csrr a3, mscratch
    li t2, 0x1F
    beq a3, t2, test2_pass
    
    li t1, '2'
    sw t1, 0(t0)
    li t1, 'F'
    sw t1, 0(t0)
    j end
    
test2_pass:
    li t1, '2'
    sw t1, 0(t0)
    li t1, 'P'
    sw t1, 0(t0)
    
    # 最終成功標記
    li t1, '!'
    sw t1, 0(t0)
    
end:
    li t1, '\n'
    sw t1, 0(t0)
    j end
    