#!/bin/bash

# BearCore-V 中断集成开发环境一键初始化

set -e

PROJ_ROOT=$(cd "$(dirname "$0")/.." && pwd)
INTERRUPT_DEV="$PROJ_ROOT/interrupt_dev"

echo "🚀 BearCore-V 中断集成开发环境初始化"
echo "==================================="

# 1. 检查当前状态
echo "1. 检查当前项目状态..."
if [ ! -d "src" ]; then
    echo "❌ 错误：未在项目根目录中运行"
    exit 1
fi

# 2. 创建目录结构
echo "2. 创建开发目录结构..."
mkdir -p "$INTERRUPT_DEV/phases"
mkdir -p "$INTERRUPT_DEV/tests"
mkdir -p "$INTERRUPT_DEV/scripts"
mkdir -p "$INTERRUPT_DEV/logs"
mkdir -p "$INTERRUPT_DEV/backup"
mkdir -p "$INTERRUPT_DEV/waveforms"

echo "   ✅ 目录结构创建完成"

# 3. 设置Git忽略
echo "3. 配置Git忽略规则..."
cat > "$INTERRUPT_DEV/.gitignore" << 'GITIGNORE'
# 开发环境忽略文件
logs/
backup/
waveforms/
*.vvp
*.vcd
*.log
current_phase
GITIGNORE

echo "   ✅ Git忽略配置完成"

# 4. 初始化阶段管理器
echo "4. 初始化阶段管理器..."
echo "0" > "$INTERRUPT_DEV/.current_phase"
chmod +x "$INTERRUPT_DEV/phase_manager.sh"
chmod +x "$INTERRUPT_DEV/scripts/"*.sh 2>/dev/null || true

echo "   ✅ 阶段管理器初始化完成"

# 5. 创建阶段0（基准测试）
echo "5. 创建阶段0：基准测试..."
mkdir -p "$INTERRUPT_DEV/phases/phase0"

cat > "$INTERRUPT_DEV/phases/phase0/README.md" << 'PHASE0_README'
# 阶段0：基准测试

## 目标
- 确保现有核心稳定
- 记录性能基线
- 为后续中断集成提供参考

## 文件
- 无单独文件，使用现有核心

## 测试
- 运行所有现有测试套件
- 记录性能指标
- 保存参考波形
PHASE0_README

echo "   ✅ 阶段0创建完成"

# 6. 备份当前版本
echo "6. 备份当前稳定版本..."
mkdir -p "$INTERRUPT_DEV/backup/phase0"
cp src/core.v "$INTERRUPT_DEV/backup/phase0/core_original.v" 2>/dev/null || true
cp src/csr_registers.v "$INTERRUPT_DEV/backup/phase0/csr_original.v" 2>/dev/null || true

echo "   ✅ 当前版本备份完成"

# 7. 创建开发监控
echo "7. 创建开发监控..."
cat > "$INTERRUPT_DEV/scripts/start_development.sh" << 'START_DEV'
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
START_DEV

chmod +x "$INTERRUPT_DEV/scripts/start_development.sh"

echo "   ✅ 开发启动脚本创建完成"

# 8. 完成
echo ""
echo "🎉 BearCore-V中断集成开发环境初始化完成！"
echo ""
echo "下一步操作:"
echo "1. 运行基准测试:"
echo "   ./interrupt_dev/scripts/phase0_baseline.sh"
echo ""
echo "2. 启动开发环境:"
echo "   ./interrupt_dev/scripts/start_development.sh"
echo ""
echo "3. 查看开发指南:"
echo "   cat interrupt_dev/WORKFLOW.md"
echo ""
echo "4. 开始阶段1开发:"
echo "   ./interrupt_dev/phase_manager.sh next"
echo ""
echo "📚 开发文档已就绪，祝您开发顺利！"
