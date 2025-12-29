.globl _start
_start:
    # 设置返回值为0（成功）
    li a0, 0
    
    # 使用ecall退出（在某些配置中可能有效）
    # li a7, 93   # exit系统调用号
    # ecall
    
    # 或者使用ebreak
    ebreak
