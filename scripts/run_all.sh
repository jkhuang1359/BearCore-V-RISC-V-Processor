#!/bin/bash
# scripts/run_all.sh

echo "=== BearCore-V 完整測試流程 ==="
echo "1. 編譯韌體..."
make clean
make all

echo -e "\n2. 運行 Python 指令級模擬..."
python riscv_ils.py --rom firmware.hex --max-cycles 50000

echo -e "\n3. 運行 Verilog 模擬..."
iverilog -g2012 -o wave.vvp -f files.f
vvp wave.vvp

echo -e "\n4. 分析結果..."
echo "如果看到 'Test OK' 和正確的反轉字串，測試通過！"