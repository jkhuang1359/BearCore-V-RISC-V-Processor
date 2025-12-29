.section .text
.global _start

# 性能基准测试套件
_start:
    # 打印测试开始消息
    la a0, test_start_msg
    jal ra, print_string
    
    # 1. ALU算术运算性能测试
    jal ra, test_alu_arithmetic
    
    # 2. 分支预测性能测试
    jal ra, test_branch_performance
    
    # 3. 内存访问性能测试
    jal ra, test_memory_performance
    
    # 4. CSR访问性能测试
    jal ra, test_csr_performance
    
    # 打印测试完成消息
    la a0, test_complete_msg
    jal ra, print_string
    
    # 结束测试
    li a0, 0
    li a7, 1
    scall

# ========================================
# ALU算术运算性能测试
# ========================================
test_alu_arithmetic:
    addi sp, sp, -16
    sw ra, 12(sp)
    
    la a0, alu_test_msg
    jal ra, print_string
    
    li t0, 1000000      # 迭代次数
    li t1, 0x12345678   # 测试数据1
    li t2, 0x9ABCDEF0   # 测试数据2
    
    # 开始计时（使用cycle计数器）
    csrr t3, mcycle
    
alu_loop:
    # 执行各种ALU操作
    add t4, t1, t2
    sub t5, t1, t2
    and t6, t1, t2
    or  s0, t1, t2
    xor s1, t1, t2
    sll s2, t1, t2
    srl s3, t1, t2
    
    addi t0, t0, -1
    bnez t0, alu_loop
    
    # 结束计时
    csrr t4, mcycle
    sub t5, t4, t3
    
    # 打印结果
    mv a0, t5
    jal ra, print_cycles
    
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

# ========================================
# 分支性能测试
# ========================================
test_branch_performance:
    addi sp, sp, -16
    sw ra, 12(sp)
    
    la a0, branch_test_msg
    jal ra, print_string
    
    li t0, 500000       # 迭代次数
    li t1, 0            # 计数器
    
    # 开始计时
    csrr t2, mcycle
    
branch_loop:
    # 分支模式1：总是跳转
    beqz zero, branch_target1
branch_target1:
    
    # 分支模式2：条件跳转（50%概率）
    andi t3, t1, 1
    beqz t3, branch_target2
    addi t4, zero, 1
branch_target2:
    
    # 分支模式3：长跳转
    jal ra, branch_subroutine
    
    addi t1, t1, 1
    addi t0, t0, -1
    bnez t0, branch_loop
    
    # 结束计时
    csrr t3, mcycle
    sub t4, t3, t2
    
    # 打印结果
    mv a0, t4
    jal ra, print_cycles
    
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

branch_subroutine:
    ret

# ========================================
# 内存访问性能测试
# ========================================
test_memory_performance:
    addi sp, sp, -16
    sw ra, 12(sp)
    
    la a0, memory_test_msg
    jal ra, print_string
    
    li t0, 100000       # 迭代次数
    li t1, 0x1000       # 测试地址
    
    # 开始计时
    csrr t2, mcycle
    
memory_loop:
    # 连续内存访问模式
    sw t0, 0(t1)
    lw t3, 0(t1)
    sw t0, 4(t1)
    lw t4, 4(t1)
    sw t0, 8(t1)
    lw t5, 8(t1)
    sw t0, 12(t1)
    lw t6, 12(t1)
    
    addi t0, t0, -1
    bnez t0, memory_loop
    
    # 结束计时
    csrr t3, mcycle
    sub t4, t3, t2
    
    # 打印结果
    mv a0, t4
    jal ra, print_cycles
    
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

# ========================================
# CSR访问性能测试
# ========================================
test_csr_performance:
    addi sp, sp, -16
    sw ra, 12(sp)
    
    la a0, csr_test_msg
    jal ra, print_string
    
    li t0, 500000       # 迭代次数
    
    # 开始计时
    csrr t1, mcycle
    
csr_loop:
    # CSR读写操作
    csrr t2, mcycle
    csrr t3, minstret
    csrr t4, mstatus
    csrw mscratch, t0
    csrr t5, mscratch
    
    addi t0, t0, -1
    bnez t0, csr_loop
    
    # 结束计时
    csrr t2, mcycle
    sub t3, t2, t1
    
    # 打印结果
    mv a0, t3
    jal ra, print_cycles
    
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

# ========================================
# 辅助函数：打印字符串
# ========================================
print_string:
    # 简单打印到UART（假设地址0x10000000）
    li t0, 0x10000000
print_loop:
    lb t1, 0(a0)
    beqz t1, print_done
    sb t1, 0(t0)
    addi a0, a0, 1
    j print_loop
print_done:
    ret

# ========================================
# 辅助函数：打印周期数
# ========================================
print_cycles:
    addi sp, sp, -16
    sw ra, 12(sp)
    
    # 打印周期数
    la a1, cycles_buffer
    jal ra, hex_to_string
    
    la a0, cycles_buffer
    jal ra, print_string
    
    la a0, newline
    jal ra, print_string
    
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

# ========================================
# 十六进制转字符串
# ========================================
hex_to_string:
    li t0, 8            # 8个十六进制数字
    addi t1, a1, 7      # 缓冲区末尾
    
hex_loop:
    andi t2, a0, 0xF    # 获取最低4位
    addi t3, t2, '0'    # 转换为字符
    li t4, '9'
    bleu t3, t4, hex_store
    addi t3, t3, 7      # A-F
hex_store:
    sb t3, 0(t1)
    srli a0, a0, 4      # 右移4位
    addi t1, t1, -1
    addi t0, t0, -1
    bnez t0, hex_loop
    
    # 添加"0x"前缀
    li t0, 'x'
    sb t0, 1(a1)
    li t0, '0'
    sb t0, 0(a1)
    
    # 添加null终止符
    sb zero, 8(a1)
    
    ret

# ========================================
# 数据段
# ========================================
.section .data
test_start_msg:
    .asciz "\n=== RISC-V Core Performance Benchmark ===\n\n"

alu_test_msg:
    .asciz "ALU Arithmetic Test (1M iterations): "

branch_test_msg:
    .asciz "Branch Performance Test (500K iterations): "

memory_test_msg:
    .asciz "Memory Access Test (100K iterations): "

csr_test_msg:
    .asciz "CSR Access Test (500K iterations): "

test_complete_msg:
    .asciz "\n=== Performance Benchmark Complete ===\n"

newline:
    .asciz " cycles\n"

cycles_buffer:
    .space 9
