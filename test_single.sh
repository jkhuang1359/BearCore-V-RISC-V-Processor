#!/bin/bash
# 測試單個程序

if [ -z "$1" ]; then
    echo "使用方法: $0 <測試名稱>"
    echo "可用測試: minimal_test, alu_comprehensive, control_flow, memory_test, csr_test"
    exit 1
fi

TEST_NAME=$1
TEST_DIR="hw_tests/phase0"
LOG_DIR="logs"

echo "測試: $TEST_NAME"
echo "================================"

# 1. 編譯測試程序
echo "1. 編譯測試程序..."
cd $TEST_DIR

# 編譯
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -g \
    -T link.ld -o ${TEST_NAME}.elf ${TEST_NAME}.s

# 生成二進制和hex
riscv64-unknown-elf-objcopy -O binary ${TEST_NAME}.elf ${TEST_NAME}.bin
od -An -tx4 -w4 -v ${TEST_NAME}.bin > ${TEST_NAME}.hex

# 反彙編
riscv64-unknown-elf-objdump -d ${TEST_NAME}.elf > ${TEST_NAME}.disasm

echo "✅ 編譯完成"

# 2. 複製 hex 文件到項目根目錄
cd ../..
cp ${TEST_DIR}/${TEST_NAME}.hex firmware.hex

# 3. 檢查 hex 文件
echo "2. 檢查 hex 文件..."
head -5 firmware.hex
echo "..."

# 4. 編譯仿真
echo "3. 編譯仿真..."
iverilog -o wave.vvp -f files.f -I src 2>&1 | tee ${LOG_DIR}/${TEST_NAME}_compile.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "❌ 仿真編譯失敗"
    exit 1
fi

echo "✅ 仿真編譯成功"

# 5. 運行仿真
echo "4. 運行仿真..."
vvp wave.vvp +testname=${TEST_NAME} 2>&1 | tee ${LOG_DIR}/${TEST_NAME}_sim.log

# 6. 檢查結果
echo "5. 檢查結果..."
if grep -q "✅ 测试通过" ${LOG_DIR}/${TEST_NAME}_sim.log; then
    echo "🎉 $TEST_NAME: 測試通過！"
    exit 0
elif grep -q "❌ 测试失败" ${LOG_DIR}/${TEST_NAME}_sim.log; then
    echo "❌ $TEST_NAME: 測試失敗"
    exit 1
else
    echo "⚠️  $TEST_NAME: 結果不確定"
    
    # 顯示 UART 輸出
    echo "UART 輸出:"
    grep -A5 "接收到的字符" ${LOG_DIR}/${TEST_NAME}_sim.log || true
    
    exit 2
fi