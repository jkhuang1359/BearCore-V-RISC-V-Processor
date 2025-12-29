#!/bin/bash
echo "编译脚本 v1.0"
echo "============="

# 检查所有文件是否存在
echo "检查文件..."
files=("alu.v" "decoder.v" "reg_file.v" "rom.v" "data_ram.v" 
       "csr_registers.v" "uart_tx.v" "core.v")

missing=0
for file in "${files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ 缺少: $file"
        missing=1
    fi
done

if [ $missing -eq 1 ]; then
    echo "错误：缺少必要文件"
    exit 1
fi

echo "所有必要文件都存在"

# 决定使用哪个testbench
if [ -f "tb_pc_correct.v" ]; then
    TB_FILE="tb_pc_correct.v"
    OUTPUT="pc_correct.vvp"
elif [ -f "tb_if_debug.v" ]; then
    TB_FILE="tb_if_debug.v"
    OUTPUT="if_debug.vvp"
else
    echo "错误：找不到testbench文件"
    exit 1
fi

echo "使用testbench: $TB_FILE"

# 编译命令
echo ""
echo "编译命令："
echo "iverilog -o $OUTPUT $TB_FILE alu.v decoder.v reg_file.v rom.v data_ram.v csr_registers.v uart_tx.v core.v"

iverilog -g2012 -o $OUTPUT $TB_FILE alu.v decoder.v reg_file.v rom.v data_ram.v csr_registers.v uart_tx.v core.v

if [ $? -eq 0 ]; then
    echo "✅ 编译成功"
    echo ""
    echo "运行仿真："
    echo "vvp $OUTPUT"
else
    echo "❌ 编译失败"
    exit 1
fi
