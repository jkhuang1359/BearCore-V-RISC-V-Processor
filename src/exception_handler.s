.section .text.vec
.global exception_vector
.align 4

exception_vector:
    # 🏆 保存上下文（簡單版本）
    csrrw sp, mscratch, sp   # 交換 sp 和 mscratch（如果 mscratch 已設置）
    
    # 保存 ra
    addi sp, sp, -4
    sw ra, 0(sp)
    
    # 保存其他需要保存的寄存器...
    
    # 調用 C 例外處理函數
    call exception_handler
    
    # 恢復上下文
    lw ra, 0(sp)
    addi sp, sp, 4
    
    # 恢復 sp
    csrrw sp, mscratch, sp
    
    # 返回
    mret

.section .text.init
.global _start

_start:
    # 🏆 設置例外向量
    la t0, exception_vector
    csrw mtvec, t0
    
    # 🏆 設置 mscratch 為臨時堆疊
    li t0, 0x7000
    csrw mscratch, t0
    
    # 設置堆疊指標
    li sp, 0x8000
    
    # 跳轉到 main
    call main
    
loop:
    j loop