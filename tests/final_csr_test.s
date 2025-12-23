.section .text.init
.global _start

_start:
    li t0, 0x10000000  # UART地址
    
    # 開始標記
    li t1, 'S'
    sw t1, 0(t0)
    
    # 測試：寫入寄存器 -> 寫入CSR -> 讀取CSR -> 比較
    
    # 步驟1: 寫入寄存器
    li a1, 0x12345678
    
    # 確保數據寫回（插入足夠的nop）
    nop
    nop
    nop
    nop
    
    # 步驟2: 寫入CSR (csrw)
    csrw 0x340, a1
    
    # 寫入完成標記
    li t1, 'W'
    sw t1, 0(t0)
    
    # 步驟3: 讀取CSR (csrr)
    csrr a2, 0x340
    
    # 讀取完成標記
    li t1, 'R'
    sw t1, 0(t0)
    
    # 步驟4: 比較
    beq a1, a2, pass
    
fail:
    li t1, 'F'
    sw t1, 0(t0)
    j end
    
pass:
    li t1, 'P'
    sw t1, 0(t0)
    
end:
    li t1, '\n'
    sw t1, 0(t0)
    j end
    