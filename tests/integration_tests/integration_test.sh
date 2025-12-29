#!/bin/bash

# RISC-V核心集成测试脚本
# 测试整个核心的功能

set -e

PROJ_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BUILD_DIR="$PROJ_ROOT/build"
TEST_DIR="$PROJ_ROOT/tests"
LOG_DIR="$PROJ_ROOT/test_logs"

mkdir -p $LOG_DIR
mkdir -p $BUILD_DIR

echo "=== RISC-V Core Integration Tests ==="
echo "Start time: $(date)"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass_count=0
fail_count=0

# 测试函数
run_test() {
    local test_name=$1
    local test_file=$2
    local log_file="$LOG_DIR/${test_name}_$(date +%Y%m%d_%H%M%S).log"
    
    echo -n "Running $test_name... "
    
    # 编译测试程序
    cd $PROJ_ROOT
    make clean > /dev/null 2>&1
    if make test TEST="$test_file" > "$log_file" 2>&1; then
        # 运行仿真
        if make sim >> "$log_file" 2>&1; then
            # 检查是否成功完成（通过特定的输出判断）
            if grep -q "TEST_PASS" simulation.log 2>/dev/null || \
               grep -q "All tests passed" simulation.log 2>/dev/null; then
                echo -e "${GREEN}PASS${NC}"
                pass_count=$((pass_count + 1))
                return 0
            fi
        fi
    fi
    
    echo -e "${RED}FAIL${NC}"
    echo "  See log: $log_file"
    fail_count=$((fail_count + 1))
    return 1
}

# 运行各种集成测试
echo "1. Basic Instruction Tests"
echo "--------------------------"
run_test "minimal" "tests/minimal_test.s"
run_test "simple_arithmetic" "tests/test.s"

echo ""
echo "2. Control Flow Tests"
echo "---------------------"
run_test "jump" "tests/jump_test.S"
run_test "branch" "tests/direct_test.s"

echo ""
echo "3. CSR Register Tests"
echo "---------------------"
run_test "csr_basic" "tests/csr_simple_test.c"
run_test "csr_detailed" "tests/csr_detailed_test.s"
run_test "csr_trap" "tests/csr_asm_test.s"

echo ""
echo "4. Memory Access Tests"
echo "----------------------"
# 创建内存访问测试
cat > $TEST_DIR/integration_tests/memory_test.s << 'MEMEOF'
.section .text
.global _start
_start:
    # 测试存储和加载
    li t0, 0x1000        # 测试地址
    li t1, 0xDEADBEEF    # 测试数据
    
    # 存储字
    sw t1, 0(t0)
    
    # 加载字
    lw t2, 0(t0)
    
    # 验证
    bne t1, t2, fail
    
    # 测试半字
    li t1, 0x12345678
    sh t1, 4(t0)
    lh t2, 4(t0)
    li t3, 0x00005678    # 符号扩展后的期望值
    bne t2, t3, fail
    
    # 测试字节
    li t1, 0xA5
    sb t1, 8(t0)
    lb t2, 8(t0)
    li t3, 0xFFFFFFA5    # 符号扩展后的期望值
    bne t2, t3, fail
    
    # 成功
    li a0, 0x12345678
    li a7, 1
    scall
    
fail:
    li a0, 0xDEADBEEF
    li a7, 1
    scall
MEMEOF

run_test "memory_access" "tests/integration_tests/memory_test.s"

echo ""
echo "5. Exception and Interrupt Tests"
echo "--------------------------------"
cat > $TEST_DIR/integration_tests/exception_test.s << 'EXCEPTIONEOF'
.section .text
.global _start
_start:
    # 设置异常处理程序
    la t0, trap_handler
    csrw mtvec, t0
    
    # 触发非法指令异常
    .word 0x00000000  # 非法指令
    
    # 如果返回，继续执行
    li a0, 0x12345678
    li a7, 1
    scall
    
trap_handler:
    # 异常处理程序
    csrr t0, mcause
    li t1, 2           # 非法指令的mcause值
    bne t0, t1, trap_fail
    
    # 从异常返回
    mret
    
trap_fail:
    li a0, 0xDEADBEEF
    li a7, 1
    scall
EXCEPTIONEOF

run_test "exception" "tests/integration_tests/exception_test.s"

echo ""
echo "=== Test Summary ==="
echo "Total tests: $((pass_count + fail_count))"
echo "Passed: $pass_count"
echo "Failed: $fail_count"
echo ""

if [ $fail_count -eq 0 ]; then
    echo -e "${GREEN}✓ All integration tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
