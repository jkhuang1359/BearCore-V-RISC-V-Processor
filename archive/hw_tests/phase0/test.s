################################################################
# 基本功能测试
################################################################

.global _start
_start:
    # 测试各种指令
    li x1, 10
    li x2, 20
    add x3, x1, x2      # 30
    sub x4, x2, x1      # 10
    and x5, x1, x2      # 0
    or  x6, x1, x2      # 30
    xor x7, x1, x2      # 30
    
    # 验证结果
    li x8, 30
    bne x3, x8, fail
    li x8, 10
    bne x4, x8, fail
    bne x5, zero, fail
    
    # 成功
    li t0, 0x10000000
    li t1, 'P'
    sw t1, 0(t0)
    ebreak
    
fail:
    li t0, 0x10000000
    li t1, 'F'
    sw t1, 0(t0)
    ebreak
    