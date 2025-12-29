`timescale 1ns/1ps

module tb_final;
    reg clk;
    reg rst_n;
    wire uart_tx;
    
    // 實例化 core
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx_o(uart_tx)
    );
    
    // 時鐘 (100MHz)
    always #5 clk = ~clk;
    
    // UART 接收器
    reg [7:0] rx_data;
    reg [3:0] rx_bit_cnt;
    reg rx_receiving;
    integer rx_i;
    
    always @(negedge uart_tx) begin
        if (!rx_receiving) begin
            rx_receiving = 1;
            
            fork
                begin
                    // 等待 1.5 個位元時間
                    #13020;
                    
                    // 接收 8 個數據位
                    rx_data = 0;
                    for (rx_i = 0; rx_i < 8; rx_i = rx_i + 1) begin
                        #8680;
                        rx_data[rx_i] = uart_tx;
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
        $dumpfile("final.vcd");
        $dumpvars(0, tb_final);
        
        clk = 0;
        rst_n = 0;
        
        $display("========================================");
        $display("最終測試開始");
        $display("應該輸出: A B C");
        $display("========================================");
        
        // 復位
        #100;
        rst_n = 1;
        $display("[%t] 復位釋放", $time);
        
        // 等待足夠時間
        #2000000; // 2ms
        
        $display("========================================");
        $display("測試完成");
        $display("========================================");
        $finish;
    end
    
    // 監視 PC 變化
    integer cycle = 0;
    always @(posedge clk) begin
        if (cycle < 20) begin
            $display("[%t] 週期 %d: PC = 0x%08h", $time, cycle, u_core.pc);
            cycle = cycle + 1;
        end
    end
endmodule
