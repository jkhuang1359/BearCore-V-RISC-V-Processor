echo "=== 正確的BEQ測試 ==="

# 創建正確的測試程序
cat > firmware.hex << 'EOF'
00100093  # addi x1, x0, 1
00100113  # addi x2, x0, 1
00000013  # nop
00000013  # nop
00208063  # beq x1, x2, 0 (應該跳轉)
00300093  # addi x1, x0, 3 (應該被跳過)
00500113  # addi x2, x0, 5
EOF

echo "測試程序:"
cat firmware.hex

echo -e "\n編譯..."
iverilog -g2012 -Wall -o beq_correct.vvp tb_debug.v alu.v decoder.v reg_file.v rom.v data_ram.v csr_registers.v uart_tx.v core.v

echo -e "\n運行仿真..."
vvp beq_correct.vvp

echo -e "\n檢查結果..."
if [ -f "debug.vcd" ]; then
    echo "波形文件: debug.vcd"
    echo "使用 gtkwave debug.vcd 查看波形"
fi