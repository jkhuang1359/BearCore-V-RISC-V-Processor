.text
.globl _start
_start:
    # 简单BEQ测试
    li x1, 0x12345678
    li x2, 0x12345678
    
    # 相等时应该跳转
    beq x1, x2, equal
    
    # 不应该执行到这里
    li x10, 0xDEADBEEF
    j end

equal:
    # 应该跳转到这里
    li x10, 0x600D600D
    
    # 测试不相等情况
    li x3, 0x11111111
    li x4, 0x22222222
    beq x3, x4, should_not_jump
    
    # 应该继续执行（因为不相等）
    li x11, 0x55555555
    j final

should_not_jump:
    # 不应该到这里
    li x11, 0xBADBAD
    j end

final:
    li x12, 0x12345678
    j end

end:
    j end
