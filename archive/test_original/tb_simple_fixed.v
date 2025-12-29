`timescale 1ns/1ps

module tb_simple;
    reg clk;
    reg rst_n;
    wire uart_tx;
    
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx_o(uart_tx)
    );
    
    // 時鐘生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // 簡單的 UART 接收器，只顯示字符
    parameter BIT_PERIOD = 8680;
    
    reg [7:0] uart_data;
    integer uart_i;
    
    always @(negedge uart_tx) begin
        #(BIT_PERIOD * 1.5);
        
        for (uart_i = 0; uart_i < 8; uart_i = uart_i + 1) begin
            uart_data[uart_i] = uart_tx;
            #BIT_PERIOD;
        end
        
        $write("UART輸出: '%c' (0x%h)\n", uart_data, uart_data);
        $fflush();
    end
    
    // 主測試
    initial begin
        integer i;
        
        // 創建波形文件
        $dumpfile("original_core_fixed.vcd");
        $dumpvars(0, tb_simple);
        
        $display("========================================");
        $display("原始核心測試（修復版）");
        $display("========================================");
        
        // 復位
        rst_n = 0;
        #100;
        rst_n = 1;
        $display("[%0t] 復位釋放", $time);
        
        // 運行 1000 個週期
        for (i = 0; i < 1000; i = i + 1) begin
            @(posedge clk);
            
            // 每 100 個週期報告一次
            if (i % 100 == 0) begin
                $display("[%0t] 週期 %0d", $time, i);
            end
        end
        
        $display("[%0t] 測試完成，運行 1000 個週期", $time);
        $display("========================================");
        #1000000
        $finish;
    end
    
    // 監視 PC 變化（前100個週期）
    integer pc_monitor_count = 0;
    
    always @(posedge clk) begin
        if (pc_monitor_count < 100) begin
            $display("[%0t] PC = 0x%08h, instr = 0x%08h", $time, u_core.pc, u_core.id_inst);
            pc_monitor_count = pc_monitor_count + 1;
        end
    end
    
endmodule
