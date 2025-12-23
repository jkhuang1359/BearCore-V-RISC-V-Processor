.section .text.init
.global _start

_start:
    # 初始化堆栈指针
    lui sp, 0x8        # sp = 0x00008000
    
    # 跳转到主测试程序
    call main
    
    # 测试完成后进入死循环
loop:
    j loop

# 例外向量表
.section .text.vec
.global trap_vector
.align 4
trap_vector:
    # 保存上下文 (简化版本)
    csrrw sp, mscratch, sp  # 使用mscratch作为临时堆栈
    
    # 根据mcause判断例外类型
    csrr t0, mcause
    srli t1, t0, 31        # 检查最高位 (1=中断, 0=例外)
    bnez t1, handle_interrupt
    
    # 处理例外
    li t1, 2               # 非法指令例外
    beq t0, t1, handle_illegal_inst
    
    li t1, 11              # 环境调用例外
    beq t0, t1, handle_ecall
    
    li t1, 3               # 断点例外
    beq t0, t1, handle_ebreak
    
    # 其他例外
    j handle_other_exception

handle_interrupt:
    andi t0, t0, 0x7FF    # 清除最高位
    li t1, 7               # 定时器中断
    beq t0, t1, handle_timer_interrupt
    
    li t1, 3               # 软件中断
    beq t0, t1, handle_software_interrupt
    
    li t1, 11              # 外部中断
    beq t0, t1, handle_external_interrupt
    
    j handle_other_interrupt

handle_timer_interrupt:
    # 定时器中断处理
    # 清除中断标志 (写mtimecmp)
    li t0, 0x20000008      # mtimecmp地址
    li t1, 0xFFFFFFFF
    sw t1, 0(t0)
    
    # 增加中断计数器
    la t0, timer_int_count
    lw t1, 0(t0)
    addi t1, t1, 1
    sw t1, 0(t0)
    
    j trap_exit

handle_ecall:
    # ECALL处理 - 用于系统调用
    csrr t0, mepc
    addi t0, t0, 4         # 跳过ECALL指令
    csrw mepc, t0
    
    # 设置返回值 (a0 = 1表示ECALL处理成功)
    li a0, 1
    
    j trap_exit

handle_ebreak:
    # EBREAK处理 - 断点
    csrr t0, mepc
    addi t0, t0, 4         # 跳过EBREAK指令
    csrw mepc, t0
    
    # 设置断点标志
    li a0, 0xBEEF
    
    j trap_exit

handle_illegal_inst:
    # 非法指令处理
    csrr t0, mepc
    addi t0, t0, 4         # 跳过非法指令
    csrw mepc, t0
    
    li a0, 0xDEAD          # 错误码
    
    j trap_exit

trap_exit:
    # 恢复上下文
    csrr sp, mscratch
    
    mret

handle_software_interrupt:
handle_external_interrupt:
handle_other_exception:
handle_other_interrupt:
    # 默认处理
    mret

.section .data
timer_int_count: .word 0
