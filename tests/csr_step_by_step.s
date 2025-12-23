# tests/csr_step_by_step.s
.section .text.init
.global _start

_start:
    # UART 地址
    li t0, 0x10000000
    
    # 測試開始標記
    li t1, 'S'
    sw t1, 0(t0)
    
    # 設置堆疊
    li sp, 0x8000
    
    # ===== 第 1 步：確保 a1 有正確的值 =====
    # 使用立即數加載到 a1
    li a1, 0x12345678
    
    # 輸出 'L' 表示 li 指令完成
    li t1, 'L'
    sw t1, 0(t0)
    
    # ===== 第 2 步：執行 CSR 寫入 =====
    # 寫入 MSCRATCH (0x340)
    csrw 0x340, a1
    
    # 輸出 'W' 表示 csrw 指令完成
    li t1, 'W'
    sw t1, 0(t0)
    
    # ===== 第 3 步：執行 CSR 讀取 =====
    # 讀取 MSCRATCH 到 a2
    csrr a2, 0x340
    
    # 輸出 'R' 表示 csrr 指令完成
    li t1, 'R'
    sw t1, 0(t0)
    
    # ===== 第 4 步：比較結果 =====
    # 比較 a1 和 a2
    beq a1, a2, test_passed
    
test_failed:
    # 輸出 'F' 表示失敗
    li t1, 'F'
    sw t1, 0(t0)
    
    # 輸出失敗原因
    # 如果 a2 == 0，輸出 '0'
    beqz a2, output_zero
    j end_test
    
output_zero:
    li t1, '0'
    sw t1, 0(t0)
    j end_test
    
test_passed:
    # 輸出 'P' 表示通過
    li t1, 'P'
    sw t1, 0(t0)
    
end_test:
    # 換行
    li t1, '\n'
    sw t1, 0(t0)
    
    # 無限循環
    j end_test