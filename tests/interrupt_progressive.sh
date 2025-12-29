echo "渐进式中断集成测试"
echo "=================="

echo "阶段1: 验证原有功能..."
make clean
make test TEST=tests/minimal_test.s
if [ $? -eq 0 ]; then
    echo "✅ 原有功能正常"
else
    echo "❌ 原有功能被破坏"
    exit 1
fi

echo ""
echo "阶段2: 测试中断向量设置..."
make clean
make test TEST=tests/interrupt_vector_test.s
if grep -q "0x12345678" simulation.log; then
    echo "✅ 中断向量设置正常"
else
    echo "⚠️  中断向量设置可能有问题"
fi

echo ""
echo "阶段3: 测试软件中断..."
make clean
make test TEST=tests/interrupt_simple_test.s
if grep -q "0x87654321" simulation.log; then
    echo "✅ 软件中断处理正常"
else
    echo "⚠️  软件中断处理可能有问题"
fi

echo ""
echo "所有渐进测试完成!"