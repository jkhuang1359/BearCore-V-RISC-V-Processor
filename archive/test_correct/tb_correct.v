`timescale 1ns/1ps

module tb_correct;
    reg clk;
    reg rst_n;
    wire uart_tx;
    
    // 只使用已知的端口
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx_o(uart_tx)
    );
    
    // 時鐘 (100MHz)
    always #5 clk = ~clk;
    
    // 簡單的 UART 接收器
    reg [7:0] rx_data;
    reg [3:0] rx_bit_cnt;
    reg rx_receiving;
    
    always @(negedge uart_tx) begin
        if (!rx_receiving) begin
            rx_receiving = 1;
            rx_bit_cnt = 0;
            rx_data = 0;
            
            // 等待 1.5 個位元時間後開始採樣
            #13020; // 1.5 * 8680ns
            
            // 使用 fork 在後台接收
            fork
                begin
                    // 接收 8 個數據位
                    repeat(8) begin
                        #8680; // 1 個位元時間
                        rx_data[rx_bit_cnt] = uart_tx;
                        rx_bit_cnt = rx_bit_cnt + 1;
                    end
                    
                    // 等待停止位
                    #8680;
                    
                    $display("[%t] UART 收到: 0x%02h ('%c')", $time, rx_data, rx_data);
                    rx_receiving = 0;
                end
            join_none
        end
    end
    
    // 主測試
    initial begin
        $dumpfile("correct.vcd");
        $dumpvars(0, tb_correct);
        
        clk = 0;
        rst_n = 0;
        
        $display("========================================");
        $display("正確 UART 測試開始");
        $display("應該輸出: A B C");
        $display("========================================");
        
        // 復位
        #100;
        rst_n = 1;
        $display("[%t] 復位釋放", $time);
        
        // 監視前幾個週期
        repeat(20) @(posedge clk);
        
        // 等待足夠時間讓 UART 發送
        #500000; // 0.5ms
        
        $display("========================================");
        $display("測試完成");
        $display("========================================");
        $finish;
    end
    
    // 監視 PC 變化
    integer cycle = 0;
    always @(posedge clk) begin
        if (cycle < 15) begin
            $display("[%t] 週期 %d: PC = 0x%08h", $time, cycle, u_core.pc);
            cycle = cycle + 1;
        end
    end
endmodule
