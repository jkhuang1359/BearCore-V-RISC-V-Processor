`timescale 1ns/1ps
// ============================================
// BearCore-V with Basic Interrupt Support
// ============================================
// 第一步：先添加最基本的中断支持，不破坏现有功能
// ============================================

module core_with_interrupts(
    input clk,
    input rst_n,
    output uart_tx_o,
    
    // 🆕 中断输入（简化版）
    input wire external_irq_i,    // 外部中断输入
    input wire timer_irq_i        // 定时器中断输入
);

    // --- 原有的所有信号定义保持不变 ---
    // [这里复制您现有的core.v中的所有信号定义]
    
    // 🆕 新增中断相关信号
    wire interrupt_pending;
    wire [4:0] interrupt_cause;
    wire [31:0] interrupt_vector;
    wire global_interrupt_enable;
    wire [31:0] mepc_value;
    wire mret_signal;
    
    // 🆕 简易中断检测
    assign interrupt_pending = (timer_irq_i || external_irq_i) && global_interrupt_enable;
    assign interrupt_cause = timer_irq_i ? 5'h07 : 5'h0B; // 7=定时器, 11=外部
    
    // --- 实例化现有的CSR模块 ---
    csr_registers u_csr (
        .clk(clk),
        .rst_n(rst_n),
        
        // CSR 存取接口（保持不变）
        .csr_addr(mem_csr_addr),
        .csr_wdata(csr_wdata),
        .csr_we(csr_we),
        .csr_op(mem_csr_op),
        .csr_use_imm(mem_csr_use_imm),
        
        // 🆕 中断接口
        .irq_i(interrupt_pending),
        .irq_cause_i(interrupt_cause),
        .irq_extra_i(32'h0),
        .irq_enable_o(global_interrupt_enable),
        .irq_vector_o(interrupt_vector),
        
        // 🆕 异常接口（暂时简单处理）
        .exception_i(1'b0),
        .exception_code_i(4'b0),
        .exception_pc_i(32'b0),
        .exception_addr_i(32'b0),
        
        // 🆕 处理器状态
        .pc_i(ex_pc),
        .inst_i(id_inst), // 使用ID阶段的指令
        .mepc_o(mepc_value),
        .mret_o(mret_signal),
        .wfi_o(),
        
        // 🆕 定时器接口
        .mtime_o(),
        .mtime_i(64'b0),
        .mtime_we_i(1'b0),
        
        // 原有的输出（保持不变）
        .csr_rdata(csr_rdata),
        .mtvec(),
        .mepc(),
        .mie(),
        .timer_int(),
        .ext_int()
    );
    
    // --- 原有的核心逻辑保持不变 ---
    // [这里复制您现有的core.v中的所有逻辑]
    
    // 🆕 只在关键位置添加中断处理逻辑
    
    // 1. 修改PC选择逻辑，支持中断跳转
    wire [31:0] next_pc_with_interrupt;
    reg interrupt_taken;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            interrupt_taken <= 1'b0;
        end else if (interrupt_pending && !stall) begin
            interrupt_taken <= 1'b1;
        end else if (mret_signal) begin
            interrupt_taken <= 1'b0;
        end
    end
    
    // 简单的PC多路选择器
    assign next_pc_with_interrupt = 
        interrupt_taken ? interrupt_vector :
        mret_signal ? mepc_value :
        pc_next; // 原有的PC逻辑
    
    // 2. 修改流水线冲刷逻辑，中断时冲刷流水线
    wire pipeline_flush = interrupt_taken || mret_signal || ex_take_branch;
    
    // 3. 简单的调试输出
    always @(posedge clk) begin
        if (interrupt_taken) begin
            $display("[INTERRUPT] 进入中断处理，向量=0x%08h，原因=%0d", 
                     interrupt_vector, interrupt_cause);
        end
        if (mret_signal) begin
            $display("[INTERRUPT] 从中断返回，PC=0x%08h", mepc_value);
        end
    end
    
endmodule