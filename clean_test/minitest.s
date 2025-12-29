.text
.globl _start
_start:
    # 测试1: 确认指令读取正确
    nop                     # 0x00000013
    
    # 测试2: 寄存器操作
    addi x1, x0, 0x123      # x1 = 0x123
    
    # 测试3: 简单算术
    addi x2, x0, 0x456      # x2 = 0x456
    add x3, x1, x2          # x3 = 0x579
    
    # 测试4: 内存写入/读取
    li sp, 0x1000           # 设置堆栈
    sw x3, 0(sp)
    lw x4, 0(sp)            # x4 应该等于 x3
    
    # 测试5: 条件分支
    beq x3, x4, branch_ok   # 应该跳转
    j test_fail

branch_ok:
    # 测试6: 跳转指令
    j success

test_fail:
    j test_fail

success:
    # 成功标记
    addi x10, x0, 0x123
    j end

end:
    j end
