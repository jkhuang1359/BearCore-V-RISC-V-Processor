#!/bin/bash

echo "🎯 启动BearCore-V中断集成开发"
echo "==============================="

# 显示当前状态
./interrupt_dev/phase_manager.sh status

echo ""
echo "可用命令:"
echo "  ./interrupt_dev/phase_manager.sh help     # 查看帮助"
echo "  ./interrupt_dev/scripts/switch_to_phase.sh [N]  # 切换到阶段N"
echo "  ./interrupt_dev/scripts/develop_monitor.sh status  # 开发监控"
echo ""
echo "开始开发前请先运行基准测试:"
echo "  ./interrupt_dev/scripts/phase0_baseline.sh"
echo ""
echo "开发工作流程请参考:"
echo "  cat interrupt_dev/WORKFLOW.md"

# 进入项目目录
cd $(dirname "$0")/../..
exec $SHELL
