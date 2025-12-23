# tests/csr_simple_test.s
.section .text.init
.global _start

_start:
    # 初始化堆栈指针
    lui sp, 0x8        # sp = 0x00008000
    
    # 设置mtvec为异常处理程序地址
    la t0, trap_handler
    csrw mtvec, t0
    
    # 跳转到主测试程序
    call main
    
    # 测试完成后进入死循环
loop:
    j loop

# 简单的异常处理程序
trap_handler:
    # 保存上下文
    csrw mscratch, a0
    
    # 获取mcause
    csrr a0, mcause
    
    # 如果是ECALL (cause=11)，跳过指令继续执行
    li t0, 11
    beq a0, t0, handle_ecall
    
    # 如果是EBREAK (cause=3)，跳过指令继续执行
    li t0, 3
    beq a0, t0, handle_ebreak
    
    # 其他异常，直接返回
    j trap_return

handle_ecall:
handle_ebreak:
    # 增加mepc以跳过ecall/ebreak指令
    csrr a0, mepc
    addi a0, a0, 4
    csrw mepc, a0

trap_return:
    # 恢复上下文
    csrr a0, mscratch
    
    # 从异常返回
    mret
    