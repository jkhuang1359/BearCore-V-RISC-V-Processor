`timescale 1ns/1ps

module tb_if_debug;
    reg clk;
    reg rst_n;
    
    // 实例化核心
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx_o()
    );
    
    // 时钟 (10MHz)
    always #50 clk = ~clk;
    
    // ========================================
    // 测试变量声明（在initial块外）
    // ========================================
    integer cycle = 0;
    integer error_count = 0;
    reg [31:0] expected_pc;
    
    // 访问ROM信号
    wire [31:0] rom_inst;
    assign rom_inst = u_core.u_rom.inst;  // 直接从ROM读取
    
    // 访问核心的if_inst信号
    wire [31:0] core_if_inst;
    assign core_if_inst = u_core.if_inst;
    
    // PC监控
    always @(posedge clk) begin
        if (rst_n) begin
            cycle <= cycle + 1;
            expected_pc <= (cycle * 4);  // 期望的PC值
            
            $display("周期 %0d:", cycle);
            $display("  核心PC = 0x%08h", u_core.pc);
            $display("  ROM输出 = 0x%08h", rom_inst);
            $display("  核心IF指令 = 0x%08h", core_if_inst);
            
            // 检查PC是否正确递增
            if (cycle > 0 && u_core.pc != expected_pc) begin
                $display("  ❌ PC错误: 期望 0x%08h, 得到 0x%08h", 
                        expected_pc, u_core.pc);
                error_count <= error_count + 1;
            end
            
            // 检查ROM输出和核心IF指令是否一致
            if (rom_inst !== core_if_inst) begin
                $display("  ❌ 指令不一致: ROM=0x%08h, 核心IF=0x%08h", 
                        rom_inst, core_if_inst);
                error_count <= error_count + 1;
            end
            
            $display("");
            
            // 安全停止
            if (cycle > 15) begin
                $display("诊断完成，发现 %0d 个错误", error_count);
                $finish;
            end
        end
    end
    
    initial begin
        $dumpfile("if_debug.vcd");
        $dumpvars(0, tb_if_debug);
        
        clk = 0;
        rst_n = 0;
        
        $display("========================================");
        $display("IF阶段诊断测试");
        $display("检查PC递增和指令读取");
        $display("========================================");
        
        // 复位
        #200;
        rst_n = 1;
        
        // 运行足够时间
        #5000;
        $finish;
    end
    
    integer i;
    // 监控ROM内容
    initial begin
        #100;  // 等待复位
        $display("检查ROM内存前16个字：");
        for (i = 0; i < 16; i = i + 1) begin
            $display("  ROM[%0d] = 0x%08h", i, u_core.u_rom.mem[i]);
        end
        $display("");
    end
endmodule
