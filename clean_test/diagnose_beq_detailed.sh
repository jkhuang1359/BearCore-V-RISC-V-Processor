echo "=== BEQ指令詳細診斷 ==="

# 創建測試程序
cat > firmware.hex << 'EOF'
00100093  # addi x1, x0, 1
00100113  # addi x2, x0, 1
00008063  # beq x1, x2, 0
00300093  # addi x1, x0, 3
00500113  # addi x2, x0, 5
EOF

echo "測試程序已創建"
echo "編譯..."
iverilog -g2012 -Wall -o beq_detailed.vvp tb_debug.v alu.v decoder.v reg_file.v rom.v data_ram.v csr_registers.v uart_tx.v core.v

echo "運行仿真..."
vvp beq_detailed.vvp

# 分析結果
echo -e "\n=== 分析結果 ==="
echo "如果BEQ正確跳轉，x1應該保持為1，x2應該為5"
echo "如果BEQ沒有跳轉，x1應該變為3，x2應該為5"