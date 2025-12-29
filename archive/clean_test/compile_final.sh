#!/bin/bash
# ==============================================================================
# 终极编译脚本 v4.0 - 修正数据前推和时序问题
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() { echo -e "${BLUE}## $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "ℹ️  $1"; }

clear
print_header "RISC-V CPU 终极编译脚本 v4.0"
echo "======================================"

# 1. 检查必要文件
print_header "1. 检查必要文件"
REQUIRED_FILES=("alu.v" "decoder.v" "reg_file.v" "rom.v" "data_ram.v" 
                "csr_registers.v" "uart_tx.v" "core.v")

missing_files=()
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_success "$file"
    else
        print_error "$file"
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -gt 0 ]; then
    print_error "缺少以下文件: ${missing_files[*]}"
    exit 1
fi

# 2. 检查语法需求
print_header "2. 检查语法需求"
if grep -r "integer.*:" *.v 2>/dev/null | grep -v "//.*integer" | head -3; then
    print_warning "检测到SystemVerilog语法，使用 -g2012"
    IVFLAGS="-g2012 -Wall"
else
    IVFLAGS="-Wall"
fi

# 3. 选择Testbench
print_header "3. 选择Testbench"
declare -A tb_map=(
    ["tb_pc_fixed.v"]="pc_fixed"
    ["tb_debug.v"]="debug" 
    ["tb_beq_diagnose.v"]="beq_diagnose"
    ["tb_simple.v"]="simple"
    ["tb_minimal.v"]="minimal"
)

selected_tb=""
selected_output=""

for tb in "${!tb_map[@]}"; do
    if [ -f "$tb" ]; then
        selected_tb="$tb"
        selected_output="${tb_map[$tb]}.vvp"
        print_success "选择: $tb -> $selected_output"
        break
    fi
done

if [ -z "$selected_tb" ]; then
    print_warning "未找到Testbench，创建简单版本..."
    cat > tb_auto_gen.v << 'AUTO_TB'
`timescale 1ns/1ps
module tb_auto_gen;
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
        $dumpfile("auto_gen.vcd");
        $dumpvars(0, tb_auto_gen);
        clk = 0; rst_n = 0;
        #200; rst_n = 1;
        #10000; $finish;
    end
endmodule
AUTO_TB
    selected_tb="tb_auto_gen.v"
    selected_output="auto_gen.vvp"
    print_success "已创建: $selected_tb"
fi

# 4. 检查firmware.hex
print_header "4. 检查firmware.hex"
if [ ! -f "firmware.hex" ]; then
    print_warning "未找到firmware.hex，创建简单测试程序..."
    
    # 创建简单的BEQ测试程序
    cat > create_test_program.sh << 'CREATE_EOF'
#!/bin/bash
cat > simple_test.s << 'ASM_EOF'
.text
.globl _start
_start:
    # 测试BEQ：相等跳转
    addi x1, x0, 1      # x1 = 1
    addi x2, x0, 1      # x2 = 1
    beq x1, x2, target  # 应该跳转
    
    # 不应该执行这里
    addi x10, x0, 0xBAD
    j end

target:
    # 跳转到这里
    addi x10, x0, 0x600D
    j end

end:
    j end
ASM_EOF

# 编译
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -Ttext=0x0 -o simple.elf simple_test.s
riscv64-unknown-elf-objcopy -O binary simple.elf simple.bin
hexdump -v -e '1/4 "%08x\n"' simple.bin > firmware.hex

echo "生成的firmware.hex:"
head -10 firmware.hex
CREATE_EOF
    
    chmod +x create_test_program.sh
    ./create_test_program.sh
else
    print_success "firmware.hex 已存在"
    echo "前10行:"
    head -10 firmware.hex
fi

# 5. 编译
print_header "5. 编译"
COMPILE_CMD="iverilog $IVFLAGS -o $selected_output $selected_tb ${REQUIRED_FILES[*]}"
print_info "编译命令:"
echo "  $COMPILE_CMD"

# 先语法检查
print_info "语法检查..."
if iverilog $IVFLAGS -t null $selected_tb ${REQUIRED_FILES[*]} 2>/dev/null; then
    print_success "语法检查通过"
else
    print_error "语法检查失败"
    iverilog $IVFLAGS -t null $selected_tb ${REQUIRED_FILES[*]} 2>&1 | head -20
    exit 1
fi

# 正式编译
print_info "正式编译..."
if eval "$COMPILE_CMD" 2>compile_errors.log; then
    print_success "编译成功!"
    
    # 检查警告
    warnings=$(grep -c "warning" compile_errors.log 2>/dev/null || echo 0)
    if [ "$warnings" -gt 0 ]; then
        print_warning "发现 $warnings 个警告"
        grep -i "warning" compile_errors.log | head -5
    fi
else
    print_error "编译失败"
    echo "错误信息:"
    cat compile_errors.log | head -30
    exit 1
fi

# 6. 创建运行脚本
print_header "6. 创建运行脚本"
cat > run_simulation.sh << 'RUN_EOF'
#!/bin/bash
echo "运行仿真..."
vvp "$1" 2>&1 | tee simulation.log

echo ""
echo "=== 仿真结果 ==="
echo "PC轨迹:"
grep -E "周期.*PC|PC.*=" simulation.log | head -15

echo ""
echo "关键事件:"
grep -E "BEQ|跳转|到达|进入" simulation.log | head -10

if grep -q "BEQ成功" simulation.log; then
    echo "✅ BEQ测试通过"
elif grep -q "BEQ未跳转" simulation.log; then
    echo "❌ BEQ测试失败"
fi

echo ""
echo "波形文件: ${1%.vvp}.vcd"
echo "查看波形: gtkwave ${1%.vvp}.vcd"
RUN_EOF

chmod +x run_simulation.sh

# 7. 创建诊断脚本
print_header "7. 创建诊断脚本"
cat > diagnose_core.sh << 'DIAG_EOF'
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
DIAG_EOF

chmod +x diagnose_core.sh

# 8. 完成
print_header "8. 完成准备"
print_success "编译完成: $selected_output"
print_success "测试程序: firmware.hex"
echo ""
echo "运行仿真:"
echo "  ./run_simulation.sh $selected_output"
echo ""
echo "诊断问题:"
echo "  ./diagnose_core.sh ${selected_output%.vvp}"
echo ""
echo "清理文件:"
echo "  rm -f *.vvp *.vcd *.log tb_auto_gen.v"

# 清理临时文件
rm -f compile_errors.log 2>/dev/null
rm -f create_test_program.sh 2>/dev/null
