#!/bin/bash

# BearCore-V 中断集成阶段管理器

PROJ_ROOT=$(cd "$(dirname "$0")/.." && pwd)
INTERRUPT_DEV="$PROJ_ROOT/interrupt_dev"
CURRENT_PHASE_FILE="$INTERRUPT_DEV/.current_phase"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取当前阶段
get_current_phase() {
    if [ -f "$CURRENT_PHASE_FILE" ]; then
        cat "$CURRENT_PHASE_FILE"
    else
        echo "0"
    fi
}

# 设置当前阶段
set_current_phase() {
    echo "$1" > "$CURRENT_PHASE_FILE"
}

# 显示阶段信息
show_phase_info() {
    local phase=$1
    echo ""
    echo "${BLUE}=== 阶段 $phase 信息 ===${NC}"
    
    case $phase in
        0) 
            echo "名称: 基准测试"
            echo "目标: 确保现有核心稳定，建立性能基线"
            echo "任务:"
            echo "  - 运行所有现有测试"
            echo "  - 记录性能指标"
            echo "  - 备份稳定版本"
            ;;
        1)
            echo "名称: 中断检测"
            echo "目标: 添加中断信号接口，只检测不处理"
            echo "任务:"
            echo "  - 添加中断输入信号"
            echo "  - 实现中断状态寄存器"
            echo "  - 验证不影响现有功能"
            ;;
        2)
            echo "名称: 中断跳转"
            echo "目标: 实现中断跳转到mtvec"
            echo "任务:"
            echo "  - 实现中断跳转逻辑"
            echo "  - 保存和恢复PC"
            echo "  - 基本的异常进入/退出"
            ;;
        3)
            echo "名称: CSR完整支持"
            echo "目标: 实现完整的中断相关CSR"
            echo "任务:"
            echo "  - 实现mie、mip、mcause寄存器"
            echo "  - 中断使能控制"
            echo "  - 中断优先级处理"
            ;;
        4)
            echo "名称: 异常处理"
            echo "目标: 支持各种异常"
            echo "任务:"
            echo "  - 非法指令异常"
            echo "  - 内存访问异常"
            echo "  - 系统调用异常"
            ;;
        5)
            echo "名称: 嵌套中断"
            echo "目标: 支持中断优先级和嵌套"
            echo "任务:"
            echo "  - 中断优先级仲裁"
            echo "  - 嵌套中断支持"
            echo "  - 中断屏蔽功能"
            ;;
        6)
            echo "名称: 性能优化"
            echo "目标: 优化中断性能"
            echo "任务:"
            echo "  - 中断延迟优化"
            echo "  - 关键路径优化"
            echo "  - 面积和功耗优化"
            ;;
        *)
            echo "未知阶段"
            ;;
    esac
    echo ""
}

# 显示状态
status() {
    local phase=$(get_current_phase)
    echo "${GREEN}=== BearCore-V 中断集成开发环境 ===${NC}"
    echo ""
    echo "当前阶段: ${YELLOW}阶段 $phase${NC}"
    show_phase_info $phase
    echo "项目根目录: $PROJ_ROOT"
    echo "开发目录: $INTERRUPT_DEV"
}

# 切换到下一阶段
next() {
    local current_phase=$(get_current_phase)
    local next_phase=$((current_phase + 1))
    
    if [ $next_phase -le 6 ]; then
        echo "从${YELLOW}阶段 $current_phase${NC} 切换到 ${GREEN}阶段 $next_phase${NC}"
        set_current_phase $next_phase
        status
    else
        echo "${RED}已经是最后阶段${NC}"
    fi
}

# 切换到上一阶段
prev() {
    local current_phase=$(get_current_phase)
    local prev_phase=$((current_phase - 1))
    
    if [ $prev_phase -ge 0 ]; then
        echo "从${YELLOW}阶段 $current_phase${NC} 切换到 ${GREEN}阶段 $prev_phase${NC}"
        set_current_phase $prev_phase
        status
    else
        echo "${RED}已经是最初阶段${NC}"
    fi
}

# 跳转到指定阶段
goto() {
    local target_phase=$1
    
    if [ $target_phase -ge 0 ] && [ $target_phase -le 6 ]; then
        echo "跳转到 ${GREEN}阶段 $target_phase${NC}"
        set_current_phase $target_phase
        status
    else
        echo "${RED}无效的阶段: $target_phase (有效范围: 0-6)${NC}"
    fi
}

# 运行当前阶段测试
test() {
    local phase=$(get_current_phase)
    echo "运行${YELLOW}阶段 $phase${NC} 测试..."
    
    # 根据阶段调用不同的测试脚本
    case $phase in
        0) run_phase0_test ;;
        1) run_phase1_test ;;
        2) run_phase2_test ;;
        3) run_phase3_test ;;
        4) run_phase4_test ;;
        5) run_phase5_test ;;
        6) run_phase6_test ;;
    esac
}

# 阶段0测试
run_phase0_test() {
    echo "${BLUE}运行阶段0：基准测试${NC}"
    cd "$PROJ_ROOT"
    
    # 运行现有测试套件
    echo "1. 运行现有测试..."
    tests=(
        "tests/minimal_test.s"
        "tests/test.s"
        "tests/jump_test.S"
        "tests/csr_simple_test.c"
    )
    
    for test_file in "${tests[@]}"; do
        echo -n "  $(basename $test_file)... "
        make clean > /dev/null 2>&1
        if make test TEST="$test_file" > /dev/null 2>&1; then
            echo "${GREEN}✅${NC}"
        else
            echo "${RED}❌${NC}"
        fi
    done
    
    # 备份当前稳定版本
    echo "2. 备份稳定版本..."
    mkdir -p "$INTERRUPT_DEV/backup/phase0"
    cp src/core.v "$INTERRUPT_DEV/backup/phase0/core_original.v"
    cp src/csr_registers.v "$INTERRUPT_DEV/backup/phase0/csr_original.v"
    echo "  ${GREEN}✅ 备份完成${NC}"
}

# 阶段1测试
run_phase1_test() {
    echo "${BLUE}运行阶段1：中断检测测试${NC}"
    echo "TODO: 实现阶段1测试"
}

# 显示帮助
help() {
    echo "${GREEN}BearCore-V 中断集成阶段管理器${NC}"
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  status     显示当前状态"
    echo "  next       进入下一阶段"
    echo "  prev       回退到上一阶段"
    echo "  goto N     跳转到阶段N (0-6)"
    echo "  test       运行当前阶段测试"
    echo "  help       显示帮助信息"
    echo ""
    echo "阶段定义:"
    echo "  0: 基准测试"
    echo "  1: 中断检测"
    echo "  2: 中断跳转"
    echo "  3: CSR支持"
    echo "  4: 异常处理"
    echo "  5: 嵌套中断"
    echo "  6: 性能优化"
}

# 主函数
main() {
    # 确保当前阶段文件存在
    if [ ! -f "$CURRENT_PHASE_FILE" ]; then
        set_current_phase 0
    fi
    
    case $1 in
        "status")
            status
            ;;
        "next")
            next
            ;;
        "prev")
            prev
            ;;
        "goto")
            if [ -n "$2" ]; then
                goto $2
            else
                echo "${RED}错误: 需要指定阶段号${NC}"
                echo "用法: $0 goto [0-6]"
            fi
            ;;
        "test")
            test
            ;;
        "help"|"-h"|"--help")
            help
            ;;
        *)
            status
            echo ""
            echo "使用 '$0 help' 查看可用命令"
            ;;
    esac
}

main "$@"
