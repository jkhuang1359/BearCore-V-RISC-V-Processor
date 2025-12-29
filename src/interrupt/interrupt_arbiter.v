`timescale 1ns/1ps
// ============================================
// BearCore-V Interrupt Arbiter
// ============================================
// 集成CLINT和PLIC中断，处理中断优先级和路由
// ============================================

module interrupt_arbiter #(
    parameter PLIC_NUM_SOURCES = 16
)(
    // 系统接口
    input wire          clk,
    input wire          rst_n,
    
    // 中断源输入
    input wire          clint_timer_irq_i,
    input wire          clint_software_irq_i,
    input wire [PLIC_NUM_SOURCES-1:0] plic_irq_sources_i,
    
    // 配置接口
    input wire          cfg_en,
    input wire          cfg_we,
    input wire [31:0]   cfg_addr,
    input wire [31:0]   cfg_wdata,
    output wire [31:0]  cfg_rdata,
    output wire         cfg_ready,
    
    // 中断输出到核心
    output wire         irq_o,          // 中断请求
    output wire [4:0]   irq_cause_o,    // 中断原因
    output wire [31:0]  irq_extra_o,    // 额外信息（如PLIC中断ID）
    
    // 核心响应
    input wire          irq_ack_i,      // 中断确认
    input wire          irq_complete_i  // 中断处理完成
);

// ============================================
// 中断优先级定义
// ============================================

// RISC-V标准中断优先级（数字越高优先级越高）
localparam PRIO_TIMER      = 4'h7;  // 定时器中断（最高）
localparam PRIO_SOFTWARE   = 4'h3;  // 软件中断
localparam PRIO_EXTERNAL   = 4'h1;  // 外部中断（PLIC）
localparam PRIO_NONE       = 4'h0;  // 无中断

// 中断原因编码（RISC-V标准）
localparam CAUSE_MSOFTWARE = 5'h03;  // 机器模式软件中断
localparam CAUSE_MTIMER    = 5'h07;  // 机器模式定时器中断
localparam CAUSE_MEXTERNAL = 5'h0B;  // 机器模式外部中断

// ============================================
// 模块实例化
// ============================================

// CLINT实例
wire clint_timer_irq;
wire clint_software_irq;
wire [31:0] clint_rdata;
wire clint_ready;

clint #(
    .TIMER_BITS(64),
    .TIMER_ADDR(32'h0200_0000)
) u_clint (
    .clk(clk),
    .rst_n(rst_n),
    .bus_en(cfg_en && cfg_addr >= 32'h0200_0000 && cfg_addr < 32'h0201_0000),
    .bus_we(cfg_we),
    .bus_addr(cfg_addr),
    .bus_wdata(cfg_wdata),
    .bus_rdata(clint_rdata),
    .bus_ready(clint_ready),
    .timer_irq_o(clint_timer_irq),
    .software_irq_o(clint_software_irq),
    .irq_enable(1'b1),
    .timer_mode(2'b01)
);

// PLIC实例
wire plic_irq;
wire [31:0] plic_irq_id;
wire [31:0] plic_rdata;
wire plic_ready;

plic #(
    .NUM_SOURCES(PLIC_NUM_SOURCES),
    .NUM_TARGETS(1),
    .PRIO_BITS(3)
) u_plic (
    .clk(clk),
    .rst_n(rst_n),
    .irq_sources_i(plic_irq_sources_i),
    .irq_o(plic_irq),
    .irq_id_o(plic_irq_id),
    .irq_complete_i(irq_complete_i),
    .cfg_en(cfg_en && cfg_addr >= 32'h0C00_0000 && cfg_addr < 32'h0C20_0000),
    .cfg_we(cfg_we),
    .cfg_addr(cfg_addr),
    .cfg_wdata(cfg_wdata),
    .cfg_rdata(plic_rdata),
    .cfg_ready(plic_ready)
);

// ============================================
// 中断仲裁逻辑
// ============================================

// 当前等待的中断
reg timer_irq_pending;
reg software_irq_pending;
reg external_irq_pending;
reg [31:0] external_irq_id;

// 中断优先级比较
reg [3:0] current_priority;
reg [4:0] current_cause;
reg [31:0] current_extra;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        timer_irq_pending <= 1'b0;
        software_irq_pending <= 1'b0;
        external_irq_pending <= 1'b0;
        external_irq_id <= 32'b0;
        current_priority <= PRIO_NONE;
        current_cause <= 5'b0;
        current_extra <= 32'b0;
    end else begin
        // 更新中断等待状态
        if (clint_timer_irq) timer_irq_pending <= 1'b1;
        if (clint_software_irq) software_irq_pending <= 1'b1;
        if (plic_irq) begin
            external_irq_pending <= 1'b1;
            external_irq_id <= plic_irq_id;
        end
        
        // 中断被确认时清除等待状态
        if (irq_ack_i) begin
            case (current_cause)
                CAUSE_MTIMER:    timer_irq_pending <= 1'b0;
                CAUSE_MSOFTWARE: software_irq_pending <= 1'b0;
                CAUSE_MEXTERNAL: external_irq_pending <= 1'b0;
            endcase
        end
        
        // 仲裁逻辑
        if (timer_irq_pending) begin
            current_priority <= PRIO_TIMER;
            current_cause <= CAUSE_MTIMER;
            current_extra <= 32'b0;
        end
        else if (software_irq_pending) begin
            current_priority <= PRIO_SOFTWARE;
            current_cause <= CAUSE_MSOFTWARE;
            current_extra <= 32'b0;
        end
        else if (external_irq_pending) begin
            current_priority <= PRIO_EXTERNAL;
            current_cause <= CAUSE_MEXTERNAL;
            current_extra <= external_irq_id;
        end
        else begin
            current_priority <= PRIO_NONE;
            current_cause <= 5'b0;
            current_extra <= 32'b0;
        end
    end
end

// 中断输出
assign irq_o = (current_priority != PRIO_NONE);
assign irq_cause_o = current_cause;
assign irq_extra_o = current_extra;

// 配置总线响应
assign cfg_rdata = clint_ready ? clint_rdata : 
                   plic_ready ? plic_rdata : 32'b0;
assign cfg_ready = clint_ready | plic_ready;

// ============================================
// 中断控制寄存器
// ============================================

// 全局中断使能寄存器
reg global_irq_enable;

// 中断使能掩码
reg [2:0] irq_enable_mask;  // bit2:外部, bit1:定时器, bit0:软件

// 中断状态寄存器
wire [2:0] irq_status = {external_irq_pending, timer_irq_pending, software_irq_pending};

// 配置寄存器访问
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        global_irq_enable <= 1'b0;
        irq_enable_mask <= 3'b111;  // 默认所有中断使能
    end else if (cfg_en && cfg_we) begin
        case (cfg_addr)
            32'h1000_0000: global_irq_enable <= cfg_wdata[0];  // 全局中断使能
            32'h1000_0004: irq_enable_mask <= cfg_wdata[2:0];  // 中断使能掩码
        endcase
    end
end

// ============================================
// 中断屏蔽逻辑
// ============================================

// 实际中断请求（考虑使能掩码）
wire actual_timer_irq = clint_timer_irq && irq_enable_mask[1];
wire actual_software_irq = clint_software_irq && irq_enable_mask[0];
wire actual_external_irq = plic_irq && irq_enable_mask[2];

// 替换原始中断信号
assign clint_timer_irq = actual_timer_irq;
assign clint_software_irq = actual_software_irq;
assign plic_irq = actual_external_irq;

// ============================================
// 嵌套中断支持
// ============================================

// 嵌套中断深度计数器
reg [1:0] irq_depth;
reg [4:0] saved_cause [0:3];
reg [31:0] saved_extra [0:3];

// 嵌套中断使能
reg nested_irq_enable;
integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        irq_depth <= 2'b0;
        nested_irq_enable <= 1'b0;
        for (i = 0; i < 4; i = i + 1) begin
            saved_cause[i] <= 5'b0;
            saved_extra[i] <= 32'b0;
        end
    end else begin
        if (irq_ack_i && nested_irq_enable) begin
            // 保存当前中断上下文
            if (irq_depth < 4) begin
                saved_cause[irq_depth] <= current_cause;
                saved_extra[irq_depth] <= current_extra;
                irq_depth <= irq_depth + 1;
            end
        end
        else if (irq_complete_i && irq_depth > 0) begin
            // 恢复上一级中断
            irq_depth <= irq_depth - 1;
        end
    end
end

// ============================================
// 调试输出
// ============================================

`ifdef DEBUG_INTERRUPT
always @(posedge clk) begin
    if (irq_o) begin
        $display("[INTERRUPT] IRQ asserted: cause=%0d, extra=0x%08h", 
                 current_cause, current_extra);
    end
    if (irq_ack_i) begin
        $display("[INTERRUPT] IRQ acknowledged");
    end
    if (irq_complete_i) begin
        $display("[INTERRUPT] IRQ complete");
    end
end
`endif

endmodule