# BearCore-V 中断集成开发辅助脚本

PROJ_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
INTERRUPT_DEV="$PROJ_ROOT/interrupt_dev"

echo "${GREEN}🔧 BearCore-V 中断集成开发环境${NC}"
echo "===================================="

# 显示当前状态
"$INTERRUPT_DEV/phase_manager.sh" status

echo ""
echo "${YELLOW}可用命令:${NC}"
echo "  ./phase_manager.sh status    # 显示当前状态"
echo "  ./phase_manager.sh next      # 进入下一阶段"
echo "  ./phase_manager.sh test      # 运行当前阶段测试"
echo ""
echo "${YELLOW}开发工具:${NC}"
echo "  make test TEST=...           # 运行测试"
echo "  make sim                     # 运行仿真"
echo "  make clean                   # 清理构建"
echo ""
echo "${YELLOW}目录结构:${NC}"
echo "  phases/      - 各阶段代码"
echo "  tests/       - 阶段测试"
echo "  logs/        - 开发日志"
echo "  backup/      - 版本备份"
echo "  waveforms/   - 波形文件"

# 设置颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'