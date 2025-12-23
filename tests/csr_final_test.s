.section .text.init
.global _start

_start:
    li t0, 0x10000000  # UART
    
    # 開始標記
    li t1, 'S'
    sw t1, 0(t0)
    
    li sp, 0x8000
    
    # 測試 1: 直接加載立即數到 a1 並寫入 CSR
    li a1, 0x12345678
    
    # 添加 nop 確保數據可用（測試數據前推）
    nop
    nop
    
    # 寫入 CSR
    csrw 0x340, a1
    
    # 標記寫入完成
    li t1, 'W'
    sw t1, 0(t0)
    
    # 讀取 CSR
    csrr a2, 0x340
    
    # 比較
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
    