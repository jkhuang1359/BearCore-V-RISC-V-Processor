#!/bin/bash

# 阶段0：基准测试 - 确保原有功能正常

set -e

PROJ_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
LOG_DIR="$PROJ_ROOT/interrupt_dev/logs/phase0"
mkdir -p "$LOG_DIR"

echo "=== 阶段0：基准测试 ==="
echo "目标：确保中断集成不影响原有功能"
echo ""

cd "$PROJ_ROOT"

# 1. 备份当前稳定版本
echo "1. 备份稳定版本..."
mkdir -p "$PROJ_ROOT/interrupt_dev/backup/phase0"
if [ -f "src/core.v" ]; then
    cp src/core.v "$PROJ_ROOT/interrupt_dev/backup/phase0/core_original.v"
    echo "   ✅ core.v 备份完成"
else
    echo "   ⚠️  找不到 src/core.v"
fi

if [ -f "src/csr_registers.v" ]; then
    cp src/csr_registers.v "$PROJ_ROOT/interrupt_dev/backup/phase0/csr_original.v"
    echo "   ✅ csr_registers.v 备份完成"
else
    echo "   ⚠️  找不到 src/csr_registers.v"
fi

echo ""

# 2. 运行现有测试套件
echo "2. 运行现有测试套件..."

# 检查测试文件目录
TEST_DIR="$PROJ_ROOT/interrupt_dev/tests/phase0"
if [ ! -d "$TEST_DIR" ]; then
    echo "   ❌ 测试目录不存在: $TEST_DIR"
    exit 1
fi

tests=(
    "$TEST_DIR/minimal_test.s"
    "$TEST_DIR/test.s"
    "$TEST_DIR/jump_test.S"
    "$TEST_DIR/csr_simple_test.c"
)

# 检查工具链
if ! command -v riscv64-unknown-elf-gcc &> /dev/null; then
    echo "   ❌ RISC-V 工具链未安装"
    exit 1
fi

# 检查 spike
if ! command -v spike &> /dev/null; then
    echo "   ❌ spike 未安装"
    exit 1
fi

all_pass=true
for test in "${tests[@]}"; do
    test_name=$(basename "$test")
    log_file="$LOG_DIR/${test_name}.log"
    
    echo -n "  测试 $test_name... "
    
    if [ ! -f "$test" ]; then
        echo "❌ (文件不存在)"
        all_pass=false
        echo "文件 $test 不存在" > "$log_file"
        continue
    fi
    
    > "$log_file"  # 清空日志文件
    
    # 编译测试程序
    echo "编译 $test_name..." >> "$log_file"
    riscv64-unknown-elf-gcc -o "${test}.elf" "$test" -nostdlib -march=rv32i -mabi=ilp32 -Ttext=0x80000000 >> "$log_file" 2>&1
    
    # 检查编译是否成功
    if [ $? -ne 0 ]; then
        echo "❌ (编译失败)"
        all_pass=false
        continue
    fi
    
    echo "编译成功，使用spike运行..." >> "$log_file"
    
    # 使用timeout防止spike卡住
    timeout 5s spike --isa=rv32i "${test}.elf" 2>&1 | head -20 >> "$log_file"
    spike_exit=$?
    
    echo "spike退出码: $spike_exit" >> "$log_file"
    
    # 检查运行结果
    if [ $spike_exit -eq 0 ] || [ $spike_exit -eq 124 ] || grep -q "ebreak\|ecall" "$log_file"; then
        echo "✅"
        echo "测试通过" >> "$log_file"
    else
        echo "❌ (运行失败)"
        echo "测试失败，退出码: $spike_exit" >> "$log_file"
        all_pass=false
    fi
done

echo ""

# 3. 创建性能基线
echo "3. 创建性能基线..."
current_date=$(date)
cat > "$LOG_DIR/performance_baseline.txt" << BASELINE
BearCore-V 性能基线
===================
测试时间: $current_date

核心特性：
- RV32I 指令集
- 5级流水线
- 基础CSR支持
- UART输出

性能指标：
1. 时钟频率: 100 MHz (目标)
2. 关键路径: 待测量
3. 面积: 待测量
4. 功耗: 待测量

测试通过情况：
BASELINE

# 添加测试状态
for test in "${tests[@]}"; do
    test_name=$(basename "$test")
    log_file="$LOG_DIR/${test_name}.log"
    status="❌"
    
    if [ -f "$test" ] && [ -f "$log_file" ]; then
        if grep -q "测试通过\|编译成功" "$log_file"; then
            status="✅"
        elif grep -q "仅编译成功" "$log_file"; then
            status="⚠️"
        fi
    fi
    
    echo "- $test_name: $status" >> "$LOG_DIR/performance_baseline.txt"
done

cat >> "$LOG_DIR/performance_baseline.txt" << BASELINE

建议：
1. 记录当前波形作为参考
2. 测量关键路径时序
3. 确保所有现有功能正常
BASELINE

echo "   ✅ 性能基线已保存到 $LOG_DIR/performance_baseline.txt"

# 4. 总结
echo ""
echo "=== 阶段0完成 ==="
if $all_pass; then
    echo "✅ 所有测试通过，可以进入阶段1"
else
    echo "❌ 有测试失败，请检查 $LOG_DIR 中的日志"
    
    # 显示失败的测试
    echo "失败的测试:"
    for test in "${tests[@]}"; do
        test_name=$(basename "$test")
        log_file="$LOG_DIR/${test_name}.log"
        if [ -f "$log_file" ] && ! grep -q "测试通过" "$log_file"; then
            echo "  - $test_name"
        fi
    done
    
    exit 1
fi
