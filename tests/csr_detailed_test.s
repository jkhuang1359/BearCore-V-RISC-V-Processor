# tests/csr_detailed_test.s
.section .text.init
.global _start

_start:
    li t0, 0x10000000  # UART 地址
    
    # 測試開始
    li t1, 'S'
    sw t1, 0(t0)
    
    li sp, 0x8000
    
    # 1. 先設置 a1 寄存器為測試值
    li a1, 0x12345678
    
    # 2. 執行 csrw 指令
    csrw 0x340, a1
    
    # 3. 讀取並檢查
    csrr a2, 0x340
    
    # 4. 根據結果輸出
    li t1, 'W'
    sw t1, 0(t0)
    
    beq a1, a2, test_pass
    
test_fail:
    li t1, 'F'
    sw t1, 0(t0)
    j end
    
test_pass:
    li t1, 'P'
    sw t1, 0(t0)
    
end:
    li t1, '\n'
    sw t1, 0(t0)
    j end
