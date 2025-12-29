################################################################
# 控制流指令硬件测试
################################################################

.global _start
_start:
    # 初始化堆栈
    lui sp, %hi(_stack_top)
    addi sp, sp, %lo(_stack_top)
    
    # 测试 JAL
    li x1, 0
    jal x2, target1
back1:
    addi x1, x1, 1      # 标记返回
    
target1:
    jalr x0, 0(x2)      # 返回 back1
    
    # 测试 BEQ
    li x3, 10
    li x4, 10
    beq x3, x4, branch_ok1
    j fail
    
branch_ok1:
    # 测试 BNE
    li x3, 10
    li x4, 20
    bne x3, x4, branch_ok2
    j fail
    
branch_ok2:
    # 测试 BLT
    li x3, -5
    li x4, 5
    blt x3, x4, branch_ok3
    j fail
    
branch_ok3:
    # 测试 BGE
    li x3, 10
    li x4, 5
    bge x3, x4, branch_ok4
    j fail
    
branch_ok4:
    # 测试 BLTU
    li x3, 0xFFFFFFFF
    li x4, 0x00000001
    bltu x3, x4, fail  # 不应跳转
    # 继续执行表示正确
    
    # 测试 BGEU
    bgeu x3, x4, branch_ok5
    j fail
    
branch_ok5:
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
    