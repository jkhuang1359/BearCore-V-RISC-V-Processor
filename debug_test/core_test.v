`timescale 1ns/1ps

module core_test;
    reg clk;
    reg rst_n;
    wire uart_tx;
    
    simple_core u_core(
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx_o(uart_tx)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        $dumpfile("debug.vcd");
        $dumpvars(0, core_test);
        
        $display("簡單核心測試開始");
        
        // 復位
        rst_n = 0;
        #100;
        rst_n = 1;
        
        // 運行 50 個時鐘週期
        #5000;
        
        $display("測試完成");
        $finish;
    end
endmodule
