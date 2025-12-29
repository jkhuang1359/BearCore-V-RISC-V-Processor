.text
.globl _start
_start:
    # 測試1: 寄存器操作
    li x1, 0x11111111
    li x2, 0x22222222
    li x3, 0x33333333
    
    # 測試2: 算術指令
    add x4, x1, x2      # x4 = 0x33333333
    sub x5, x2, x1      # x5 = 0x11111111
    
    # 測試3: 內存存儲/加載
    li sp, 0x00001000   # 設置堆疊指針
    sw x1, 0(sp)
    sw x2, 4(sp)
    lw x6, 0(sp)        # x6 應該 = 0x11111111
    lw x7, 4(sp)        # x7 應該 = 0x22222222
    
    # 測試4: 比較和分支
    beq x6, x1, branch_ok1
    j test_fail
    
branch_ok1:
    bne x7, x2, test_fail
    j branch_ok2
    
branch_ok2:
    # 測試5: 跳轉和鏈接
    jal x8, target_func
    j test_success
    
target_func:
    addi x9, x0, 1
    jalr x0, x8, 0
    
test_fail:
    # 失敗標記
    li x10, 0xBADBAD
    j end
    
test_success:
    # 成功標記
    li x10, 0x600D600D
    j end
    
end:
    j end
