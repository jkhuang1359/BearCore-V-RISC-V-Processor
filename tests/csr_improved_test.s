.section .text.init
.global _start

_start:
    li t0, 0x10000000  # UART 地址
    
    # 發送開始標記
    li t1, 'S'
    sw t1, 0(t0)
    
    li sp, 0x8000
    
    # === 測試 1: 驗證數據路徑 ===
    # 先寫入寄存器，確保數據可用
    li a1, 0x12345678
    nop                     # 確保數據寫回寄存器文件
    nop                     # 等待寫回完成
    
    # 寫入 CSR
    csrw 0x340, a1         # mscratch = a1
    
    # 發送寫入完成標記
    li t1, 'W'
    sw t1, 0(t0)
    
    # 讀取 CSR 驗證
    csrr a2, 0x340
    
    # 比較驗證
    beq a1, a2, test_pass
    j test_fail
    
test_fail:
    li t1, 'F'
    sw t1, 0(t0)
    j end_test
    
test_pass:
    li t1, 'P'
    sw t1, 0(t0)
    
end_test:
    li t1, '\n'
    sw t1, 0(t0)
    
    # 停止模擬
    li t1, 0x5555
    sw t1, 0(t0)
    
    j end_test

.section .data
test_data:
    .word 0x12345678
    