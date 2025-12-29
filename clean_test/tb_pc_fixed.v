`timescale 1ns/1ps

module tb_pc_fixed;
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
    // 变量声明（在always/initial块外）
    // ========================================
    integer cycle;
    reg [31:0] last_pc;
    integer error_count;
    
    // 初始化
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
            if (cycle > 0) begin
                // 正常情况：PC+4，或者跳转
                if (u_core.pc != last_pc + 4) begin
                    // 如果不是+4，检查是否是跳转指令
                    $display("  PC变化: 0x%08h -> 0x%08h", last_pc, u_core.pc);
                    
                    // 检查是否是预期的跳转
                    if (u_core.pc == 32'h00000000 && last_pc == 32'h00000028) begin
                        $display("  ✅ 正常跳转: 0x28 -> 0x00");
                    end else if (u_core.pc == 32'h00000004 && last_pc == 32'h00000000) begin
                        $display("  ✅ 正常递增: 0x00 -> 0x04");
                    end else begin
                        $display("  ⚠️  非标准变化 (疑似跳转或异常)");
                        error_count = error_count + 1;
                    end
                end else begin
                    // 正常递增情况
                    $display("  ✅ 正常递增: +4");
                end
            end
            
            last_pc = u_core.pc;
            
            // 安全停止
            if (cycle > 30) begin
                $display("========================================");
                $display("诊断完成，发现 %0d 个错误", error_count);
                if (error_count == 0) begin
                    $display("✅ PC行为正常！");
                end
                $finish;
            end
        end
    end
    
    initial begin
        $dumpfile("pc_fixed.vcd");
        $dumpvars(0, tb_pc_fixed);
        
        clk = 0;
        rst_n = 0;
        
        $display("========================================");
        $display("PC行为诊断测试 (修正版)");
        $display("========================================");
        
        // 复位
        #200;
        rst_n = 1;
        
        // 运行足够时间
        #10000;
        $finish;
    end
    
    // 监控BEQ执行情况
    always @(posedge clk) begin
        if (rst_n) begin
            // 检查BEQ指令执行情况
            case (u_core.pc)
                32'h00000010: $display("🎯 执行BEQ指令 (PC=0x10)");
                32'h00000020: $display("🎯 到达equal标签 (PC=0x20) - BEQ应跳转到这里");
                32'h00000014: $display("❌ 进入错误分支 (PC=0x14) - BEQ未跳转");
                32'h00000038: $display("🎯 执行第二个BEQ (PC=0x38) - 应不跳转");
                32'h00000048: $display("❌ 进入should_not_jump (PC=0x48) - 第二个BEQ错误跳转");
                32'h0000003c: $display("✅ 第二个BEQ正确不跳转 (PC=0x3c)");
                32'h00000060: $display("🏁 到达程序终点 (PC=0x60)");
            endcase
        end
    end
endmodule
