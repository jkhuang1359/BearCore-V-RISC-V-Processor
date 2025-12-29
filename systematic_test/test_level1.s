.text
.globl _start
_start:
    # 測試PC遞增：執行5條nop指令
    nop      # 0x00000013
    nop      # 0x00000013  
    nop      # 0x00000013
    nop      # 0x00000013
    nop      # 0x00000013
    
    # 然後無限循環
end:
    j end    # 0x0000006f
