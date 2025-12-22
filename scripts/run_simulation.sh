#!/bin/bash
# BearCore-V 自動化仿真腳本

echo "=== BearCore-V 仿真 ==="
echo "1. 清理..."
make clean

echo "2. 編譯韌體..."
make all

echo "3. 編譯仿真..."
iverilog -g2012 -o wave.vvp -f files.f

echo "4. 執行仿真..."
vvp wave.vvp

echo "5. 查看波形（可選）..."
echo "   使用 gtkwave cpu.vcd 查看波形"
