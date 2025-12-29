`timescale 1ns/1ps

module tb_clean;
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
    
    // 简单的PC监控
    integer cycle = 0;
    reg [31:0] last_pc = 0;
    
    always @(posedge clk) begin
        if (rst_n) begin
            cycle <= cycle + 1;
            
            // 只显示前20个周期
            if (cycle < 20) begin
                $display("周期 %0d: PC = 0x%08h", cycle, u_core.pc);
            end
            
            last_pc <= u_core.pc;
            
            // 安全停止
            if (cycle > 100) begin
                $display("测试超时，停止仿真");
                $finish;
            end
        end
    end
    
    // 寄存器监控
    always @(posedge clk) begin
        if (rst_n && cycle > 5) begin
            // 通过层次化引用检查寄存器（如果支持）
            // 注意：这可能需要根据实际结构调整
            if (u_core.pc == 32'h0000001c) begin
                $display("检查点：PC到达0x1c");
            end
        end
    end
    
    initial begin
        $dumpfile("clean.vcd");
        $dumpvars(0, tb_clean);
        
        clk = 0;
        rst_n = 0;
        
        $display("========================");
        $display("清洁测试开始");
        $display("========================");
        
        // 复位
        #200;
        rst_n = 1;
        
        // 运行足够时间
        #10000;
        
        $display("========================");
        $display("测试完成");
        $display("========================");
        $finish;
    end
endmodule
