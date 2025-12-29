`timescale 1ns/1ps

module tb_uart_tx;
    reg clk;
    reg rst_n;
    reg tx_start;
    reg [7:0] tx_data;
    wire tx_busy;
    wire tx_out;
    
    // 實例化 UART TX 模塊，設置 baudrate 為 1152000
    uart_tx #(
        .CLK_FREQ(100_000_000),   // 100 MHz 時鐘
        .BAUD_RATE(1_152_000)     // 1.152 Mbps
    ) u_uart_tx (
        .clk(clk),
        .rst_n(rst_n),
        .data_i(tx_data),
        .valid_i(tx_start),
        .test_mode_i(1'b1), // ✨ 新增：測試模式開關
        .busy_o(tx_busy),
        .tx_o(tx_out)        
    );
    
    // 時鐘生成 (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // UART 接收器（軟件模擬）
    task automatic receive_uart;
        begin
            reg [7:0] data;
            integer i;
            
            // 等待起始位
            wait(tx_out == 0);
            #868; // 等待 1.5 個位元時間（1152000 baudrate 的位元時間約 868ns）
            
            // 讀取 8 個數據位
            for (i = 0; i < 8; i = i + 1) begin
                data[i] = tx_out;
                #868; // 等待 1 個位元時間
            end
            
            // 等待停止位
            wait(tx_out == 1);
            
            $display("[%0t] UART RX: 收到數據 0x%02h ('%c')", $time, data, data);
        end
    endtask
    
    // 主測試流程
    initial begin
        integer i;
        
        // 創建波形文件
        $dumpfile("uart_tx.vcd");
        $dumpvars(0, tb_uart_tx);
        
        $display("========================================");
        $display("UART TX 測試開始");
        $display("========================================");
        
        // 初始化
        tx_start = 0;
        tx_data = 8'h00;
        rst_n = 0;
        #100;
        rst_n = 1;
        #100;
        
        $display("[%0t] 復位完成，開始測試", $time);
        
        // 測試 1: 發送字符 'A' (0x41)
        $display("\n--- 測試 1: 發送 'A' (0x41) ---");
        tx_data = 8'h41;  // 'A'
        tx_start = 1;
        #10;
        tx_start = 0;
        
        // 啟動接收任務
        fork
            receive_uart();
        join_none
        
        // 等待發送完成
        wait(tx_busy == 0);
        #1000;
        
        // 測試 2: 發送字符 'B' (0x42)
        $display("\n--- 測試 2: 發送 'B' (0x42) ---");
        tx_data = 8'h42;  // 'B'
        tx_start = 1;
        #10;
        tx_start = 0;
        
        // 啟動接收任務
        fork
            receive_uart();
        join_none
        
        // 等待發送完成
        wait(tx_busy == 0);
        #1000;
        
        // 測試 3: 連續發送 "Hello"
        $display("\n--- 測試 3: 連續發送 'Hello' ---");
        tx_data = 8'h48;  // 'H'
        tx_start = 1;
        #10;
        tx_start = 0;
        wait(tx_busy == 0);
        #100;
        
        tx_data = 8'h65;  // 'e'
        tx_start = 1;
        #10;
        tx_start = 0;
        wait(tx_busy == 0);
        #100;
        
        tx_data = 8'h6C;  // 'l'
        tx_start = 1;
        #10;
        tx_start = 0;
        wait(tx_busy == 0);
        #100;
        
        tx_data = 8'h6C;  // 'l'
        tx_start = 1;
        #10;
        tx_start = 0;
        wait(tx_busy == 0);
        #100;
        
        tx_data = 8'h6F;  // 'o'
        tx_start = 1;
        #10;
        tx_start = 0;
        wait(tx_busy == 0);
        #1000;
        
        $display("\n========================================");
        $display("UART TX 測試完成");
        $display("========================================");
        $finish;
    end
    
    // 監控信號變化
    always @(posedge tx_start) begin
        $display("[%0t] TX 開始: 數據=0x%02h", $time, tx_data);
    end
    
    always @(negedge tx_busy) begin
        $display("[%0t] TX 完成", $time);
    end
    
endmodule
