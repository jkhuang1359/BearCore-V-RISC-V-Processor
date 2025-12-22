.section .text.init
.global _start

_start:
    # 簡單的跳轉測試
    j target
    
    # 這裡的代碼不應該執行
    lui a5, 0x10000
    li a4, 'E'  # Error標記
    sw a4, 0(a5)
    j end
    
target:
    lui a5, 0x10000
    li a4, 'O'  # OK標記
    sw a4, 0(a5)
    
end:
    j end  # 無限循環
