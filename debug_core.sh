#!/bin/bash
# BearCore-V 手動調試腳本

echo "===================================================================="
echo "BearCore-V 硬體調試"
echo "===================================================================="

# 清理舊文件
rm -f wave.vvp cpu.vcd firmware.hex

# 使用調試測試
TEST_NAME="debug_test"
TEST_DIR="hw_tests/phase0"

echo "1. 編譯測試程序: $TEST_NAME"
cd $TEST_DIR

# 編譯測試程序
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -g \
    -T link.ld -o ${TEST_NAME}.elf ${TEST_NAME}.s

# 檢查編譯結果
if [ $? -ne 0 ]; then
    echo "❌ 編譯失敗"
    exit 1
fi

echo "✅ 編譯成功"

# 生成 hex 文件
echo "2. 生成 hex 文件..."
riscv64-unknown-elf-objcopy -O binary ${TEST_NAME}.elf ${TEST_NAME}.bin
od -An -tx4 -w4 -v ${TEST_NAME}.bin > ${TEST_NAME}.hex

# 顯示 hex 文件內容
echo "Hex 文件內容（前20行）:"
head -20 ${TEST_NAME}.hex

# 顯示反彙編
echo ""
echo "反彙編（前10條指令）:"
riscv64-unknown-elf-objdump -d ${TEST_NAME}.elf | head -30

# 複製到根目錄
cd ../..
cp ${TEST_DIR}/${TEST_NAME}.hex firmware.hex

# 編譯仿真
echo ""
echo "3. 編譯仿真..."
iverilog -o wave.vvp -f files.f -I src 2>&1 | tee compile.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "❌ 仿真編譯失敗"
    echo "編譯錯誤:"
    cat compile.log
    exit 1
fi

echo "✅ 仿真編譯成功"

# 運行仿真
echo ""
echo "4. 運行仿真（10,000 週期）..."
echo "期望輸出: 字符 'X' 和換行"
echo ""

vvp wave.vvp 2>&1 | tee sim.log

echo ""
echo "5. 仿真完成"
echo "查看波形文件: gtkwave cpu.vcd"
echo "查看完整日誌: less sim.log"