#!/bin/bash
echo "=== BearCore-V 性能基準測試 ==="

echo "1. 編譯時間基準..."
time make clean > /dev/null
time make ENABLE_FLOAT_TESTS=1 test-full > /dev/null 2>&1

echo -e "\n2. 程式大小比較..."
echo "配置            text    data     bss    總大小"
echo "----------------------------------------------"
make clean > /dev/null
make test-minimal 2>/dev/null | grep -E "firmware.elf|目前佔用"
make clean > /dev/null
make test-standard 2>/dev/null | grep -E "firmware.elf|目前佔用"
make clean > /dev/null
make test-full 2>/dev/null | grep -E "firmware.elf|目前佔用"
make clean > /dev/null
make ENABLE_FLOAT_TESTS=1 test-full 2>/dev/null | grep -E "firmware.elf|目前佔用"
