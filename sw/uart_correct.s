.section .text
.globl _start
_start:
    # --- 設置 UART 寄存器地址 ---
    # 注意：必須遵守硬體規範，使用 polling 機制
    li s0, 0x10000000      # UART 數據寄存器 (只寫)
    li s1, 0x10000004      # UART 狀態寄存器 (可讀，bit 0 = busy 標誌)
    
    # --- 發送字符序列：ABC ---
    # 每個字符發送前都檢查 busy 狀態
    
    # 發送 'A' (0x41)
    li a0, 0x41
    jal ra, uart_send
    
    # 發送 'B' (0x42)
    li a0, 0x42
    jal ra, uart_send
    
    # 發送 'C' (0x43)
    li a0, 0x43
    jal ra, uart_send
    
    # --- 結束：無限循環 ---
end_loop:
    j end_loop

# ========================================
# UART 發送函數（符合規範）
# 輸入: a0 - 要發送的字符 (8位)
# 使用: s0 - 數據寄存器地址, s1 - 狀態寄存器地址
# 規範: 必須檢查 busy 狀態，只有 idle 時才能寫入
# ========================================
uart_send:
    # 保存返回地址
    addi sp, sp, -4
    sw ra, 0(sp)
    
    # 保存字符到臨時寄存器
    mv t0, a0
    
    # --- POLLING 循環：等待 UART 空閒 ---
    # 規範要求：必須讀取 0x10000004 的 bit 0
    # bit 0 = 1: UART 忙，不能發送
    # bit 0 = 0: UART 空閒，可以發送
uart_poll:
    lw t1, 0(s1)           # 讀取狀態寄存器 (0x10000004)
    andi t1, t1, 1         # 提取 bit 0 (busy 標誌)
    bnez t1, uart_poll     # 如果 busy != 0，繼續等待
    
    # --- 發送字符 ---
    # 此時 UART 確認為空閒狀態
    sw t0, 0(s0)           # 寫入數據寄存器 (0x10000000)
    
    # --- 函數返回 ---
    lw ra, 0(sp)
    addi sp, sp, 4
    ret
