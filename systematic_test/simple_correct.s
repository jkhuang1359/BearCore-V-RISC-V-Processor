.text
.globl _start
_start:
    # 簡單測試：5條nop + 無限循環
    nop                 # 0x00000013
    nop                 # 0x00000013
    nop                 # 0x00000013  
    nop                 # 0x00000013
    nop                 # 0x00000013
end:
    j end               # 0x0000006f
