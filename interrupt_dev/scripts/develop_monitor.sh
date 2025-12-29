#!/bin/bash

# 中断集成开发监控

set -e

PROJ_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
LOG_DIR="$PROJ_ROOT/interrupt_dev/logs"
MONITOR_LOG="$LOG_DIR/develop_monitor_$(date +%Y%m%d_%H%M%S).log"

echo "�� BearCore-V 中断集成开发监控"
echo "==============================="
echo "开始时间: $(date)"
echo "日志文件: $MONITOR_LOG"
echo ""

# 创建监控函数
monitor_phase_change() {
    local last_phase=""
    
    while true; do
        if [ -f "$PROJ_ROOT/interrupt_dev/.current_phase" ]; then
            current_phase=$(cat "$PROJ_ROOT/interrupt_dev/.current_phase")
            
            if [ "$current_phase" != "$last_phase" ]; then
                echo "[$(date)] 阶段变更: ${last_phase:-无} -> $current_phase" | tee -a "$MONITOR_LOG"
                last_phase="$current_phase"
            fi
        fi
        
        # 检查测试运行
        if [ -f "simulation.log" ]; then
            test_time=$(stat -c %y "simulation.log" 2>/dev/null)
            if [ "$test_time" != "$last_test_time" ]; then
                echo "[$(date)] 测试运行检测到" | tee -a "$MONITOR_LOG"
                last_test_time="$test_time"
                
                # 检查测试结果
                if grep -q "TEST_PASS" simulation.log; then
                    echo "[$(date)] ✅ 测试通过" | tee -a "$MONITOR_LOG"
                elif grep -q "TEST_FAIL" simulation.log; then
                    echo "[$(date)] ❌ 测试失败" | tee -a "$MONITOR_LOG"
                fi
            fi
        fi
        
        # 检查编译
        if [ -f "files.f" ]; then
            compile_time=$(stat -c %y "files.f" 2>/dev/null)
            if [ "$compile_time" != "$last_compile_time" ]; then
                echo "[$(date)] 项目编译检测到" | tee -a "$MONITOR_LOG"
                last_compile_time="$compile_time"
            fi
        fi
        
        sleep 5
    done
}

# 显示当前状态
show_current_status() {
    echo "当前项目状态:" | tee -a "$MONITOR_LOG"
    echo "--------------" | tee -a "$MONITOR_LOG"
    
    # Git状态
    echo "Git分支:" | tee -a "$MONITOR_LOG"
    git branch --show-current 2>/dev/null | tee -a "$MONITOR_LOG"
    
    # 阶段状态
    if [ -f "$PROJ_ROOT/interrupt_dev/.current_phase" ]; then
        phase=$(cat "$PROJ_ROOT/interrupt_dev/.current_phase")
        echo "开发阶段: 阶段$phase" | tee -a "$MONITOR_LOG"
    fi
    
    # 文件状态
    echo "" | tee -a "$MONITOR_LOG"
    echo "关键文件修改时间:" | tee -a "$MONITOR_LOG"
    for file in src/core.v src/csr_registers.v; do
        if [ -f "$file" ]; then
            mtime=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1)
            echo "  $file: $mtime" | tee -a "$MONITOR_LOG"
        fi
    done
    
    echo "" | tee -a "$MONITOR_LOG"
}

# 运行监控
main() {
    case $1 in
        "status")
            show_current_status
            ;;
        "log")
            tail -f "$MONITOR_LOG"
            ;;
        "monitor")
            echo "开始监控中断集成开发..." | tee -a "$MONITOR_LOG"
            monitor_phase_change
            ;;
        *)
            show_current_status
            echo ""
            echo "可用命令:"
            echo "  $0 status   显示当前状态"
            echo "  $0 monitor  启动实时监控"
            echo "  $0 log      查看监控日志"
            ;;
    esac
}

main "$@"
