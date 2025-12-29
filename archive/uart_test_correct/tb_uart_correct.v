`timescale 1ns/1ps

module tb_uart_correct;
    reg clk;
    reg rst_n;
    reg valid_i;
    reg [7:0] data_i;
    reg test_mode_i;
    wire busy_o;
    wire tx_o;
    
    // 實例化 UART TX 模塊
    uart_tx_correct u_uart (
        .clk(clk),
        .rst_n(rst_n),
        .data_i(data_i),
        .valid_i(valid_i),
        .test_mode_i(test_mode_i),
        .busy_o(busy_o),
        .tx_o(tx_o)
    );
    
    // 時鐘生成 (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // 主測試流程
    initial begin
        integer i;
        reg [7:0] received_char;
        
        // 創建波形文件
        $dumpfile("uart_correct.vcd");
        $dumpvars(0, tb_uart_correct);
        
        $display("========================================");
        $display("UART TX 正確測試");
        $display("========================================");
        
        // 初始化
        valid_i = 0;
        test_mode_i = 0;
        data_i = 8'h00;
        rst_n = 0;
        #100;
        rst_n = 1;
        #1000;
        
        $display("\n[%0t] 測試 1: 手動發送 'A' (0x41)", $time);
        
        // 啟動發送
        data_i = 8'h41;  // 'A'
        valid_i = 1;
        @(posedge clk);
        valid_i = 0;
        
        // 等待發送開始
        wait(busy_o == 1);
        
        // 手動接收 UART 數據
        $display("[%0t] 開始接收...", $time);
        
        // 等待起始位 (下降沿)
        wait(tx_o == 0);
        $display("[%0t] 檢測到起始位", $time);
        
        // 等待 1.5 個位元時間（採樣點在數據位中間）
        #(87 * 10 * 1.5);  // 87 時鐘週期 * 10ns * 1.5
        
        // 讀取 8 個數據位
        received_char = 0;
        for (i = 0; i < 8; i = i + 1) begin
            received_char[i] = tx_o;
            $display("[%0t] 讀取位元 %0d: %b (數據: 0x%02h)", $time, i, tx_o, received_char);
            #(87 * 10);  // 等待 1 個位元時間
        end
        
        $display("[%0t] 接收完成: 0x%02h ('%c')", $time, received_char, received_char);
        
        // 等待停止位
        #(87 * 10);
        if (tx_o == 1) begin
            $display("[%0t] 停止位正確", $time);
        end else begin
            $display("[%0t] 錯誤: 停止位應為1, 實際為%b", $time, tx_o);
        end
        
        // 等待發送完成
        wait(busy_o == 0);
        #1000;
        
        $display("\n[%0t] 測試 2: 手動發送 'B' (0x42)", $time);
        
        // 啟動發送
        data_i = 8'h42;  // 'B'
        valid_i = 1;
        @(posedge clk);
        valid_i = 0;
        
        // 等待發送開始
        wait(busy_o == 1);
        
        // 等待起始位
        wait(tx_o == 0);
        
        // 等待 1.5 個位元時間後開始採樣
        #(87 * 10 * 1.5);
        
        // 讀取 8 個數據位
        received_char = 0;
        for (i = 0; i < 8; i = i + 1) begin
            received_char[i] = tx_o;
            #(87 * 10);
        end
        
        $display("[%0t] 接收完成: 0x%02h ('%c')", $time, received_char, received_char);
        
        // 等待發送完成
        wait(busy_o == 0);
        #1000;
        
        $display("\n[%0t] 測試 3: 測試模式", $time);
        test_mode_i = 1;
        
        // 等待測試模式發送幾個字符
        #500000;
        
        $display("\n========================================");
        $display("測試完成");
        $display("========================================");
        $finish;
    end
    
    // 簡單的自動接收器（僅用於顯示）
    always @(negedge tx_o) begin
        integer j;
        reg [7:0] auto_rx_data;
        
        if ($time > 200000) begin  // 避免初始復位時觸發
            $display("[%0t] 自動接收器: 檢測到起始位", $time);
            
            // 延遲避免被立即觸發
            #10;
            
            // 在後台接收
            fork
                begin
                    // 等待 1.5 個位元時間
                    #(87 * 10 * 1.5);
                    
                    auto_rx_data = 0;
                    for (j = 0; j < 8; j = j + 1) begin
                        auto_rx_data[j] = tx_o;
                        #(87 * 10);
                    end
                    
                    $display("[%0t] 自動接收器: 收到 0x%02h ('%c')", 
                            $time, auto_rx_data, auto_rx_data);
                end
            join_none
        end
    end
    
endmodule
