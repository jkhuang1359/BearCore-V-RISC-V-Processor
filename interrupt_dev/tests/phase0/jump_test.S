.global _start
_start:
    # 测试跳转指令
    li x1, 1
    li x2, 2
    beq x1, x2, fail  # 不应跳转
    bne x1, x2, pass  # 应跳转
    j fail
pass:
    li a0, 0
    ebreak
fail:
    li a0, 1
    ebreak
