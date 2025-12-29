################################################################
# ALU 全面硬件测试
# 通过 UART 输出结果，验证硬件实现
################################################################

.global _start
_start:
    # 初始化堆栈
    lui sp, %hi(_stack_top)
    addi sp, sp, %lo(_stack_top)
    
    # 测试 ADD
    li x1, 0x12345678
    li x2, 0x11111111
    add x3, x1, x2      # 0x23456789
    li x4, 0x23456789
    bne x3, x4, fail
    
    # 测试 SUB
    li x1, 0x100
    li x2, 0x55
    sub x3, x1, x2      # 0xAB
    li x4, 0xAB
    bne x3, x4, fail
    
    # 测试 AND
    li x1, 0xFF00FF00
    li x2, 0x00FF00FF
    and x3, x1, x2      # 0x00000000
    bne x3, zero, fail
    
    # 测试 OR
    or x3, x1, x2       # 0xFFFFFFFF
    li x4, 0xFFFFFFFF
    bne x3, x4, fail
    
    # 测试 XOR
    li x1, 0xAAAAAAAA
    li x2, 0x55555555
    xor x3, x1, x2      # 0xFFFFFFFF
    bne x3, x4, fail
    
    # 测试 SLL
    li x1, 0x0000000F
    li x2, 4
    sll x3, x1, x2      # 0x000000F0
    li x4, 0x000000F0
    bne x3, x4, fail
    
    # 测试 SRL
    li x1, 0xF0000000
    srl x3, x1, x2      # 0x0F000000
    li x4, 0x0F000000
    bne x3, x4, fail
    
    # 测试 SRA（算术右移）
    li x1, 0x80000000
    sra x3, x1, x2      # 0xF8000000
    li x4, 0xF8000000
    bne x3, x4, fail
    
    # 测试 SLT（有符号比较）
    li x1, -1
    li x2, 1
    slt x3, x1, x2      # 1
    li x4, 1
    bne x3, x4, fail
    
    # 测试 SLTU（无符号比较）
    sltu x3, x1, x2     # 0
    bne x3, zero, fail
    
    # 所有测试通过
    j success
    
fail:
    # 发送失败信号到 UART (发送 'F')
    li t0, 0x10000000
    li t1, 'F'
    sw t1, 0(t0)
    j end_test
    
success:
    # 发送成功信号到 UART (发送 'P')
    li t0, 0x10000000
    li t1, 'P'
    sw t1, 0(t0)
    
end_test:
    ebreak
    