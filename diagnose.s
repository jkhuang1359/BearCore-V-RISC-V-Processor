.text
.globl _start
_start:
    # 地址0x00: nop
    nop
    
    # 地址0x04: nop
    nop
    
    # 地址0x08: nop
    nop
    
    # 地址0x0c: nop
    nop
    
    # 地址0x10: nop
    nop
    
    # 地址0x14: jal x0, -4 (跳轉回0x10)
    # 編碼: 0xffdff06f
    # 實際使用簡單的j end
end:
    j end
