.global _start
_start:
    # 测试加载/存储
    li x1, 0x1000
    li x2, 0x55
    sw x2, 0(x1)
    lw x3, 0(x1)
    # 验证
    bne x2, x3, fail
    # 成功退出
    li a0, 0
    ebreak
fail:
    li a0, 1
    ebreak
