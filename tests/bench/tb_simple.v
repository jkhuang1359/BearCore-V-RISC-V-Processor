`timescale 1ns/1ps

module tb_simple;
    reg clk;
    reg rst_n;
    wire uart_tx;
    
    core_wrapper_simple u_core(
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
        $dumpfile("simple_cpu.vcd");
        $dumpvars(0, tb_simple);
        
        $display("========================================");
        $display("簡單核心測試開始");
        $display("========================================");
        
        // 復位
        rst_n = 0;
        #100;
        rst_n = 1;
        $display("[%0t] 復位釋放", $time);
        
        // 運行 50 個週期
        #5000;
        
        $display("[%0t] 測試完成", $time);
        $display("========================================");
        $finish;
    end
endmodule
