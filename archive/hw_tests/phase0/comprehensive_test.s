################################################################
# 綜合測試：測試所有主要功能
# 通過則輸出 "PASS"，失敗則輸出 "FAIL"
################################################################

.global _start
_start:
    # 初始化堆棧
    lui sp, %hi(_stack_top)
    addi sp, sp, %lo(_stack_top)
    
    # 發送開始信號
    li t0, 0x10000000
    li t1, 'S'
    sw t1, 0(t0)
    
    # ==================== 測試 1: ALU 基本運算 ====================
    li x1, 0x12345678
    li x2, 0x11111111
    add x3, x1, x2      # 0x23456789
    li x4, 0x23456789
    bne x3, x4, fail
    
    # ==================== 測試 2: 控制流指令 ====================
    # 測試 BEQ
    li x5, 10
    li x6, 10
    beq x5, x6, test2_pass1
    j fail
test2_pass1:
    
    # 測試 JAL
    li x7, 0
    jal x8, test2_target
test2_back:
    addi x7, x7, 1
    bne x7, x1, fail
    
test2_target:
    jalr x0, 0(x8)      # 返回
    
    # ==================== 測試 3: 內存訪問 ====================
    li x9, 0x1000
    li x10, 0xDEADBEEF
    sw x10, 0(x9)
    lw x11, 0(x9)
    bne x10, x11, fail
    
    # ==================== 測試 4: CSR 指令 ====================
    # 簡單測試 CSR 指令是否執行（不檢查具體值）
    li x12, 0x12345678
    csrrw x13, mscratch, x12
    # 如果執行到這裡，沒有產生例外，則通過
    
    # ==================== 所有測試通過 ====================
    j success
    
fail:
    # 發送失敗信號
    li t0, 0x10000000
    li t1, 'F'
    sw t1, 0(t0)
    li t1, 'A'
    sw t1, 0(t0)
    li t1, 'I'
    sw t1, 0(t0)
    li t1, 'L'
    sw t1, 0(t0)
    li t1, '\n'
    sw t1, 0(t0)
    j end_test
    
success:
    # 發送成功信號
    li t0, 0x10000000
    li t1, 'P'
    sw t1, 0(t0)
    li t1, 'A'
    sw t1, 0(t0)
    li t1, 'S'
    sw t1, 0(t0)
    li t1, 'S'
    sw t1, 0(t0)
    li t1, '\n'
    sw t1, 0(t0)
    
end_test:
    ebreak

# 堆棧頂部定義
_stack_top = 0x00020000
