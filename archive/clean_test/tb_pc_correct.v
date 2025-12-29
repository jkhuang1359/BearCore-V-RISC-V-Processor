`timescale 1ns/1ps

module tb_pc_correct;
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
    // 正确的变量声明位置（在always/initial块外）
    // ========================================
    integer cycle;
    reg [31:0] last_pc;
    integer error_count;
    
    // 初始化变量
    initial begin
        cycle = 0;
        last_pc = 0;
        error_count = 0;
    end
    
    // PC监控
    always @(posedge clk) begin
        if (rst_n) begin
            cycle = cycle + 1;
            $display("周期 %0d: PC = 0x%08h", cycle, u_core.pc);
            
            // 检查PC是否合理变化
            if (cycle > 1) begin // 從第二個有效週期開始檢查
                if (u_core.pc != last_pc + 4) begin
                    // 情況 A: 跳轉發生
                    $display("  PC变化: 0x%08h -> 0x%08h", last_pc, u_core.pc);
                    
                    if (u_core.pc == 32'h00000000 && last_pc == 32'h00000028) begin
                        $display("  ✅ 正常跳转: 0x28 -> 0x00");
                    end else begin
                        $display("  ⚠️  非标准变化 (疑似跳轉或異常)");
                        error_count = error_count + 1;
                    end
                end else begin
                    // 情況 B: 正常 PC + 4
                    $display("  ✅ 正常递增: +4");
                end
            end
            
            last_pc = u_core.pc;
            
            // 安全停止
            if (cycle > 20) begin
                $display("========================================");
                $display("诊断完成，发现 %0d 个错误", error_count);
                if (error_count == 0) $display("✅ PC行为基本正常！");
                $display("========================================");
                $finish;
            end
        end
    end
    
    initial begin
        $dumpfile("pc_correct.vcd");
        $dumpvars(0, tb_pc_correct);
        
        clk = 0;
        rst_n = 0;
        
        $display("========================================");
        $display("PC行为诊断测试");
        $display("========================================");
        
        // 复位
        #200;
        rst_n = 1;
        
        // 运行足够时间
        #5000;
        $finish;
    end
endmodule
