echo "=== 修復 CSR 數據前推和分支問題 ==="

# 1. 首先檢查當前 core.v 文件
if [ ! -f src/core.v.backup.original ]; then
    cp src/core.v src/core.v.backup.original
fi

# 2. 創建修正版 core.v
cat > /tmp/fixed_core.v << 'EOF'
// 我們需要修正的核心問題：
// 1. CSR讀取數據需要正確前推到分支指令
// 2. 確保分支指令使用正確的數據

// 在 core.v 中，我們需要修改前推邏輯，特別是對於 CSR 讀取指令
EOF

# 3. 讓我們先查看當前的數據前推邏輯
echo "檢查當前的數據前推邏輯..."
grep -n "fwd_rs1\|fwd_rs2" src/core.v | head -20

# 4. 問題：當 CSR 讀取指令在 MEM 階段時，它的結果（csr_rdata）應該可以前推到 EX 階段
#    但當前的前推邏輯只前推 mem_alu_result，沒有前推 csr_rdata
# 解決方案：修改前推邏輯，當 mem_is_csr 為真時，使用 csr_rdata 而不是 mem_alu_result

# 5. 創建修復的 core.v
cp src/core.v src/core.v.backup.before_fix

# 6. 修改前推邏輯
echo "修改前推邏輯以支持 CSR 數據前推..."

# 找到 fwd_rs1 的定義並修改
sed -i 's/wire \[31:0\] fwd_rs1 = (mem_reg_wen && mem_rd_addr != 0 && mem_rd_addr == ex_rs1_addr) ? mem_alu_result :/wire [31:0] fwd_rs1 = \
    (mem_reg_wen && mem_rd_addr != 0 && mem_rd_addr == ex_rs1_addr) ? \
        (mem_is_csr ? csr_rdata : mem_alu_result) :/' src/core.v

# 同樣修改 fwd_rs2
sed -i 's/wire \[31:0\] fwd_rs2 = (mem_reg_wen && mem_rd_addr != 0 && mem_rd_addr == ex_rs2_addr) ? mem_alu_result :/wire [31:0] fwd_rs2 = \
    (mem_reg_wen && mem_rd_addr != 0 && mem_rd_addr == ex_rs2_addr) ? \
        (mem_is_csr ? csr_rdata : mem_alu_result) :/' src/core.v

# 7. 添加調試信息來驗證修復
echo "添加調試信息..."
cat >> src/core.v << 'EOF'

// ========== 數據流調試 ==========
always @(posedge clk) begin
    // 追蹤 CSR 讀取和寄存器寫入
    if (mem_is_csr && mem_reg_wen) begin
        $display("[CSR-READ-MEM] CSR[0x%h] -> x%0d = 0x%h (will write at WB)", 
                mem_csr_addr, mem_rd_addr, csr_rdata);
    end
    
    if (wb_is_csr && wb_reg_wen) begin
        $display("[CSR-READ-WB] CSR[0x%h] -> x%0d = 0x%h (writing now)", 
                wb_csr_addr, wb_rd_addr, wb_write_data);
    end
    
    // 追蹤分支指令
    if (ex_is_branch) begin
        $display("[BRANCH-EX] PC=0x%h, type=%b, rs1=0x%h, rs2=0x%h, zero=%b, taken=%b", 
                ex_pc, ex_funct3, alu_in_a_final, ex_alu_in_b, ex_alu_zero, ex_take_branch);
        $display("  rs1_addr=%d, rs2_addr=%d, fwd_rs1=0x%h, fwd_rs2=0x%h",
                ex_rs1_addr, ex_rs2_addr, fwd_rs1, fwd_rs2);
    end
    
    // 追蹤數據前推
    if (ex_is_csr || ex_is_branch) begin
        if (mem_reg_wen && mem_rd_addr != 0) begin
            $display("[FWD-INFO] MEM stage writing to x%0d = 0x%h, is_csr=%b",
                    mem_rd_addr, mem_is_csr ? csr_rdata : mem_alu_result, mem_is_csr);
        end
        if (wb_reg_wen && wb_rd_addr != 0) begin
            $display("[FWD-INFO] WB stage writing to x%0d = 0x%h",
                    wb_rd_addr, wb_write_data);
        end
    end
end
EOF

# 8. 創建一個更簡單的測試來驗證修復
echo "創建驗證測試..."
cat > tests/verify_fix.s << 'EOF'
.section .text.init
.global _start

_start:
    li t0, 0x10000000  # UART地址
    
    # 開始標記
    li t1, 'S'
    sw t1, 0(t0)
    
    # 測試1: 直接比較（不涉及CSR）
    li a1, 0x12345678
    li a2, 0x12345678
    
    nop
    nop
    
    # 結果標記1
    li t1, 'R'
    sw t1, 0(t0)
    
    # 比較
    beq a1, a2, test1_pass
    
test1_fail:
    li t1, '1'
    sw t1, 0(t0)
    li t1, 'F'
    sw t1, 0(t0)
    j test2
    
test1_pass:
    li t1, '1'
    sw t1, 0(t0)
    li t1, 'P'
    sw t1, 0(t0)
    
test2:
    # 測試2: CSR寫入和讀取
    li a1, 0x12345678
    
    # 寫入CSR
    csrw mscratch, a1
    
    # 讀取CSR
    csrr a2, mscratch
    
    nop
    nop
    
    # 結果標記2
    li t1, 'C'
    sw t1, 0(t0)
    
    # 比較
    beq a1, a2, test2_pass
    
test2_fail:
    li t1, '2'
    sw t1, 0(t0)
    li t1, 'F'
    sw t1, 0(t0)
    j end
    
test2_pass:
    li t1, '2'
    sw t1, 0(t0)
    li t1, 'P'
    sw t1, 0(t0)
    
end:
    li t1, '\n'
    sw t1, 0(t0)
    j end
EOF

# 9. 重新編譯和測試
echo "重新編譯..."
make clean
riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles \
    -ffreestanding -T link.ld tests/verify_fix.s -o firmware.elf
riscv64-unknown-elf-objcopy -O binary firmware.elf firmware.bin
od -An -t x4 -w4 -v firmware.bin | tr -d ' ' > firmware.hex

echo "運行測試..."
echo "========================================"
iverilog -g2012 -o wave.vvp -f files.f && vvp wave.vvp 2>&1 | grep -E "UART TX:|BRANCH-EX|CSR-READ|FWD-INFO" | head -50
echo "========================================"

echo "預期 UART 輸出: SR1P C2P"
echo "如果看到 '1F' 或 '2F' 表示對應測試失敗"
echo "修復完成！"