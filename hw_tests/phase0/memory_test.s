.global _start
_start:
    # 初始化堆栈
    lui sp, %hi(_stack_top)
    addi sp, sp, %lo(_stack_top)
    
    # 测试地址
    li x2, 0x1000
    
    # 测试 SW/LW
    li x1, 0xDEADBEEF
    sw x1, 0(x2)
    lw x3, 0(x2)
    bne x1, x3, fail
    
    # 测试 SH/LH/LHU
    li x1, 0x1234ABCD
    sh x1, 4(x2)
    
    # LH（有符号扩展）
    lh x3, 4(x2)
    li x4, 0xFFFFABCD
    bne x3, x4, fail
    
    # LHU（无符号扩展）
    lhu x3, 4(x2)
    li x4, 0x0000ABCD
    bne x3, x4, fail
    
    # 测试 SB/LB/LBU
    li x1, 0xA5
    sb x1, 8(x2)
    
    # LB（有符号扩展）
    lb x3, 8(x2)
    li x4, 0xFFFFFFA5
    bne x3, x4, fail
    
    # LBU（无符号扩展）
    lbu x3, 8(x2)
    li x4, 0x000000A5
    bne x3, x4, fail
    
    # 测试字序（小端序）
    li x1, 0x44332211
    sw x1, 12(x2)
    
    # 检查字节
    lb x3, 12(x2)   # 0x11
    li x4, 0x11
    bne x3, x4, fail
    
    lb x3, 13(x2)   # 0x22
    li x4, 0x22
    bne x3, x4, fail
    
    lb x3, 14(x2)   # 0x33
    li x4, 0x33
    bne x3, x4, fail
    
    lb x3, 15(x2)   # 0x44
    li x4, 0x44
    bne x3, x4, fail
    
    # 所有测试通过
    j success
    
fail:
    li t0, 0x10000000
    li t1, 'F'
    sw t1, 0(t0)
    j end_test
    
success:
    li t0, 0x10000000
    li t1, 'P'
    sw t1, 0(t0)
    
end_test:
    ebreak
    