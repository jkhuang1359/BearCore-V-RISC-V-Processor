# src/start.s - 還原版
.section .text.init
.globl _start
.align 2

_start:
    # 🏆 還原為原本能動的堆疊設定
    li sp, 0x0001F000             #la sp, _stack_top    
    # mtvec 指向 0x100
    li t0, 0x00000100
    csrw mtvec, t0
    
    # 直接進入 main
    jal ra, main

1:  j 1b

# --- 例外向量表區段 ---
.section .text.vec
.align 2
.global exception_entry

exception_entry:
    # 1. 在堆疊上開闢空間 (32 個 32-bit 暫存器 = 128 bytes)
    addi sp, sp, -128

    # 🏆 核心修正：先把被中斷的 PC (mepc) 存進堆疊的第一個位置
    sw x5, 20(sp)
    csrr x5, mepc
    sw x5, 0(sp)      # 存入靈魂位址 (offset 0)

    # 2. 保存通用暫存器 x1, x3-x31 (x2 是 sp，稍後特殊處理；x0 不用存)
    sw x1,  4(sp)   # ra
    # x2 (sp) 會在後面存入原來的數值
    sw x3,  12(sp)  # gp
    sw x4,  16(sp)  # tp
    # sw x5,  20(sp)  # t0
    sw x6,  24(sp)  # t1
    sw x7,  28(sp)  # t2
    sw x8,  32(sp)  # s0/fp
    sw x9,  36(sp)  # s1
    sw x10, 40(sp)  # a0
    sw x11, 44(sp)  # a1
    sw x12, 48(sp)  # a2
    sw x13, 52(sp)  # a3
    sw x14, 56(sp)  # a4
    sw x15, 60(sp)  # a5
    sw x16, 64(sp)  # a6
    sw x17, 68(sp)  # a7
    sw x18, 72(sp)  # s2
    sw x19, 76(sp)  # s3
    sw x20, 80(sp)  # s4
    sw x21, 84(sp)  # s5
    sw x22, 88(sp)  # s6
    sw x23, 92(sp)  # s7
    sw x24, 96(sp)  # s8
    sw x25, 100(sp) # s9
    sw x26, 104(sp) # s10
    sw x27, 108(sp) # s11
    sw x28, 112(sp) # t3
    sw x29, 116(sp) # t4
    sw x30, 120(sp) # t5
    sw x31, 124(sp) # t6

    # 3. 特殊處理：存入「進入中斷前」的原始 sp 值
    addi t0, sp, 128
    sw t0, 8(sp)

    # 4. 讀取 CSR 資訊，準備傳給 C 語言 
    csrr a0, mcause   # 第一個參數：cause 
    csrr a1, mepc     # 第二個參數：epc 
    mv   a2, sp       # 第三個參數：指向這 128 bytes 存檔的指標 (Context)

    # 5. 呼叫 C 語言處理器
    jal ra, handle_exception

    # 🏆 這裡就是多工切換的秘密：
    # 如果 handle_exception 修改了 a2 並返回，我們就會從另一個任務的堆疊還原！
    mv sp, a0

    # 🏆 從新任務的堆疊還原它上次停下的 PC
    lw t0, 0(sp)
    csrw mepc, t0    

    # 6. 從堆疊還原所有暫存器
    lw x1,  4(sp)
    # x2 (sp) 透過最後的 addi 還原
    lw x3,  12(sp)
    lw x4,  16(sp)
    lw x5,  20(sp)
    lw x6,  24(sp)
    lw x7,  28(sp)
    lw x8,  32(sp)
    lw x9,  36(sp)
    lw x10, 40(sp)
    lw x11, 44(sp)
    lw x12, 48(sp)
    lw x13, 52(sp)
    lw x14, 56(sp)
    lw x15, 60(sp)
    lw x16, 64(sp)
    lw x17, 68(sp)
    lw x18, 72(sp)
    lw x19, 76(sp)
    lw x20, 80(sp)
    lw x21, 84(sp)
    lw x22, 88(sp)
    lw x23, 92(sp)
    lw x24, 96(sp)
    lw x25, 100(sp)
    lw x26, 104(sp)
    lw x27, 108(sp)
    lw x28, 112(sp)
    lw x29, 116(sp)
    lw x30, 120(sp)
    lw x31, 124(sp)

    # 7. 釋放堆疊空間並返回
    addi sp, sp, 128
    mret
    