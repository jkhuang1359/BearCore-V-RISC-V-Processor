#!/bin/bash
# generate_report.sh

echo "=== BearCore-V 測試報告 ==="
date
echo ""

echo "📊 編譯統計:"
echo "  程式大小: $(grep -E 'text|data|bss' firmware.disasm | head -1)"
echo "  ROM 使用: $(grep "目前佔用:" simulation.log | tail -1)"
echo "  RAM 使用: $(grep "bss" firmware.disasm | awk '{print "BSS: "$2" bytes"}')"
echo ""

echo "✅ 測試結果:"
echo "  總測試組數: $(grep "測試組數:" simulation.log | tail -1 | awk '{print $2}')"
echo "  總測試數: $(grep "總測試數:" simulation.log | tail -1 | awk '{print $2}')"
echo "  通過數: $(grep "通過:" simulation.log | tail -1 | awk '{print $2}')"
echo "  失敗數: $(grep "失敗:" simulation.log | tail -1 | awk '{print $2}')"
echo "  成功率: $(grep "成功率:" simulation.log | tail -1 | awk '{print $2}')"
echo ""

echo "📋 測試類別完成情況:"
grep -E "^--- \[[0-9]+\].*---$" simulation.log
echo ""

echo "⚠️  警告訊息:"
grep -i "warning\|error" simulation.log | head -5
echo ""

echo "🕒 執行時間:"
grep "Time diff:" simulation.log
grep "Time:" simulation.log | grep ticks
echo ""

echo "📈 性能指標:"
echo "  程式碼密度: $(grep "text" firmware.disasm | awk '{print $2/1024" KB"}')"
echo "  數據大小: $(grep "data" firmware.disasm | awk '{print $2/1024" KB"}')"
echo "  堆棧使用: $(grep "bss" firmware.disasm | awk '{print $2/1024" KB"}')"