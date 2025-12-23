# tests/csr_asm_test.s
.section .text.init
.global _start

_start:
    # UART 地址
    li t0, 0x10000000
    
    # 輸出 'S' 表示開始
    li t1, 'S'
    sw t1, 0(t0)
    
    # 設置堆疊
    li sp, 0x8000
    
    # 🐛 測試 1: 讀取 MISA (0x301)
    csrr a0, 0x301
    # 如果 MISA 讀取成功，輸出 'M'
    li t1, 'M'
    sw t1, 0(t0)
    
    # 🐛 測試 2: 寫入 MSCRATCH (0x340)
    li a1, 0x12345678
    csrw 0x340, a1
    # 輸出 'W' 表示寫入完成
    li t1, 'W'
    sw t1, 0(t0)
    
    # 🐛 測試 3: 讀回 MSCRATCH
    csrr a2, 0x340
    # 如果讀回正確，輸出 'R'
    li t1, 'R'
    sw t1, 0(t0)
    
    # 🐛 檢查讀回值
    beq a1, a2, test_passed
    
test_failed:
    # 輸出 'F' 表示失敗
    li t1, 'F'
    sw t1, 0(t0)
    j end
    
test_passed:
    # 輸出 'P' 表示通過
    li t1, 'P'
    sw t1, 0(t0)
    
end:
    li t1, '\n'
    sw t1, 0(t0)
    j end
    