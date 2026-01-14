#!/bin/bash
# detect_fpu.sh

echo "=== 檢測 RISC-V 浮點支援 ==="

# 1. 檢查編譯器支援
echo "1. 檢查編譯器浮點支援..."
riscv64-unknown-elf-gcc -march=rv32imf -dM -E - < /dev/null | grep -i "float\|fpu" | head -10

# 2. 檢查 RTL 代碼
echo -e "\n2. 檢查 RTL 中的浮點關鍵字..."
find src/ -name "*.v" -exec grep -l -i "float\|fpu\|fadd\|fmul" {} \; | head -5

# 3. 生成測試程序
echo -e "\n3. 生成浮點測試程序..."
cat > test_fp.c << 'EOF'
int main() {
    float a = 1.0, b = 2.0;
    float c = a + b;
    return (int)c;
}
EOF

# 4. 嘗試編譯
echo -e "\n4. 嘗試編譯浮點程序..."
if riscv64-unknown-elf-gcc -march=rv32imf -mabi=ilp32f -nostdlib test_fp.c -o test_fp.elf 2>/dev/null; then
    echo "✅ 可以編譯浮點程序"
    
    # 檢查生成的指令
    echo "檢查生成的指令:"
    riscv64-unknown-elf-objdump -d test_fp.elf | grep -i "fadd\|fmul\|flw\|fsw" | head -5
    
    if [ $? -eq 0 ]; then
        echo "✅ 檢測到浮點指令"
    else
        echo "⚠️  未檢測到浮點指令，可能使用軟體庫"
    fi
else
    echo "❌ 無法編譯浮點程序"
    echo "嘗試使用軟體浮點:"
    riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -nostdlib test_fp.c -o test_fp_soft.elf 2>&1 | grep -i "float"
fi

# 清理
rm -f test_fp.c test_fp.elf test_fp_soft.elf