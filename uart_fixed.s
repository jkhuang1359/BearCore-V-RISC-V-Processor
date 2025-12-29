.section .text
.globl _start
_start:
    # --- 初始化堆疊指針 ---
    li sp, 0x10000          # 重要：設置有效的堆疊指針！
    
    # --- 設置UART寄存器地址 ---
    li s0, 0x10000000      # UART數據寄存器
    li s1, 0x10000004      # UART狀態寄存器
    
    # --- 發送字符序列：ABC ---
    li a0, 0x41            # 'A'
    jal ra, uart_send
    
    li a0, 0x42            # 'B'
    jal ra, uart_send
    
    li a0, 0x43            # 'C'
    jal ra, uart_send
    
    # --- 結束：無限循環 ---
end_loop:
    j end_loop

# ========================================
# UART發送函數（修正版）
# 輸入: a0 - 要發送的字符
# 使用: s0, s1, t0, t1, t2
# ========================================
uart_send:
    # 保存返回地址到臨時寄存器t2（避免堆疊問題）
    mv t2, ra
    
    # 保存字符
    mv t0, a0
    
    # Polling循環：等待UART空閒
poll_loop:
    lw t1, 0(s1)           # 讀取狀態寄存器
    andi t1, t1, 1         # 檢查busy標誌
    bnez t1, poll_loop     # 如果忙，繼續等待
    
    # 發送字符
    sw t0, 0(s0)
    
    # 恢復返回地址並返回
    jr t2
