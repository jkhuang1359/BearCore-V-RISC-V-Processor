#!/bin/bash

echo "================================================================"
echo "BearCore-V 最終測試"
echo "================================================================"

# 創建一個簡單的 hex 文件
cat > firmware.hex << 'HEXEOF'
100002b7
02100313
0062a023
0000006f
HEXEOF

echo "1. 檢查文件..."
ls -la src/*.v | head -10

echo ""
echo "2. 編譯..."
iverilog -o final.vvp -f files.f -I src 2>final_compile.log

if [ $? -ne 0 ]; then
    echo "❌ 編譯失敗"
    echo "錯誤信息:"
    cat final_compile.log
    exit 1
fi

echo "✅ 編譯成功"

echo ""
echo "3. 運行仿真..."
echo "如果 CPU 工作，應該能看到 PC 變化"
echo "----------------------------------------"

# 運行仿真，設置超時
timeout 3 vvp final.vvp 2>&1 | tee final_sim.log

echo ""
echo "4. 分析結果..."

# 檢查是否有任何輸出
if [ -s final_sim.log ]; then
    echo "✅ 仿真有輸出"
    echo "輸出內容:"
    cat final_sim.log
    
    # 檢查是否有錯誤
    if grep -q "error\|Error\|ERROR" final_sim.log; then
        echo "❌ 檢測到錯誤"
    fi
    
    # 檢查是否有警告
    if grep -q "warning\|Warning\|WARNING" final_sim.log; then
        echo "⚠️  檢測到警告"
        grep -i "warning" final_sim.log
    fi
else
    echo "❌ 仿真沒有輸出"
fi

# 檢查波形文件
if [ -f "cpu.vcd" ]; then
    echo "✅ 波形文件生成: cpu.vcd"
    echo "  可用 gtkwave cpu.vcd 查看"
else
    echo "❌ 波形文件未生成"
fi

echo ""
echo "================================================================"
echo "測試完成"
echo "================================================================"
