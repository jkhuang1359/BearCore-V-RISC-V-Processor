echo "=== 修復所有問題：UART busy檢查和CSR數據前推 ==="

# 1. 首先修復 core.v 中的CSR數據前推問題
echo "修復CSR數據前推..."
cp src/core.v src/core.v.backup.before_all_fixes

# 找到並修正 fwd_rs1 和 fwd_rs2 的定義
sed -i 's/wire \[31:0\] fwd_rs1 = (mem_reg_wen && mem_rd_addr != 0 && mem_rd_addr == ex_rs1_addr) ? mem_alu_result :/wire [31:0] fwd_rs1 = (mem_reg_wen \&\& mem_rd_addr != 0 \&\& mem_rd_addr == ex_rs1_addr) ? (mem_is_csr ? csr_rdata : mem_alu_result) :/' src/core.v

sed -i 's/wire \[31:0\] fwd_rs2 = (mem_reg_wen && mem_rd_addr != 0 && mem_rd_addr == ex_rs2_addr) ? mem_uart_busy :/wire [31:0] fwd_rs2 = (mem_reg_wen \&\& mem_rd_addr != 0 \&\& mem_rd_addr == ex_rs2_addr) ? (mem_is_csr ? csr_rdata : mem_alu_result) :/' src/core.v

# 2. 創建一個正確檢查UART busy的測試程序
echo "創建正確的UART測試程序..."
cat > tests/final_working_test.s << 'EOF'
.section .text.init
.global _start

_start:
    # 設置UART地址
    li t0, 0x10000000  # UART數據寄存器
    li t5, 0x10000004  # UART狀態寄存器（bit 0 = busy）
    
    # ========== 測試1: UART基本功能 ==========
    # 等待UART空閒，然後發送'S'
uart_wait1:
    lw t1, 0(t5)        # 讀取狀態寄存器
    andi t1, t1, 1      # 檢查busy位
    bnez t1, uart_wait1 # 如果busy=1，繼續等待
    li t2, 'S'
    sw t2, 0(t0)        # 發送字符
    
    # ========== 測試2: 寄存器比較測試 ==========
    li a1, 0x12345678
    li a2, 0x12345678
    
    # 插入nop確保數據可用
    nop
    nop
    nop
    
    # 比較
    beq a1, a2, test_reg_pass
    
test_reg_fail:
    # 等待UART空閒，發送'F'
uart_wait2:
    lw t1, 0(t5)
    andi t1, t1, 1
    bnez t1, uart_wait2
    li t2, 'F'
    sw t2, 0(t0)
    j end_test
    
test_reg_pass:
    # 等待UART空閒，發送'P'
uart_wait3:
    lw t1, 0(t5)
    andi t1, t1, 1
    bnez t1, uart_wait3
    li t2, 'P'
    sw t2, 0(t0)
    
    # ========== 測試3: CSR功能測試 ==========
    li a1, 0x12345678
    
    # 寫入CSR
    csrw mscratch, a1
    
    # 等待幾個周期讓CSR寫入完成
    nop
    nop
    nop
    
    # 讀取CSR
    csrr a2, mscratch
    
    # 等待幾個周期讓CSR讀取完成
    nop
    nop
    
    # 比較
    beq a1, a2, test_csr_pass
    
test_csr_fail:
    # 等待UART空閒，發送'F'
uart_wait4:
    lw t1, 0(t5)
    andi t1, t1, 1
    bnez t1, uart_wait4
    li t2, 'F'
    sw t2, 0(t0)
    j end_test
    
test_csr_pass:
    # 等待UART空閒，發送'P'
uart_wait5:
    lw t1, 0(t5)
    andi t1, t1, 1
    bnez t1, uart_wait5
    li t2, 'P'
    sw t2, 0(t0)
    
    # ========== 測試4: 最終標記 ==========
uart_wait6:
    lw t1, 0(t5)
    andi t1, t1, 1
    bnez t1, uart_wait6
    li t2, '!'
    sw t2, 0(t0)
    
end_test:
    # 發送換行符
uart_wait7:
    lw t1, 0(t5)
    andi t1, t1, 1
    bnez t1, uart_wait7
    li t2, '\n'
    sw t2, 0(t0)
    
    # 無限循環
end_loop:
    j end_loop
EOF

# 3. 確保CSR寫使能邏輯正確
echo "確保CSR寫使能邏輯正確..."
cat > /tmp/csr_we_fix.v << 'EOF'
    // CSR寫使能邏輯修正
    // CSRRW/CSRRWI (op=00): 總是寫入
    // CSRRS/CSRRSI (op=01): 當rs1/imm != 0時寫入
    // CSRRC/CSRRCI (op=10): 當rs1/imm != 0時寫入
    wire csr_write_always = (mem_csr_op == 2'b00);
    wire csr_write_set    = (mem_csr_op == 2'b01) && (|csr_wdata);
    wire csr_write_clear  = (mem_csr_op == 2'b10) && (|csr_wdata);
    
    assign csr_we = mem_is_csr && (csr_write_always || csr_write_set || csr_write_clear);
EOF

# 找到csr_we的定義並替換
if grep -q "assign csr_we = mem_is_csr" src/core.v; then
    sed -i '/assign csr_we = mem_is_csr/,+1d' src/core.v
    # 在適當位置插入新的定義
    line_num=$(grep -n "assign csr_wdata = mem_csr_wdata;" src/core.v | head -1 | cut -d: -f1)
    if [ ! -z "$line_num" ]; then
        sed -i "${line_num}a\\
    // CSR寫使能邏輯修正\\
    // CSRRW/CSRRWI (op=00): 總是寫入\\
    // CSRRS/CSRRSI (op=01): 當rs1/imm != 0時寫入\\
    // CSRRC/CSRRCI (op=10): 當rs1/imm != 0時寫入\\
    wire csr_write_always = (mem_csr_op == 2'b00);\\
    wire csr_write_set    = (mem_csr_op == 2'b01) \&\& (|csr_wdata);\\
    wire csr_write_clear  = (mem_csr_op == 2'b10) \&\& (|csr_wdata);\\
    \\
    assign csr_we = mem_is_csr \&\& (csr_write_always || csr_write_set || csr_write_clear);" src/core.v
    fi
fi

# 4. 簡化調試輸出，只保留關鍵信息
echo "簡化調試輸出..."
# 移除可能導致格式問題的調試輸出
sed -i '/\[CSR-MEM-DEBUG\]/,+2d' src/core.v
sed -i '/\[CSR-FLOW-DEBUG\]/,+2d' src/core.v
sed -i '/\[FINAL-CSR-DEBUG\]/,+3d' src/core.v

# 添加簡潔的CSR調試
cat >> src/core.v << 'EOF'

    // ========== 簡潔的CSR和分支調試 ==========
    always @(posedge clk) begin
        // CSR寫入調試
        if (csr_we && mem_csr_addr == 12'h340) begin
            $display("[CSR-WRITE-FINAL] MSCRATCH = 0x%h", csr_wdata);
        end
        
        // 分支調試
        if (ex_is_branch) begin
            $display("[BRANCH] PC=0x%h, taken=%b, rs1=0x%h, rs2=0x%h", 
                    ex_pc, ex_take_branch, alu_in_a_final, ex_alu_in_b);
        end
        
        // CSR讀取調試
        if (wb_is_csr && wb_reg_wen) begin
            $display("[CSR-READ-FINAL] x%d = CSR[0x%h] = 0x%h", 
                    wb_rd_addr, wb_csr_addr, wb_write_data);
        end
    end
EOF

# 5. 重新編譯和測試
echo "重新編譯..."
make clean
riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles \
    -ffreestanding -T link.ld tests/final_working_test.s -o firmware.elf
riscv64-unknown-elf-objcopy -O binary firmware.elf firmware.bin
od -An -t x4 -w4 -v firmware.bin | tr -d ' ' > firmware.hex

echo "運行模擬測試..."
echo "========================================"
iverilog -g2012 -o wave.vvp -f files.f && vvp wave.vvp 2>&1 | tee full_simulation.log | grep -E "UART TX:|\[CSR-WRITE-FINAL\]|\[BRANCH\]|\[CSR-READ-FINAL\]|Simulation finished"
echo "========================================"

echo "查看UART輸出序列："
grep "UART TX:" full_simulation.log | cut -d' ' -f3 | tr -d '\n'
echo ""

echo "如果看到 'SPP!' 表示所有測試通過。"
echo "如果看到 'SF' 表示寄存器測試失敗。"
echo "如果看到 'SPF' 表示CSR測試失敗。"
echo "修復完成！"