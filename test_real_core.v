`timescale 1ns/1ps

module test_real_core;
    reg clk;
    reg rst_n;
    wire uart_tx;
    
    // 實例化核心
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx_o(uart_tx)
    );
    
    // 時鐘生成 (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // 主測試流程
    initial begin
        integer i;
        
        // 創建波形文件
        $dumpfile("real_core.vcd");
        $dumpvars(0, test_real_core);
        
        $display("========================================");
        $display("真實核心測試開始");
        $display("========================================");
        
        // 初始狀態
        rst_n = 0;
        $display("[%0t] 系統復位中...", $time);
        
        // 保持復位 10 個時鐘週期
        repeat (10) @(posedge clk);
        
        // 釋放復位
        rst_n = 1;
        $display("[%0t] 釋放復位，開始執行程序", $time);
        
        // 運行 50 個時鐘週期並監視 PC
        for (i = 0; i < 50; i = i + 1) begin
            @(posedge clk);
            
            // 每 5 個週期報告一次狀態
            if (i % 5 == 0) begin
                $display("[%0t] 週期 %0d: PC = 0x%08h", 
                        $time, i, u_core.pc);
            end
            
            // 如果 PC 停止變化，提前結束
            if (i > 10 && u_core.pc == u_core.pc) begin
                // 檢查是否卡住
                if (u_core.pc == u_core.pc) begin
                    $display("[%0t] PC 卡在 0x%08h，提前結束", 
                            $time, u_core.pc);
                    break;
                end
            end
        end
        
        $display("[%0t] 測試完成", $time);
        $display("========================================");
        $finish;
    end
    
endmodule
