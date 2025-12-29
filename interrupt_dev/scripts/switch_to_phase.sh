#!/bin/bash

# 切换到指定阶段的开发环境

set -e

PHASE=$1
PROJ_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
PHASE_DIR="$PROJ_ROOT/interrupt_dev/phases/phase${PHASE}"
BACKUP_DIR="$PROJ_ROOT/interrupt_dev/backup"

if [ -z "$PHASE" ]; then
    echo "用法: $0 [阶段号]"
    echo "例如: $0 1   # 切换到阶段1"
    exit 1
fi

if [ ! -d "$PHASE_DIR" ]; then
    echo "错误: 阶段${PHASE}目录不存在"
    exit 1
fi

echo "切换到阶段${PHASE}..."

# 1. 备份当前文件
echo "1. 备份当前文件..."
mkdir -p "$BACKUP_DIR/current"
cp src/core.v "$BACKUP_DIR/current/" 2>/dev/null || true
cp src/csr_registers.v "$BACKUP_DIR/current/" 2>/dev/null || true

# 2. 复制阶段文件到主目录
echo "2. 应用阶段${PHASE}文件..."

# 检查阶段文件是否存在
if [ -f "$PHASE_DIR/core_phase${PHASE}.v" ]; then
    cp "$PHASE_DIR/core_phase${PHASE}.v" src/core.v
    echo "   ✅ 核心文件已应用"
fi

if [ -f "$PHASE_DIR/csr_phase${PHASE}.v" ]; then
    cp "$PHASE_DIR/csr_phase${PHASE}.v" src/csr_registers.v
    echo "   ✅ CSR文件已应用"
fi

# 3. 更新测试文件
echo "3. 更新测试文件..."
if [ -f "$PHASE_DIR/test_phase${PHASE}.s" ]; then
    cp "$PHASE_DIR/test_phase${PHASE}.s" tests/phase_test.s
    echo "   ✅ 测试程序已应用"
fi

# 4. 创建符号链接（可选）
echo "4. 创建开发链接..."
ln -sf "$PHASE_DIR" interrupt_dev/current_phase 2>/dev/null || true

# 5. 记录切换
echo "$PHASE" > interrupt_dev/.current_phase

echo ""
echo "✅ 已切换到阶段${PHASE}"
echo ""
echo "可用命令:"
echo "  make test TEST=tests/phase_test.s  # 运行阶段测试"
echo "  make sim                           # 运行仿真"
echo "  ./interrupt_dev/phase_manager.sh status  # 查看状态"
