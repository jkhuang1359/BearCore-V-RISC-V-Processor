`timescale 1ns/1ps
// ============================================
// BearCore-V Core Local Interrupt Controller (CLINT)
// ============================================
// 实现RISC-V标准的CLINT功能
// 包含：软件中断、定时器中断
// ============================================

`define DEBUG_CLINT 1

module clint #(
    parameter TIMER_BITS = 64,      // 定时器位数
    parameter TIMER_ADDR = 32'h0200_0000  // CLINT基地址
)(
    // 系统接口
    input wire          clk,
    input wire          rst_n,
    
    // 处理器总线接口
    input wire          bus_en,
    input wire          bus_we,
    input wire [31:0]   bus_addr,
    input wire [31:0]   bus_wdata,
    output reg [31:0]   bus_rdata,
    output reg          bus_ready,
    
    // 中断输出
    output wire         timer_irq_o,
    output wire         software_irq_o,
    
    // 配置信号
    input wire          irq_enable,     // 全局中断使能
    input wire [1:0]    timer_mode      // 定时器模式
);

// ============================================
// 内部寄存器定义
// ============================================

// CLINT寄存器地址偏移（RISC-V标准）
localparam MSIP_OFFSET  = 32'h0000;     // 软件中断等待寄存器
localparam MTIMECMP_OFFSET = 32'h4000;  // 定时器比较寄存器（64位）
localparam MTIME_OFFSET = 32'hBFF8;     // 定时器计数寄存器（64位）

// 64位定时器计数器
reg [63:0] mtime;      // 机器模式定时器计数
reg [63:0] mtimecmp;   // 机器模式定时器比较值
reg        msip;       // 机器模式软件中断等待

wire software_irq;
assign software_irq = msip && irq_enable;

// 输出中断信号
wire timer_irq;
// 软件中断信号（MSIP寄存器）
assign timer_irq = (mtime >= mtimecmp) && irq_enable;
assign software_irq_o = software_irq;
assign timer_irq_o = timer_irq;

// ============================================
// 总线接口逻辑
// ============================================

reg [1:0] bus_state;
localparam BUS_IDLE   = 2'b00;
localparam BUS_READ   = 2'b01;
localparam BUS_WRITE  = 2'b10;
localparam BUS_RESP   = 2'b11;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bus_state <= BUS_IDLE;
        bus_ready <= 1'b0;
        bus_rdata <= 32'b0;
        
        // 初始化寄存器
        mtime <= 64'b0;
        mtimecmp <= 64'd100; // 默认不触发中断
        msip <= 1'b0;
    end else begin
        case (bus_state)
            BUS_IDLE: begin
                bus_ready <= 1'b0;
                if (bus_en && (bus_addr >= TIMER_ADDR) && 
                    (bus_addr < TIMER_ADDR + 32'h10000)) begin
                    if (bus_we) begin
                        bus_state <= BUS_WRITE;
                    end else begin
                        bus_state <= BUS_READ;
                    end
                end
            end
            
            BUS_READ: begin
                // 读取寄存器
                case (bus_addr - TIMER_ADDR)
                    MSIP_OFFSET: bus_rdata <= {31'b0, msip};
                    MTIMECMP_OFFSET: bus_rdata <= mtimecmp[31:0];
                    MTIMECMP_OFFSET + 4: bus_rdata <= mtimecmp[63:32];
                    MTIME_OFFSET: bus_rdata <= mtime[31:0];
                    MTIME_OFFSET + 4: bus_rdata <= mtime[63:32];
                    default: bus_rdata <= 32'b0;
                endcase
                bus_state <= BUS_RESP;
            end
            
            BUS_WRITE: begin
                // 写入寄存器
                case (bus_addr - TIMER_ADDR)
                    MSIP_OFFSET: msip <= bus_wdata[0];
                    MTIMECMP_OFFSET: mtimecmp[31:0] <= bus_wdata;
                    MTIMECMP_OFFSET + 4: mtimecmp[63:32] <= bus_wdata;
                    // mtime是只读的，由硬件递增
                    default: ; // 忽略其他地址
                endcase
                bus_state <= BUS_RESP;
            end
            
            BUS_RESP: begin
                bus_ready <= 1'b1;
                bus_state <= BUS_IDLE;
            end
        endcase
    end
end

// ============================================
// 定时器计数器逻辑
// ============================================

reg [63:0] mtime_next;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mtime <= 64'b0;
        mtime_next <= 64'b0;
    end else begin
        // 计算下一个定时器值
        mtime_next <= mtime + 1;
        
        // 检查是否溢出（当mtime为最大值时）
        if (mtime == 64'hFFFFFFFFFFFFFFFF) begin
            mtime <= 64'b0;
        end else begin
            mtime <= mtime_next;
        end

    end
end

// ============================================
// 定时器模式处理
// ============================================

// 定时器模式：
// 00: 单次触发模式（到达比较值后停止）
// 01: 周期性模式（到达后自动重置）
// 10: 连续递增模式（到达后继续，需要手动更新比较值）
// 11: 保留

reg [63:0] period;  // 周期值（用于周期性模式）

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        period <= 64'd1000;  // 默认1kHz（假设100MHz时钟）
    end else if (timer_mode == 2'b01 && timer_irq) begin
        // 周期性模式：到达比较值后自动设置为下一个周期
        mtimecmp <= mtime + period;
    end
end

// ============================================
// 软件中断控制任务
// ============================================

// 触发软件中断（可从外部调用）
task trigger_software_irq;
begin
    msip <= 1'b1;
end
endtask

// 清除软件中断
task clear_software_irq;
begin
    msip <= 1'b0;
end
endtask

// ============================================
// 调试输出
// ============================================

`ifdef DEBUG_CLINT
always @(posedge clk) begin
    if (timer_irq) begin
        $display("[CLINT] Timer interrupt triggered at time %0d", mtime);
    end
    if (software_irq) begin
        $display("[CLINT] Software interrupt triggered");
    end
end
`endif

// 调试：显示定时器值
// always @(posedge clk) begin
//     if (mtime[5:0] == 6'b0)  // 每64个周期显示一次
//         $display("[CLINT] MTIME = %0d", mtime);
// end

endmodule