.text
.globl _start
_start:
    # 初始化寄存器
    addi x1, x0, 1      # x1 = 1
    addi x2, x0, 1      # x2 = 1
    
    # 测试BEQ：相等应该跳转
    beq x1, x2, equal   # 应该跳转
    
    # 如果到这里，BEQ失败
    addi x10, x0, 0xBAD
    j end
    
equal:
    # BEQ成功
    addi x10, x0, 0x600D
    j end
    
end:
    j end
