.section .text.init
.globl _start
.align 2

_start:
    # 1. 初始化堆疊
    li sp, 0x0001F000
    
    # 2. 清除 sscratch (良好習慣)
    csrw sscratch, x0
    
    # 3. 設定中斷向量
    la t0, exception_entry
    csrw mtvec, t0
    
    # 4. 準備 Status (Machine Mode)
    li t0, 0x1800
    csrw mstatus, t0
    
    # 5. 進入 main
    jal ra, main

    # 死循環防護
1:  j 1b

# --- 例外向量表區段 ---
.section .text.vec
.align 2
.global exception_entry

exception_entry:
    # =========================================================
    # 🐻 關鍵修正：加入 NOP 防止 Pipeline Hazard
    # 如果 addi sp 的結果來不及 Forward 給 sw，sw 會寫錯位置導致崩潰
    # =========================================================
    addi sp, sp, -128
    nop
    nop
    nop
    
    # 保存關鍵暫存器
    sw ra, 0(sp)     # [重要] 這是被中斷函式的返回地址
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    sw a0, 16(sp)
    sw a1, 20(sp)
    sw a2, 24(sp)
    sw a3, 28(sp)
    sw a4, 32(sp)
    sw a5, 36(sp)
    sw a6, 40(sp)
    sw a7, 44(sp)
    sw t3, 48(sp)
    sw t4, 52(sp)
    sw t5, 56(sp)
    sw t6, 60(sp)
    sw s0, 64(sp)
    sw s1, 68(sp)
    sw s2, 72(sp)
    sw s3, 76(sp)
    sw s4, 80(sp)
    sw s5, 84(sp)
    sw s6, 88(sp)
    sw s7, 92(sp)
    sw s8, 96(sp)
    sw s9, 100(sp)
    sw s10, 104(sp)
    sw s11, 108(sp)
    sw gp, 112(sp)
    sw tp, 116(sp)
    
    # 保存 mepc 和 mcause
    csrr t0, mepc
    sw t0, 120(sp)
    csrr t0, mcause
    sw t0, 124(sp)
    
    # 設置 C 函數參數
    lw a0, 124(sp)   # cause
    lw a1, 120(sp)   # epc
    mv a2, sp        # sp context
    
    # 調用 C 處理函數
    jal ra, handle_exception
    
    # 恢復 mepc
    lw t0, 120(sp)
    csrw mepc, t0
    
    # 恢復暫存器
    lw ra, 0(sp)     # [重要] 恢復 RA
    
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw a0, 16(sp)
    lw a1, 20(sp)
    lw a2, 24(sp)
    lw a3, 28(sp)
    lw a4, 32(sp)
    lw a5, 36(sp)
    lw a6, 40(sp)
    lw a7, 44(sp)
    lw t3, 48(sp)
    lw t4, 52(sp)
    lw t5, 56(sp)
    lw t6, 60(sp)
    lw s0, 64(sp)
    lw s1, 68(sp)
    lw s2, 72(sp)
    lw s3, 76(sp)
    lw s4, 80(sp)
    lw s5, 84(sp)
    lw s6, 88(sp)
    lw s7, 92(sp)
    lw s8, 96(sp)
    lw s9, 100(sp)
    lw s10, 104(sp)
    lw s11, 108(sp)
    lw gp, 112(sp)
    lw tp, 116(sp)
    
    # 釋放堆疊 (這裡也加 NOP 保險)
    addi sp, sp, 128
    nop
    nop
    
    # 中斷返回
    mret
    
.global test_asm_only
test_asm_only:
    li t0, 0x00018000
    sw ra, 0(t0)
    nop
    addi x0, x0, 0
    sw ra, 4(t0)
    lw ra, 0(t0)
    ret
    