.section .text.init
.global _start

_start:
    li t0, 0x10000000
    li t1, 'S'
    sw t1, 0(t0)
    
    li sp, 0x8000
    
    # 讀取 MISA
    csrr a0, 0x301
    li t1, 'M'
    sw t1, 0(t0)
    
    # 寫入 MSCRATCH
    li a1, 0x12345678
    csrw 0x340, a1
    li t1, 'W'
    sw t1, 0(t0)
    
    # 讀回 MSCRATCH
    csrr a2, 0x340
    li t1, 'R'
    sw t1, 0(t0)
    
    # 檢查
    beq a1, a2, passed
    li t1, 'F'
    sw t1, 0(t0)
    j end
    
passed:
    li t1, 'P'
    sw t1, 0(t0)
    
end:
    li t1, '\n'
    sw t1, 0(t0)
    j end
