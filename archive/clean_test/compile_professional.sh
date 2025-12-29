#!/bin/bash
# ==============================================================================
# 專業編譯腳本 v3.2 (熊芯-V 終極修正版)
# ==============================================================================

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_error() { echo -e "${RED}❌ $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "ℹ️  $1"; }

clear
echo "專業編譯腳本 v3.2"
echo "=================="

# 1. 檢查文件
print_info "1. 檢查必要文件..."
REQUIRED_FILES=("alu.v" "decoder.v" "reg_file.v" "rom.v" "data_ram.v" "csr_registers.v" "uart_tx.v" "core.v")

MISSING=0
for file in "${REQUIRED_FILES[@]}"; do
    [ ! -f "$file" ] && { print_error "缺少: $file"; MISSING=1; } || print_success "$file"
done
[ $MISSING -eq 1 ] && exit 1

# 2. 語法版本
print_info "2. 檢查語法版本需求..."
NEED_G2012=0
grep -q "integer.*:" "${REQUIRED_FILES[@]}" 2>/dev/null && NEED_G2012=1
grep -q "logic\|byte\|shortint\|int\|longint\|bit" "${REQUIRED_FILES[@]}" 2>/dev/null && NEED_G2012=1
[ $NEED_G2012 -eq 1 ] && print_warning "需要使用 -g2012"

# 3. 選擇 Testbench
print_info "3. 選擇 testbench..."
TB_FILE=""
TB_PRIORITY=("tb_pc_fixed.v" "tb_debug.v" "tb_simple.v" "tb_minimal.v")
for tb in "${TB_PRIORITY[@]}"; do
    if [ -f "$tb" ]; then
        TB_FILE="$tb"; OUTPUT="${tb%.v}.vvp"; print_success "找到: $TB_FILE"; break
    fi
done

# 4. 檢查重複包含 (修正反引號邏輯)
print_info "4. 檢查模塊重複包含..."
if [ -n "$TB_FILE" ]; then
    # 🏆 使用 \$' 避開反引號衝突
    if grep -q "\`include" "$TB_FILE" 2>/dev/null; then
        print_warning "testbench 包含 \`include 語句"
        # 簡化檢測，僅提醒用戶
    fi
fi

# 5. 構建命令
print_info "5. 構建編譯命令..."
IV_FLAGS="-Wall"
[ $NEED_G2012 -eq 1 ] && IV_FLAGS="$IV_FLAGS -g2012"
COMPILE_FILES="$TB_FILE ${REQUIRED_FILES[*]}"

# 6. 語法檢查
print_info "6. 進行語法檢查..."
iverilog $IV_FLAGS -t null $COMPILE_FILES 2> syntax_check.log
if [ $? -ne 0 ]; then
    print_error "語法檢查失敗！"
    grep -E "error|Error" syntax_check.log | head -10
    exit 1
fi
print_success "語法檢查通過"

# 7. 正式編譯
print_info "7. 正式編譯..."
# 🏆 修正原本變數誤用的問題
iverilog $IV_FLAGS -o "$OUTPUT" $COMPILE_FILES 2> compile.log
if [ $? -eq 0 ]; then
    print_success "編譯成功！"
    echo -e "\n👉 運行: vvp $OUTPUT"
    echo -e "👉 波形: gtkwave ${OUTPUT%.vvp}.vcd\n"
else
    print_error "編譯失敗！"
    cat compile.log | head -20
    exit 1
fi

# 8. 清理
rm -f syntax_check.log compile.log
print_info "所有步驟完成。"