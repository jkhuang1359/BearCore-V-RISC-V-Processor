`timescale 1ns/1ps

module test_interrupt_system;
    reg clk;
    reg rst_n;
    
    // CLINT信号
    wire clint_timer_irq;
    wire clint_software_irq;
    
    // PLIC信号
    reg [15:0] plic_irq_sources;
    
    // 配置总线
    reg cfg_en;
    reg cfg_we;
    reg [31:0] cfg_addr;
    reg [31:0] cfg_wdata;
    wire [31:0] cfg_rdata;
    wire cfg_ready;
    
    // 中断输出
    wire irq_to_core;
    wire [4:0] irq_cause;
    wire [31:0] irq_extra;
    
    // 核心响应
    reg irq_ack;
    reg irq_complete;
    
    // 实例化中断仲裁器
    interrupt_arbiter #(
        .PLIC_NUM_SOURCES(16)
    ) u_interrupt_arbiter (
        .clk(clk),
        .rst_n(rst_n),
        .clint_timer_irq_i(clint_timer_irq),
        .clint_software_irq_i(clint_software_irq),
        .plic_irq_sources_i(plic_irq_sources),
        .cfg_en(cfg_en),
        .cfg_we(cfg_we),
        .cfg_addr(cfg_addr),
        .cfg_wdata(cfg_wdata),
        .cfg_rdata(cfg_rdata),
        .cfg_ready(cfg_ready),
        .irq_o(irq_to_core),
        .irq_cause_o(irq_cause),
        .irq_extra_o(irq_extra),
        .irq_ack_i(irq_ack),
        .irq_complete_i(irq_complete)
    );
    
    // 模拟CLINT
    reg [63:0] clint_counter;
    reg [63:0] clint_compare;
    reg clint_msip;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clint_counter <= 64'b0;
            clint_compare <= 64'hFFFFFFFFFFFFFFFF;
            clint_msip <= 1'b0;
        end else begin
            clint_counter <= clint_counter + 1;
            
            // 模拟配置写入
            if (cfg_en && cfg_we) begin
                case (cfg_addr)
                    32'h02000000: clint_msip <= cfg_wdata[0];
                    32'h02004000: clint_compare[31:0] <= cfg_wdata;
                    32'h02004004: clint_compare[63:32] <= cfg_wdata;
                endcase
            end
        end
    end
    
    assign clint_timer_irq = (clint_counter >= clint_compare);
    assign clint_software_irq = clint_msip;
    
    // 时钟生成
    always #5 clk = ~clk;
    
    // 配置任务
    task write_config;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            cfg_en = 1'b1;
            cfg_we = 1'b1;
            cfg_addr = addr;
            cfg_wdata = data;
            @(posedge clk);
            while (!cfg_ready) @(posedge clk);
            cfg_en = 1'b0;
            cfg_we = 1'b0;
            #10;
        end
    endtask
    
    task read_config;
        input [31:0] addr;
        output [31:0] data;
        begin
            @(posedge clk);
            cfg_en = 1'b1;
            cfg_we = 1'b0;
            cfg_addr = addr;
            @(posedge clk);
            while (!cfg_ready) @(posedge clk);
            data = cfg_rdata;
            cfg_en = 1'b0;
            #10;
        end
    endtask
    
    initial begin
        $dumpfile("interrupt_system_test.vcd");
        $dumpvars(0, test_interrupt_system);
        
        // 初始化
        clk = 0;
        rst_n = 0;
        plic_irq_sources = 16'b0;
        cfg_en = 0;
        cfg_we = 0;
        cfg_addr = 0;
        cfg_wdata = 0;
        irq_ack = 0;
        irq_complete = 0;
        
        // 复位
        #20 rst_n = 1;
        
        $display("=== 中断系统独立测试开始 ===");
        
        // 测试1：软件中断
        $display("\n测试1：软件中断");
        write_config(32'h02000000, 32'h1);  // 触发软件中断
        #50;
        
        if (irq_to_core && irq_cause == 5'h03) begin
            $display("  ✅ 软件中断仲裁成功");
            // 模拟核心响应
            irq_ack = 1;
            #10 irq_ack = 0;
            #50 irq_complete = 1;
            #10 irq_complete = 0;
        end else begin
            $display("  ❌ 软件中断仲裁失败");
        end
        
        // 测试2：定时器中断
        $display("\n测试2：定时器中断");
        write_config(32'h02004000, 32'h00000064);  // 设置比较值=100
        #200;  // 等待定时器触发
        
        if (irq_to_core && irq_cause == 5'h07) begin
            $display("  ✅ 定时器中断仲裁成功");
            irq_ack = 1;
            #10 irq_ack = 0;
            #50 irq_complete = 1;
            #10 irq_complete = 0;
        end else begin
            $display("  ❌ 定时器中断仲裁失败");
        end
        
        // 测试3：外部中断（PLIC）
        $display("\n测试3：外部中断（PLIC）");
        write_config(32'h0C000000, 32'h3);  // 设置中断源1优先级=3
        write_config(32'h0C002000, 32'h1);  // 使能中断源1
        write_config(32'h0C002000, 32'h1);  // 设置阈值=1
        
        // 触发外部中断
        plic_irq_sources[1] = 1'b1;
        #50;
        
        if (irq_to_core && irq_cause == 5'h0B) begin
            $display("  ✅ 外部中断仲裁成功，ID=0x%h", irq_extra);
            irq_ack = 1;
            #10 irq_ack = 0;
            #50 irq_complete = 1;
            #10 irq_complete = 0;
            plic_irq_sources[1] = 1'b0;
        end else begin
            $display("  ❌ 外部中断仲裁失败");
        end
        
        // 测试4：中断优先级
        $display("\n测试4：中断优先级测试");
        // 同时触发多个中断
        write_config(32'h02000000, 32'h1);  // 软件中断
        write_config(32'h02004000, 32'h0000000A);  // 定时器比较值=10
        plic_irq_sources[2] = 1'b1;  // 外部中断
        
        #20;
        if (irq_to_core) begin
            $display("  当前最高优先级中断: cause=%0d", irq_cause);
            // 定时器中断优先级最高（7），应该最先被响应
            if (irq_cause == 5'h07) $display("  ✅ 定时器中断优先级最高");
            else $display("  ❌ 优先级仲裁错误");
        end
        
        $display("\n=== 中断系统独立测试完成 ===");
        
        #100 $finish;
    end
    
    // 监视中断信号
    always @(posedge clk) begin
        if (irq_to_core) begin
            $display("[%0t] 中断请求: cause=%0d, extra=0x%08h", 
                     $time, irq_cause, irq_extra);
        end
    end
    
endmodule