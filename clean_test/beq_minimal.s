.text
.globl _start
_start:
    # 最小BEQ測試
    li x1, 1
    li x2, 1
    beq x1, x2, target_equal
    
    # 如果執行到這裡，BEQ失敗
    li x10, 0xBAD
    j end

target_equal:
    # BEQ成功跳轉
    li x10, 0x600D
    j end

end:
    j end
