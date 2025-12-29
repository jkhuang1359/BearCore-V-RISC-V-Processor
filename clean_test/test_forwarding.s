.text
.globl _start
_start:
    # 测试数据前推
    # 指令序列制造数据冒险
    addi x1, x0, 1    # 1. x1 = 1
    addi x2, x0, 2    # 2. x2 = 2
    add  x3, x1, x2   # 3. x3 = x1 + x2 (需要前推)
    
    # 测试BEQ的数据前推
    addi x4, x0, 3    # 4. x4 = 3
    addi x5, x0, 3    # 5. x5 = 3
    beq  x4, x5, equal  # 6. 应该跳转
    
    # 不应该到这里
    li x10, 0xBAD
    j end

equal:
    li x10, 0x600D
    j end

end:
    j end
