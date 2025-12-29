.global _start
_start:
    # 测试 JAL
    li x1, 0
    jal x2, target
    addi x1, x1, 1      # 这里不应执行
    j fail
    
target:
    # 检查链接地址是否正确
    li x3, back
    bne x2, x3, fail
    
    # 测试 JALR
    la x4, next
    jalr x5, 0(x4)
    
back:
    # 成功
    li t0, 0x10000000
    li t1, 'P'
    sw t1, 0(t0)
    ebreak
    
next:
    li x6, 1
    jalr x0, -4(x4)     # 返回 back
    
fail:
    li t0, 0x10000000
    li t1, 'F'
    sw t1, 0(t0)
    ebreak
    