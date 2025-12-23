.section .text.init
.global _start

_start:
    li t0, 0x10000000  # UART地址
    
    # 開始標記
    li t1, 'S'
    sw t1, 0(t0)
    
    # 測試1: 直接比較（不涉及CSR）
    li a1, 0x12345678
    li a2, 0x12345678
    
    nop
    nop
    
    # 結果標記1
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
    # 測試2: CSR寫入和讀取
    li a1, 0x12345678
    
    # 寫入CSR
    csrw mscratch, a1
    
    # 讀取CSR
    csrr a2, mscratch
    
    nop
    nop
    
    # 結果標記2
    li t1, 'C'
    sw t1, 0(t0)
    
    # 比較
    beq a1, a2, test2_pass
    
test2_fail:
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
    
end:
    li t1, '\n'
    sw t1, 0(t0)
    j end
