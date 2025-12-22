
.section .text
.global _start

_start:
    # 初始化UART地址
    lui a5, 0x10000        # UART基地址 0x10000000
    
    # 測試1：JAL (無條件跳轉)
    li a4, 0x31            # '1' - 測試開始標誌
    sw a4, 0(a5)
    
    jal x1, test_jal       # 跳轉到test_jal，返回地址保存到x1
    
jal_back:
    # 測試2：JALR (寄存器跳轉)
    li a4, 0x34            # '4' - 進入JALR測試
    sw a4, 0(a5)
    
    la x2, test_jalr       # 載入test_jalr地址到x2
    jalr x3, x2, 0         # 跳轉到x2指向的地址
    
jalr_back:
    # 測試3：BEQ (相等時分支)
    li a4, 0x37            # '7' - 進入BEQ測試
    sw a4, 0(a5)
    
    li a0, 10
    li a1, 10
    beq a0, a1, test_beq
    
    # 不應該執行到這裡
    li a4, 0x46            # 'F' - 失敗
    sw a4, 0(a5)
    j end_test

test_beq:
    # 測試4：BNE (不相等時分支)
    li a4, 0x41            # 'A' - BEQ通過，進入BNE測試
    sw a4, 0(a5)
    
    li a0, 10
    li a1, 20
    bne a0, a1, test_bne
    
    # 不應該執行到這裡
    li a4, 0x46            # 'F' - 失敗
    sw a4, 0(a5)
    j end_test

test_bne:
    # 測試5：BLT (小於時分支)
    li a4, 0x44            # 'D' - BNE通過，進入BLT測試
    sw a4, 0(a5)
    
    li a0, 5
    li a1, 10
    blt a0, a1, test_blt
    
    # 不應該執行到這裡
    li a4, 0x46            # 'F' - 失敗
    sw a4, 0(a5)
    j end_test

test_blt:
    # 測試6：反向測試 (分支不應發生)
    li a4, 0x47            # 'G' - BLT通過
    sw a4, 0(a5)
    
    li a0, 15
    li a1, 10
    blt a0, a1, fail_test  # 不應分支
    
    # 應該執行到這裡
    li a4, 0x48            # 'H' - 成功
    sw a4, 0(a5)
    
    # 最終輸出換行
    li a4, 0x0A
    sw a4, 0(a5)
    
    j end_test

# 測試子程式
test_jal:
    li a4, 0x32            # '2' - JAL跳轉成功
    sw a4, 0(a5)
    jal x4, jal_sub        # 嵌套跳轉
    
jal_sub_back:
    li a4, 0x33            # '3' - 嵌套跳轉返回
    sw a4, 0(a5)
    jalr x0, x1, 0         # 返回主程式

jal_sub:
    li a4, 0x61            # 'a' - 嵌套子程式
    sw a4, 0(a5)
    jalr x0, x4, 0         # 返回

test_jalr:
    li a4, 0x35            # '5' - JALR跳轉成功
    sw a4, 0(a5)
    
    # 計算返回地址
    addi x4, x3, 8         # x3是返回地址，+8跳過下面的指令
    li a4, 0x36            # '6' - 準備返回
    sw a4, 0(a5)
    jalr x0, x4, 0         # 返回
    
    # 不應該執行到這裡
    li a4, 0x45            # 'E' - 錯誤
    sw a4, 0(a5)

fail_test:
    li a4, 0x46            # 'F' - 失敗標誌
    sw a4, 0(a5)

end_test:
    # 測試完成，進入無限循環
    li a4, 0x5A            # 'Z' - 測試結束
    sw a4, 0(a5)
    
    # 輸出換行
    li a4, 0x0A
    sw a4, 0(a5)
    
    # 正確的無限循環
    j end_test
