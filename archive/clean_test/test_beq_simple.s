.text
.globl _start
_start:
    # 测试BEQ指令
    # 初始化寄存器
    li x1, 0x12345678
    li x2, 0x12345678
    
    # 测试1：相等应该跳转
    beq x1, x2, target1
    
    # 如果执行到这里，BEQ失败
    li x10, 0xDEAD  # 失败标记
    j fail
    
target1:
    # 测试2：不相等不应该跳转
    li x3, 0x11111111
    li x4, 0x22222222
    beq x3, x4, fail  # 不应该跳转
    
    # 如果继续执行，BEQ正确
    li x10, 0xBEEF   # 成功标记
    j end

fail:
    li x11, 0xBAD    # 额外失败标记
    j fail

end:
    j end
