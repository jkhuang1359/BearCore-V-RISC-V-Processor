#!/bin/bash
# analyze_tests.sh

echo "=== BearCore-V 測試分析報告 ==="
date
echo ""

# 基本統計
echo "📊 基本統計:"
echo "  程式大小: $(grep -E 'text.*data.*bss' simulation.log | head -1)"
echo "  ROM 使用: $(grep "目前佔用:" simulation.log | tail -1)"
echo "  RAM 使用: BSS 段 $(grep "bss" simulation.log | awk '{print $3}') 字節"
echo ""

# 測試結果
echo "✅ 測試結果摘要:"
echo "  總測試組數: $(grep "測試組數:" simulation.log | tail -1 | awk '{print $2}')"
echo "  總測試案例: $(grep "通過:" simulation.log | tail -1 | awk '{print $2 + $4}')"
echo "  通過案例: $(grep "通過:" simulation.log | tail -1 | awk '{print $2}')"
echo "  失敗案例: $(grep "失敗:" simulation.log | tail -1 | awk '{print $4}')"
echo "  成功率: $(grep "成功率:" simulation.log | tail -1 | awk '{print $2}')"
echo ""

# 浮點測試結果
echo "🧮 浮點測試結果:"
if grep -q "浮點概念測試" simulation.log; then
    FLOAT_TESTS=$(grep -A 30 "浮點概念測試" simulation.log | grep -c "✓")
    echo "  浮點測試通過數: $FLOAT_TESTS"
    echo "  浮點測試內容:"
    grep -A 30 "浮點概念測試" simulation.log | grep "\[.*\]" | head -5
else
    echo "  浮點測試: 未啟用"
fi
echo ""

# 性能指標
echo "⚡ 性能指標:"
if grep -q "Time:" simulation.log; then
    grep "Time:" simulation.log | head -2
fi
echo ""

# 警告和錯誤
echo "⚠️  警告和錯誤:"
WARN_COUNT=$(grep -c "WARNING\|warning" simulation.log)
ERROR_COUNT=$(grep -c "ERROR\|error" simulation.log)
echo "  警告數量: $WARN_COUNT"
echo "  錯誤數量: $ERROR_COUNT"
if [ $WARN_COUNT -gt 0 ]; then
    grep -i "warning" simulation.log | head -3
fi
echo ""