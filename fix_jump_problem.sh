#!/bin/bash
# fix_jump_problem.sh

echo "=== 修復跳轉問題 ==="

# 1. 備份原始 start.s
cp src/start.s src/start.s.backup

# 2. 使用 la 偽指令的版本
cat > src/start.s << 'EOF'
.section .text.init
.global _start

_start:
    # 🏆 硬體冒煙測試
    li t0, 0x10000000
    li t1, 0x47       # 'G' 代表 Go
    sw t1, 0(t0)      # 直接在彙編階段印一個字元

    lui sp, 0x8       # 設定堆疊頂端於 0x00008000
    
    # 🏆 使用 la 偽指令加載 main 的地址
    la ra, main
    jalr ra           # 跳轉到 main
    
loop:
    j loop
EOF

# 3. 重新編譯
echo "重新編譯..."
make clean
make all

# 4. 檢查生成的指令
echo -e "\n=== 檢查地址 0x8 處的指令 ==="
riscv64-unknown-elf-objdump -d firmware.elf --start-address=0x8 --stop-address=0x10

echo -e "\n=== 檢查 main 函數地址 ==="
riscv64-unknown-elf-nm firmware.elf | grep main

# 5. 生成 hex 並測試
echo -e "\n=== 生成 hex 文件 ==="
riscv64-unknown-elf-objcopy -O binary firmware.elf firmware.bin
od -An -t x4 -w4 -v firmware.bin | tr -d ' ' > firmware.hex

echo "前10條指令："
head -10 firmware.hex

# 6. 運行模擬測試
echo -e "\n=== 運行模擬測試 ==="
echo "如果看到 'G' 後還有其他輸出，表示跳轉成功"
echo "如果只有 'G'，則跳轉仍有問題"
echo ""
echo "按 Enter 繼續運行模擬..."
read

iverilog -g2012 -o wave.vvp -f files.f && vvp wave.vvp