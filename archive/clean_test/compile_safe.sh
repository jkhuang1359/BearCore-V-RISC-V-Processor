#!/bin/bash
echo "安全编译脚本 v2.0"
echo "================"

# 1. 检查文件语法
echo "1. 检查语法..."
./check_verilog_pairs.sh

# 2. 检查必要文件
echo ""
echo "2. 检查必要文件..."
REQUIRED_FILES=("alu.v" "decoder.v" "reg_file.v" "rom.v" "data_ram.v" 
                "csr_registers.v" "uart_tx.v" "core.v")

MISSING=0
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ 缺少: $file"
        MISSING=1
    else
        echo "✅ $file"
    fi
done

if [ $MISSING -eq 1 ]; then
    echo "错误：缺少必要文件"
    exit 1
fi

# 3. 选择testbench
echo ""
echo "3. 选择testbench..."
if [ -f "tb_pc_fixed.v" ]; then
    TB_FILE="tb_pc_fixed.v"
    OUTPUT="pc_fixed.vvp"
    echo "使用: $TB_FILE"
elif [ -f "tb_pc_correct.v" ]; then
    TB_FILE="tb_pc_correct.v"
    OUTPUT="pc_correct.vvp"
    echo "使用: $TB_FILE"
else
    echo "创建简单testbench..."
    cat > tb_simple.v << 'SIMPLE_EOF'
`timescale 1ns/1ps
module tb_simple;
    reg clk; reg rst_n;
    core u_core(.clk(clk), .rst_n(rst_n), .uart_tx_o());
    always #50 clk = ~clk;
    integer cycle = 0;
    always @(posedge clk) if (rst_n) begin
        cycle = cycle + 1;
        $display("周期 %0d: PC = 0x%08h", cycle, u_core.pc);
        if (cycle > 30) $finish;
    end
    initial begin
        $dumpfile("simple.vcd"); $dumpvars(0, tb_simple);
        clk = 0; rst_n = 0; #200; rst_n = 1; #5000; $finish;
    end
endmodule
SIMPLE_EOF
    TB_FILE="tb_simple.v"
    OUTPUT="simple.vvp"
fi

# 4. 编译
echo ""
echo "4. 编译..."
echo "命令: iverilog -o $OUTPUT $TB_FILE ${REQUIRED_FILES[*]}"

# 先尝试语法检查
iverilog -t null $TB_FILE ${REQUIRED_FILES[*]} 2> syntax_check.log
if [ $? -ne 0 ]; then
    echo "❌ 语法检查失败"
    echo "错误信息:"
    cat syntax_check.log | head -30
    exit 1
fi

# 正式编译
iverilog -o $OUTPUT $TB_FILE ${REQUIRED_FILES[*]} 2> compile.log
if [ $? -eq 0 ]; then
    echo "✅ 编译成功"
    echo ""
    echo "运行仿真:"
    echo "  vvp $OUTPUT"
else
    echo "❌ 编译失败"
    echo "错误信息:"
    cat compile.log | head -30
    exit 1
fi
