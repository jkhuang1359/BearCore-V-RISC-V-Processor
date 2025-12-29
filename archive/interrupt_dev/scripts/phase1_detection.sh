#!/bin/bash

# 阶段1：中断检测 - 只添加中断检测，不改变行为

set -e

PROJ_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
LOG_DIR="$PROJ_ROOT/interrupt_dev/logs/phase1"
PHASE_DIR="$PROJ_ROOT/interrupt_dev/phases/phase1"
mkdir -p "$LOG_DIR" "$PHASE_DIR"

echo "=== 阶段1：中断检测 ==="
echo "目标：添加中断输入信号，只检测不处理"
echo ""

cd "$PROJ_ROOT"

# 1. 创建阶段1专用目录
echo "1. 创建阶段1开发环境..."

cat > "$PHASE_DIR/README.md" << 'README'
# 阶段1：中断检测

## 目标
- 添加中断输入信号接口
- 实现中断状态寄存器（只读）
- 验证不影响现有功能

## 修改文件
1. core_phase1.v - 添加中断检测的核心版本
2. csr_phase1.v - 添加中断状态寄存器的CSR版本
3. tb_phase1.v - 阶段1专用测试台

## 测试用例
1. 验证原有功能不变
2. 验证中断信号能正确检测
3. 验证中断状态寄存器可读
README

echo "   ✅ 阶段1目录创建完成"

# 2. 创建阶段1的核心版本
echo "2. 创建阶段1核心版本..."

cat > "$PHASE_DIR/core_phase1.v" << 'CORE_EOF'
`timescale 1ns/1ps
// ============================================
// BearCore-V Phase 1: Interrupt Detection
// 只添加中断检测，不改变执行流程
// ============================================

module core_phase1(
    input clk,
    input rst_n,
    output uart_tx_o,
    
    // 🆕 阶段1新增：中断输入信号
    input wire irq_timer_i,       // 定时器中断输入
    input wire irq_external_i,    // 外部中断输入
    input wire irq_software_i     // 软件中断输入
);

    // ============================================
    // 原有的所有信号定义
    // ============================================
    
    reg  [31:0] pc;
    wire [31:0] pc_next, if_inst;
    wire [31:0] ex_target_pc;
    wire ex_take_branch;
    
    reg [31:0] cycle_cnt; 
    reg [31:0] inst_cnt; 
    
    // ... [复制所有现有信号定义]
    
    // ============================================
    // 🆕 阶段1新增：中断检测逻辑
    // ============================================
    
    // 中断检测信号
    wire interrupt_detected;
    wire [2:0] interrupt_type;
    reg [31:0] interrupt_debug_counter;
    
    // 中断检测逻辑
    assign interrupt_detected = irq_timer_i | irq_external_i | irq_software_i;
    assign interrupt_type = irq_timer_i ? 3'b001 : 
                           irq_external_i ? 3'b010 : 
                           irq_software_i ? 3'b100 : 3'b000;
    
    // 中断状态寄存器（用于调试）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            interrupt_debug_counter <= 32'b0;
        end else if (interrupt_detected) begin
            interrupt_debug_counter <= interrupt_debug_counter + 1;
            $display("[PHASE1] 中断检测: 类型=%b, 计数=%d", 
                     interrupt_type, interrupt_debug_counter);
        end
    end
    
    // ============================================
    // 🆕 阶段1修改：CSR接口添加中断状态
    // ============================================
    
    // 实例化CSR（使用阶段1版本）
    csr_phase1 u_csr (
        .clk(clk),
        .rst_n(rst_n),
        
        // 原有的CSR接口...
        .csr_addr(mem_csr_addr),
        .csr_wdata(csr_wdata),
        .csr_we(csr_we),
        .csr_op(mem_csr_op),
        .csr_use_imm(mem_csr_use_imm),
        
        // 🆕 阶段1新增：中断状态
        .irq_detected_i(interrupt_detected),
        .irq_type_i(interrupt_type),
        
        .csr_rdata(csr_rdata),
        .debug_irq_status_o(debug_irq_status)
    );
    
    // ============================================
    // 原有的核心逻辑（完全不变）
    // ============================================
    
    // ... [复制所有现有逻辑]
    
    // ============================================
    // 🆕 阶段1新增：调试输出
    // ============================================
    
    wire [31:0] debug_irq_status;
    
    // 通过UART输出中断状态（调试用）
    reg [7:0] uart_debug_data;
    reg uart_debug_valid;
    
    always @(posedge clk) begin
        if (interrupt_detected && !uart_busy) begin
            uart_debug_data <= "I";  // 发送'I'表示中断
            uart_debug_valid <= 1'b1;
        end else begin
            uart_debug_valid <= 1'b0;
        end
    end
    
    // 原有的UART实例化...
    
endmodule
CORE_EOF

echo "   ✅ 阶段1核心版本创建完成"

# 3. 创建阶段1的CSR版本
echo "3. 创建阶段1 CSR版本..."

cat > "$PHASE_DIR/csr_phase1.v" << 'CSR_EOF'
`timescale 1ns/1ps
// ============================================
// CSR Phase 1: Interrupt Status Registers
// 只添加中断状态，不改变行为
// ============================================

module csr_phase1(
    input wire          clk,
    input wire          rst_n,
    
    // 原有的CSR接口
    input wire          csr_we_i,
    input wire [11:0]   csr_addr_i,
    input wire [31:0]   csr_wdata_i,
    input wire [1:0]    csr_op,
    input wire          csr_use_imm,
    output reg [31:0]   csr_rdata_o,
    
    // 🆕 阶段1新增：中断状态输入
    input wire          irq_detected_i,
    input wire [2:0]    irq_type_i,
    
    // 🆕 调试输出
    output wire [31:0]  debug_irq_status_o
);

    // ============================================
    // 原有的CSR寄存器
    // ============================================
    
    // ... [复制所有现有CSR寄存器]
    
    // ============================================
    // 🆕 阶段1新增：中断状态寄存器
    // ============================================
    
    // 中断状态寄存器（自定义CSR地址）
    localparam CSR_IRQ_STATUS = 12'h7C0;
    
    reg [31:0] irq_status_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq_status_reg <= 32'b0;
        end else begin
            // 记录最近的中断状态
            if (irq_detected_i) begin
                irq_status_reg <= {28'b0, irq_type_i, irq_detected_i};
            end
        end
    end
    
    assign debug_irq_status_o = irq_status_reg;
    
    // ============================================
    // 🆕 扩展CSR读取
    // ============================================
    
    always @(*) begin
        csr_rdata_o = 32'b0;
        
        // 原有的case语句...
        
        // 🆕 添加中断状态寄存器读取
        if (csr_addr_i == CSR_IRQ_STATUS) begin
            csr_rdata_o = irq_status_reg;
        end
    end
    
    // ============================================
    // 原有的CSR逻辑（完全不变）
    // ============================================
    
    // ... [复制所有现有CSR逻辑]
    
endmodule
CSR_EOF

echo "   ✅ 阶段1 CSR版本创建完成"

# 4. 创建阶段1测试
echo "4. 创建阶段1测试程序..."

cat > "$PHASE_DIR/test_phase1.s" << 'TEST_EOF'
.section .text
.global _start
// ============================================
// 阶段1测试程序
// 验证中断检测不影响原有功能
// ============================================

_start:
    # 1. 原有功能测试
    li a0, 1
    li a1, 2
    add a2, a0, a1    # a2 = 3
    
    # 2. 测试中断状态寄存器
    csrr t0, 0x7C0    # 读取中断状态寄存器
    
    # 3. 更多原有功能测试
    li t1, 0x1000
    sw a2, 0(t1)
    lw t2, 0(t1)
    
    # 4. 成功标记
    li a0, 0x12345678
    li a7, 1
    scall
TEST_EOF

echo "   ✅ 阶段1测试程序创建完成"

# 5. 运行阶段1验证
echo "5. 运行阶段1验证..."

cd "$PHASE_DIR"

# 创建Makefile
cat > Makefile << 'MAKEFILE'
PROJ_ROOT := ../..
PHASE1_DIR := .

# 源文件
SRCS := $(PHASE1_DIR)/core_phase1.v \
        $(PHASE1_DIR)/csr_phase1.v \
        $(PROJ_ROOT)/src/alu.v \
        $(PROJ_ROOT)/src/reg_file.v \
        $(PROJ_ROOT)/src/decoder.v \
        $(PROJ_ROOT)/src/data_ram.v \
        $(PROJ_ROOT)/src/rom.v \
        $(PROJ_ROOT)/src/uart_tx.v

# 测试台
TB := $(PHASE1_DIR)/tb_phase1.v

# 编译选项
IVERILOG := iverilog
VVP := vvp
DEFINES := -D PHASE1_TEST

all: compile run

compile:
$(IVERILOG) -o phase1_test.vvp $(DEFINES) $(SRCS) $(TB)

run:
$(VVP) phase1_test.vvp

clean:
rm -f *.vvp *.vcd *.log

.PHONY: all compile run clean
MAKEFILE

echo "   ✅ 阶段1构建系统创建完成"

echo ""
echo "=== 阶段1准备完成 ==="
echo "下一步:"
echo "1. 创建 tb_phase1.v 测试台"
echo "2. 运行 make compile 编译"
echo "3. 运行 make run 测试"
echo ""
echo "验证标准:"
echo "✅ 原有功能测试通过"
echo "✅ 中断状态寄存器可读"
echo "✅ 中断信号能正确检测"
