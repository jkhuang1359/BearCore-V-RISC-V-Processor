#!/bin/bash
# test_compile.sh

echo "=== 測試編譯環境 ==="
echo "1. 檢查工具鏈..."
which riscv64-unknown-elf-gcc
riscv64-unknown-elf-gcc --version

echo "2. 檢查頭文件..."
ls -la include/

echo "3. 簡單編譯測試..."
cat > /tmp/simple_test.c << 'EOF'
#include <stdint.h>
#include <stddef.h>
int main() { 
    void *p = NULL;
    return 0; 
}
EOF

riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles \
    -ffreestanding -fno-builtin -I./include \
    -T sw/link.ld -o /tmp/simple.elf /tmp/simple_test.c 2>&1

if [ $? -eq 0 ]; then
    echo "✅ 基本編譯測試通過"
else
    echo "❌ 基本編譯測試失敗"
fi

rm -f /tmp/simple_test.c /tmp/simple.elf