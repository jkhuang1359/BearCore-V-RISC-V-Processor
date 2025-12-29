#!/bin/bash

echo "===================================================================="
echo "BearCore-V Stage 0: 硬件功能基准测试"
echo "===================================================================="

# 创建日志目录
mkdir -p logs

# 进入测试目录
cd hw_tests/phase0

# 编译并运行所有测试
echo ""
echo "步骤 1: 编译测试程序..."
make compile

echo ""
echo "步骤 2: 运行硬件仿真测试..."
echo ""

# 运行每个测试
TESTS=("minimal_test" "test" "jump_test" "csr_test" "alu_comprehensive" "control_flow" "memory_test")

PASS_COUNT=0
FAIL_COUNT=0

for test in "${TESTS[@]}"; do
    echo "运行测试: $test"
    echo "----------------------------------------"
    
    # 运行测试
    make $test.vcd 2>&1 | tee ../logs/$test.run.log
    
    # 检查结果
    if grep -q "✅ 测试通过" ../logs/$test.run.log; then
        echo "✅ $test: 通过"
        PASS_COUNT=$((PASS_COUNT + 1))
    elif grep -q "❌ 测试失败" ../logs/$test.run.log; then
        echo "❌ $test: 失败"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        
        # 显示更多信息
        echo "   最后接收的UART字符:"
        tail -20 ../logs/$test.run.log | grep -A5 "接收到的字符"
    else
        echo "⚠️  $test: 未知结果"
    fi
    
    echo ""
done

# 返回项目根目录
cd ../..

# 生成测试报告
echo "===================================================================="
echo "测试完成摘要"
echo "===================================================================="
echo "总测试数: ${#TESTS[@]}"
echo "通过: $PASS_COUNT"
echo "失败: $FAIL_COUNT"
echo "未知: $((${#TESTS[@]} - PASS_COUNT - FAIL_COUNT))"
echo ""

if [ $FAIL_COUNT -eq 0 ] && [ $PASS_COUNT -eq ${#TESTS[@]} ]; then
    echo "🎉 所有测试通过！可以进入阶段 1。"
    echo ""
    echo "下一步:"
    echo "1. 检查波形文件: gtkwave cpu.vcd"
    echo "2. 开始阶段 1 开发: ./phase_manager.sh next"
    exit 0
else
    echo "⚠️  有测试失败，请检查 logs/ 目录中的日志文件。"
    echo ""
    echo "调试建议:"
    echo "1. 查看失败测试的日志: less logs/<testname>.run.log"
    echo "2. 检查反汇编文件: less hw_tests/phase0/<testname>.disasm"
    echo "3. 运行详细仿真: cd hw_tests/phase0 && make debug_<testname>"
    exit 1
fi