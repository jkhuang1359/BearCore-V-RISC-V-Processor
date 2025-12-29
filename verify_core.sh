#!/bin/bash
# BearCore-V 核心功能驗證腳本

set -e

echo "===================================================================="
echo "BearCore-V 核心功能驗證"
echo "===================================================================="

# 創建目錄
mkdir -p logs
mkdir -p hw_tests/phase0

# 測試列表
TESTS=(
    "minimal_test"
    "alu_comprehensive" 
    "control_flow"
    "memory_test"
    "csr_test"
    "comprehensive_test"
)

# 先編譯所有測試
echo ""
echo "編譯測試程序..."
for test in "${TESTS[@]}"; do
    echo "  📝 編譯 $test..."
    
    # 檢查測試文件是否存在
    if [ ! -f "hw_tests/phase0/${test}.s" ]; then
        echo "    ❌ 測試文件不存在: hw_tests/phase0/${test}.s"
        continue
    fi
    
    # 編譯
    cd hw_tests/phase0
    riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -g \
        -T link.ld -o ${test}.elf ${test}.s 2>../../logs/${test}_compile.err
    
    if [ $? -ne 0 ]; then
        echo "    ❌ 編譯失敗"
        cat ../../logs/${test}_compile.err
    else
        # 生成 hex
        riscv64-unknown-elf-objcopy -O binary ${test}.elf ${test}.bin
        od -An -tx4 -w4 -v ${test}.bin > ${test}.hex
        echo "    ✅ 編譯成功"
    fi
    cd ../..
done

echo ""
echo "運行硬體仿真..."
echo ""

PASS_COUNT=0
FAIL_COUNT=0

# 運行每個測試
for test in "${TESTS[@]}"; do
    echo "🔍 測試: $test"
    echo "----------------------------------------"
    
    # 檢查 hex 文件是否存在
    if [ ! -f "hw_tests/phase0/${test}.hex" ]; then
        echo "  ⚠️  hex 文件不存在，跳過"
        continue
    fi
    
    # 複製 hex 文件
    cp hw_tests/phase0/${test}.hex firmware.hex
    
    # 編譯仿真
    echo "  編譯仿真..."
    iverilog -o wave.vvp -f files.f -I src 2>logs/${test}_iverilog.err
    
    if [ $? -ne 0 ]; then
        echo "  ❌ 仿真編譯失敗"
        cat logs/${test}_iverilog.err
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi
    
    # 運行仿真
    echo "  運行仿真..."
    timeout 10 vvp wave.vvp > logs/${test}_sim.log 2>&1
    
    # 檢查結果
    if grep -q "PASS" logs/${test}_sim.log; then
        echo "  ✅ 測試通過"
        PASS_COUNT=$((PASS_COUNT + 1))
        
        # 顯示 UART 輸出
        echo "  UART 輸出:"
        grep -o "PASS\|FAIL" logs/${test}_sim.log | head -1
    elif grep -q "FAIL" logs/${test}_sim.log; then
        echo "  ❌ 測試失敗"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        
        # 顯示錯誤信息
        echo "  UART 輸出:"
        grep -o "FAIL" logs/${test}_sim.log | head -1
    else
        echo "  ⚠️  結果不確定"
        
        # 顯示最後幾行輸出
        echo "  最後幾行輸出:"
        tail -5 logs/${test}_sim.log
    fi
    
    echo ""
done

# 總結
echo "===================================================================="
echo "測試總結"
echo "===================================================================="
echo "總測試數: ${#TESTS[@]}"
echo "通過: $PASS_COUNT"
echo "失敗: $FAIL_COUNT"
echo "跳過: $((${#TESTS[@]} - PASS_COUNT - FAIL_COUNT))"
echo ""

if [ $FAIL_COUNT -eq 0 ] && [ $PASS_COUNT -gt 0 ]; then
    echo "🎉 核心功能驗證通過！"
    echo ""
    echo "下一步："
    echo "1. 查看詳細波形：gtkwave cpu.vcd"
    echo "2. 進入階段 1 開發：./interrupt_dev/phase_manager.sh next"
    exit 0
else
    echo "⚠️  有測試失敗，需要調試。"
    echo ""
    echo "調試建議："
    echo "1. 查看失敗測試的日誌：less logs/<testname>_sim.log"
    echo "2. 檢查反彙編：riscv64-unknown-elf-objdump -d hw_tests/phase0/<testname>.elf"
    echo "3. 手動運行仿真調試："
    echo "   cp hw_tests/phase0/<testname>.hex firmware.hex"
    echo "   iverilog -o wave.vvp -f files.f -I src"
    echo "   vvp wave.vvp"
    exit 1
fi