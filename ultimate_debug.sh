#!/bin/bash

echo "================================================================"
echo "BearCore-V 終極調試"
echo "================================================================"

# 1. 檢查所有必要文件
echo "1. 檢查文件..."
REQUIRED_FILES=(
    "src/core.v"
    "src/alu.v"
    "src/decoder.v"
    "src/reg_file.v"
    "src/rom.v"
    "src/data_ram.v"
    "src/uart_tx.v"
    "src/csr_registers.v"
    "tb/testbench.v"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file 缺失"
        exit 1
    fi
done

# 2. 創建最簡單的測試程序
echo ""
echo "2. 創建測試程序..."
cat > test.s << 'ASMEOF'
.global _start
_start:
    # lui t0, 0x10000
    .word 0x100002b7
    
    # li t1, '!'
    .word 0x02100313
    
    # sw t1, 0(t0)
    .word 0x0062a023
    
    # 死循環
    # j .
    .word 0x0000006f
ASMEOF

# 3. 手動編譯（避免工具鏈問題）
echo ""
echo "3. 手動創建 hex 文件..."
# 直接寫入二進制值
cat > firmware.hex << 'HEXEOF'
100002b7
02100313
0062a023
0000006f
HEXEOF

echo "firmware.hex 內容:"
cat firmware.hex

# 4. 編譯仿真
echo ""
echo "4. 編譯仿真..."
iverilog -o wave.vvp -f files.f -I src -g2012 -Wall 2>iverilog.log

if [ $? -ne 0 ]; then
    echo "❌ 編譯失敗:"
    cat iverilog.log
    exit 1
fi

echo "✅ 編譯成功"

# 5. 運行仿真
echo ""
echo "5. 運行仿真..."
echo "如果一切正常，應該輸出 '!'"
echo ""

vvp wave.vvp 2>&1 | tee vvp.log

echo ""
echo "6. 分析結果..."

# 檢查是否有波形
if [ -f "cpu.vcd" ]; then
    echo "✅ 波形文件: cpu.vcd (大小: $(wc -c < cpu.vcd) bytes)"
else
    echo "❌ 無波形文件"
fi

# 檢查輸出
if grep -q "!" vvp.log; then
    echo "✅ 檢測到 UART 輸出 '!'"
    echo ""
    echo "🎉 恭喜！CPU 工作正常！"
    exit 0
else
    echo "❌ 未檢測到 UART 輸出"
    echo ""
    echo "仿真日誌摘要:"
    echo "--------------"
    tail -30 vvp.log
    exit 1
fi