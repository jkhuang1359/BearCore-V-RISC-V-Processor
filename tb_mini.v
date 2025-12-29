`timescale 1ns/1ps

module tb_mini;
    reg clk;
    reg rst_n;
    wire uart_tx;
    
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx_o(uart_tx)
    );
    
    // 時鐘
    always #5 clk = ~clk;
    
    // 簡單的 UART 接收
    always @(negedge uart_tx) begin
        integer i;
        reg [7:0] data;
        
        // 簡單延遲模擬
        #8680; // 1 個位元時間（簡化）
        
        data = 0;
        for (i = 0; i < 8; i = i + 1) begin
            #8680;
            data[i] = uart_tx;
        end
        
        $display("[UART] 收到: 0x%02h ('%c')", data, data);
    end
    
    initial begin
        $dumpfile("cpu_mini.vcd");
        $dumpvars(0, tb_mini);
        
        clk = 0;
        rst_n = 0;
        
        #100;
        rst_n = 1;
        
        $display("CPU 測試開始");
        
        // 運行 1000 個時鐘週期
        #1000000;
        
        $display("測試完成");
        $finish;
    end
endmodule
