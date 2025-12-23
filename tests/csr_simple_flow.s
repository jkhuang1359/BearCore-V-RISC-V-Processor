# tests/csr_simple_flow.s
.section .text.init
.global _start

_start:
    li t0, 0x10000000  # UART 地址
    
    # 輸出 'S' 表示開始
    li t1, 'S'
    sw t1, 0(t0)
    
    # 設置堆疊
    li sp, 0x8000
    
    # 1. 首先將值加載到 a1
    li a1, 0x12345678
    
    # 2. 立即使用 a1 進行 CSR 寫入
    csrw 0x340, a1
    
    # 3. 輸出結果標記
    li t1, 'D'
    sw t1, 0(t0)
    
    # 4. 讀取並檢查
    csrr a2, 0x340
    
    # 5. 比較並輸出
    beq a1, a2, pass
    li t1, 'F'
    sw t1, 0(t0)
    j end
    
pass:
    li t1, 'P'
    sw t1, 0(t0)
    
end:
    li t1, '\n'
    sw t1, 0(t0)
    j end
    