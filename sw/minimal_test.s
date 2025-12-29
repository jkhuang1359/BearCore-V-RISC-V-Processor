.section .text.init
.global _start

_start:
    li t0, 0x10000000  # UART
    
    # 開始標記
    li t1, 'S'
    sw t1, 0(t0)
    
    # 簡單測試：寫入寄存器，立即比較
    li a1, 0x12345678
    li a2, 0x12345678
    
    # 等待數據可用
    nop
    nop
    
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
    