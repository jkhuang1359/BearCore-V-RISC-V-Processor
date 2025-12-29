`timescale 1ns/1ps

module tb_comprehensive_polling;
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
    parameter BIT_PERIOD = 8680;  // 1152000 baudrate 對應的位元時間
    reg [7:0] uart_data;
    integer uart_i;
    
    // UART 接收邏輯
    always @(negedge uart_tx) begin
        #(BIT_PERIOD * 1.5);
        for (uart_i = 0; uart_i < 8; uart_i = uart_i + 1) begin
            uart_data[uart_i] = uart_tx;
            #BIT_PERIOD;
        end
        $write("%c", uart_data);
        $fflush();
    end
    
    // 監視存儲器寫入，模擬 UART 狀態寄存器
    reg [31:0] uart_status = 0;
    reg [31:0] last_waddr = 0;
    reg [31:0] last_wdata = 0;
    
    always @(posedge clk) begin
        // 監視存儲器寫入到 UART 數據寄存器 (0x10000000)
        if (u_core.uart_wen && u_core.mem_alu_result == 32'h10000000) begin
            $display("[%t] UART 寫入: 0x%02h ('%c')", $time, u_core.mem_rs2_data[7:0], u_core.mem_rs2_data[7:0]);
            // 設置 UART 為 busy (bit 0 = 1)
            uart_status = 1;
            
            // 模擬 UART 發送完成 (約 10 個位元時間後清除 busy)
            fork
                begin
                    #(BIT_PERIOD * 10);  // 一個字符的發送時間
                    uart_status = 0;
                    $display("[%t] UART 發送完成，狀態寄存器清空", $time);
                end
            join_none
        end
        
        // 監視對 UART 狀態寄存器的讀取 (0x10000004)
        if (u_core.mem_rs2_data == 32'h10000004) begin
            $display("[%t] 讀取 UART 狀態寄存器: 0x%08h", $time, uart_status);
        end
    end
    
    // 將 UART 狀態寄存器值連接到 CPU 的數據讀取
    // 注意：這需要修改 core 模塊或在此 testbench 中覆蓋 data_rd
    // 這裡我們假設 core 有 data_rd 輸出，並在 testbench 中選擇
    
    // 主測試
    initial begin
        $dumpfile("comprehensive_polling.vcd");
        $dumpvars(0, tb_comprehensive_polling);
        
        clk = 0;
        rst_n = 0;
        
        #100;
        rst_n = 1;
        
        $display("========================================");
        $display("帶 Polling 的 UART 測試開始");
        $display("應該輸出: RISCV!");
        $display("========================================");
        
        // 運行足夠長時間
        #5000000;  // 5ms，足夠發送所有字符
        
        $display("\n========================================");
        $display("測試完成");
        $display("========================================");
        $finish;
    end
    
    // 顯示前 30 個週期的 PC 和指令
    integer cycle = 0;
    always @(posedge clk) begin
        if (cycle < 30) begin
            $display("[%t] PC=0x%08h, instr=0x%08h", 
                    $time, u_core.pc, u_core.id_inst);
            cycle = cycle + 1;
        end
    end
endmodule
