#!/bin/bash
# run_all_configs.sh

echo "=== 運行所有測試配置 ==="
echo ""

echo "1. 最小配置 (無浮點測試)..."
make clean
make test-minimal 2>&1 | tail -10
echo ""

echo "2. 標準配置 (無浮點測試)..."
make clean
make test-standard 2>&1 | tail -10
echo ""

echo "3. 全面配置 (無浮點測試)..."
make clean
make test-full 2>&1 | tail -10
echo ""

echo "4. 標準配置 (帶浮點測試)..."
make clean
make ENABLE_FLOAT_TESTS=1 test-standard 2>&1 | tail -10
echo ""

echo "5. 全面配置 (帶浮點測試)..."
make clean
make ENABLE_FLOAT_TESTS=1 test-full 2>&1 | tail -10
echo ""

echo "6. 調試模式 (帶浮點測試)..."
make clean
make ENABLE_FLOAT_TESTS=1 test-debug 2>&1 | tail -10
echo ""

echo "✅ 所有配置測試完成！"