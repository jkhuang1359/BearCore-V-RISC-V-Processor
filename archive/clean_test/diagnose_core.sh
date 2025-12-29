#!/bin/bash
echo "核心诊断脚本"
echo "============"

echo "1. 检查数据前推问题..."
echo "   问题: BEQ在ID阶段读取到旧的寄存器值"
echo "   原因: addi指令结果还未写回寄存器文件"
echo "   解决: 检查core.v中的前推逻辑"

echo ""
echo "2. 检查关键信号路径:"
echo "   - ex_alu_zero: ALU零标志"
echo "   - ex_take_branch: 分支跳转信号"
echo "   - fwd_rs1, fwd_rs2: 前推数据"
echo "   - branch_met: 分支条件满足"

echo ""
echo "3. 建议调试步骤:"
echo "   a. 查看波形中的寄存器值"
echo "   b. 检查前推逻辑是否正确"
echo "   c. 验证ALU比较结果"
echo "   d. 确认分支目标地址计算"

echo ""
echo "4. 快速检查命令:"
echo "   gtkwave ${1:-auto_gen}.vcd"
