.section .text
.global _start
// ============================================
// 中断集成测试（最小化）
// 验证中断基础流程不破坏原有功能
// ============================================

_start:
    # 1. 首先运行一些正常指令，确保原有功能正常
    li a0, 1
    li a1, 2
    add a2, a0, a1    # a2 = 3
    
    li a3, 0x12345678
    sw a3, 0(x0)      # 存储测试
    
    # 2. 设置中断向量（简单测试）
    la t0, interrupt_handler
    csrw mtvec, t0
    
    # 3. 使能全局中断
    csrsi mstatus, 8   # 设置MIE位
    
    # 4. 触发一个软件中断（通过CLINT）
    li t0, 0x02000000  # CLINT基地址
    li t1, 1
    sw t1, 0(t0)       # 写MSIP触发软件中断
    
    # 5. 等待中断（或继续执行）
    # 如果中断正常，会跳转到处理程序
    # 如果不正常，继续执行下面的代码
    
    # 6. 正常指令继续执行
    li t2, 0xDEADBEEF
    addi t3, t2, 1
    
    # 7. 成功标记
    li a0, 0x12345678
    li a7, 1
    scall
    
interrupt_handler:
    # 简单的中断处理程序
    # 设置一个标志表示中断发生
    li t4, 0x87654321
    
    # 清除中断源
    li t0, 0x02000000
    sw zero, 0(t0)
    
    # 返回
    mret
    
.section .data
test_data: .word 0x11111111
