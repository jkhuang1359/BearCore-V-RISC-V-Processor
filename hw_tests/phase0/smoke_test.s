################################################################
# 冒煙測試：最基本的硬體功能測試
# 如果 CPU 能執行這幾條指令，說明基本功能正常
################################################################

.global _start
_start:
    # 測試 1: 加載立即數和加法
    li x1, 1
    li x2, 2
    add x3, x1, x2      # 1 + 2 = 3
    
    # 測試 2: 比較
    li x4, 3
    bne x3, x4, fail    # 如果不等，失敗
    
    # 測試 3: 存儲和加載
    li x5, 0x1000
    li x6, 0x55AA55AA
    sw x6, 0(x5)
    lw x7, 0(x5)
    bne x6, x7, fail    # 如果不相等，失敗
    
    # 測試 4: 條件分支
    li x8, 10
    li x9, 20
    blt x8, x9, pass_test4  # 10 < 20，應該跳轉
    j fail
    
pass_test4:
    # 所有測試通過，輸出 "PASS" 到 UART
    li t0, 0x10000000   # UART 地址
    
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
    
    # 結束
    ebreak
    
fail:
    # 測試失敗，輸出 "FAIL" 到 UART
    li t0, 0x10000000   # UART 地址
    
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
    
    # 結束
    ebreak
    