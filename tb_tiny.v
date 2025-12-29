`timescale 1ns/1ps

module tb_tiny;
    reg clk;
    reg rst_n;
    wire uart_tx;
    
    cpu_tiny u_cpu(
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx(uart_tx)
    );
    
    // 時鐘 (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        $dumpfile("tiny.vcd");
        $dumpvars(0, tb_tiny);
        
        $display("========================================");
        $display("最簡單 CPU 測試開始");
        $display("========================================");
        
        // 復位
        rst_n = 0;
        #100;
        rst_n = 1;
        $display("[%0t] 復位釋放", $time);
        
        // 運行足夠長時間
        #10000;
        
        $display("[%0t] 測試完成", $time);
        $display("========================================");
        $finish;
    end
endmodule
