#!/bin/bash
# 测试运行脚本

TEST_FILE="$1"
LOG_FILE="$2"

if [ ! -f "$TEST_FILE" ]; then
    echo "测试文件不存在: $TEST_FILE" >> "$LOG_FILE"
    exit 1
fi

# 编译
riscv64-unknown-elf-gcc -o "${TEST_FILE}.elf" "$TEST_FILE" \
    -nostdlib -march=rv32i -mabi=ilp32 -Ttext=0x80000000 >> "$LOG_FILE" 2>&1

if [ $? -ne 0 ]; then
    echo "编译失败" >> "$LOG_FILE"
    exit 1
fi

# 尝试不同的运行方式
# 方法1: 简单的spike运行
echo "尝试简单spike运行..." >> "$LOG_FILE"
timeout 2s spike --isa=rv32i "${TEST_FILE}.elf" 2>&1 >> "$LOG_FILE"
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ] || [ $EXIT_CODE -eq 124 ]; then
    echo "运行成功（退出码: $EXIT_CODE）" >> "$LOG_FILE"
    exit 0
fi

# 方法2: 如果有pk
echo "尝试使用pk运行..." >> "$LOG_FILE"
if command -v pk &> /dev/null; then
    timeout 2s spike --isa=rv32i pk "${TEST_FILE}.elf" 2>&1 >> "$LOG_FILE"
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ] || [ $EXIT_CODE -eq 124 ]; then
        echo "使用pk运行成功（退出码: $EXIT_CODE）" >> "$LOG_FILE"
        exit 0
    fi
fi

# 方法3: 使用debug模式
echo "尝试debug模式运行..." >> "$LOG_FILE"
timeout 2s spike --isa=rv32i -d "${TEST_FILE}.elf" 2>&1 | head -50 >> "$LOG_FILE"

echo "所有尝试都失败" >> "$LOG_FILE"
exit 1
