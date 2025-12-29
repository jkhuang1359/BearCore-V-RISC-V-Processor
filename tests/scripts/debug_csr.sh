echo "=== CSR 調試診斷 ==="

# 1. 備份原始文件
cp src/core.v src/core.v.backup.$(date +%s)
cp src/csr_registers.v src/csr_registers.v.backup.$(date +%s)

# 2. 添加調試輸出到 core.v
sed -i '/ex_is_csr <= is_csr;/i\
        // 🐛 添加 CSR 指令調試\
        if (is_csr) begin\
            \$display("[CORE-DEBUG] ID stage: CSR instruction detected!");\
            \$display("  csr_addr = 0x%h, csr_op_type = %b", csr_addr, csr_op_type);\
        end' src/core.v

# 3. 添加調試輸出到 csr_registers.v
sed -i '/default: csr_rdata = 32'"'"'h0;/a\
        // 🐛 添加讀取調試\
        if (csr_addr == 12'"'"'h301 || csr_addr == 12'"'"'h340) begin\
            \$display("[CSR-DEBUG] Read: addr=0x%h, data=0x%h", csr_addr, csr_rdata);\
        end' src/csr_registers.v

sed -i '/if (csr_we) begin/a\
            \$display("[CSR-DEBUG] Write: addr=0x%h, data=0x%h, op=%b", csr_addr, write_val, csr_op);' src/csr_registers.v

# 4. 創建彙編測試
cat > csr_asm_test.s << 'EOF'
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
EOF

# 5. 編譯並測試
echo "編譯測試程式..."
riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles \
  -ffreestanding -T link.ld csr_asm_test.s -o firmware.elf

riscv64-unknown-elf-objcopy -O binary firmware.elf firmware.bin
od -An -t x4 -w4 -v firmware.bin | tr -d ' ' > firmware.hex

echo "運行模擬（顯示調試輸出）..."
echo "========================================"
iverilog -g2012 -o wave.vvp -f files.f && vvp wave.vvp
echo "========================================"

# 6. 恢復備份（可選）
echo -e "\n恢復原始文件？(y/N)"
read restore
if [ "$restore" = "y" ]; then
    cp src/core.v.backup.* src/core.v 2>/dev/null
    cp src/csr_registers.v.backup.* src/csr_registers.v 2>/dev/null
    echo "已恢復"
fi