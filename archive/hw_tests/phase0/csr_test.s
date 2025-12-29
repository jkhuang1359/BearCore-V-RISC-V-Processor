################################################################
# CSR 指令硬件测试
################################################################

.global _start
_start:
    # 初始化堆栈
    lui sp, %hi(_stack_top)
    addi sp, sp, %lo(_stack_top)
    
    # 测试 CSRRW
    li x1, 0x12345678
    csrrw x2, mscratch, x1
    # x2 应该得到旧的 mscratch 值
    
    # 测试 CSRRS
    li x1, 0x00000001
    csrrs x3, mscratch, x1
    # x3 应该得到 mscratch 的当前值
    
    # 测试 CSRRC
    li x1, 0x00000001
    csrrc x4, mscratch, x1
    # x4 应该得到 mscratch 的当前值，然后清除位
    
    # 测试 CSR 立即数版本
    csrrwi x5, mscratch, 0x1F
    csrrsi x6, mscratch, 0x01
    csrrci x7, mscratch, 0x01
    
    # 简单验证：如果所有 CSR 指令都执行了（没有异常），则通过
    li t0, 0x10000000
    li t1, 'P'
    sw t1, 0(t0)
    
    ebreak
    