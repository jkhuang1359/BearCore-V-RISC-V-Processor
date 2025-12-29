`timescale 1ns/1ps

module testbench;
    // 系統信號
    reg clk;
    reg rst_n;
    wire uart_tx;
    
    // 測試控制
    reg [31:0] cycle_count;
    reg test_done;
    
    // 實例化核心
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx_o(uart_tx)
    );
    
    // 時鐘生成 (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // UART 接收器
    parameter BIT_PERIOD = 8680; // 115200 bps
    reg [7:0] rx_data;
    integer bit_index;
    reg [31:0] uart_chars;
    
    always @(negedge uart_tx) begin
        // 接收 UART 字符
        #(BIT_PERIOD * 1.5);
        
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            rx_data[bit_index] = uart_tx;
            #BIT_PERIOD;
        end
        
        // 輸出到控制台
        $write("%c", rx_data);
        $fflush();
        
        uart_chars = uart_chars + 1;
        
        // 檢查測試結果
        if (rx_data == "P") begin
            $display("\n[TEST] ✅ 收到 'P' - 測試通過！");
            test_done = 1;
        end else if (rx_data == "F") begin
            $display("\n[TEST] ❌ 收到 'F' - 測試失敗！");
            test_done = 1;
        end
        
        #(BIT_PERIOD * 0.5);
    end
    
    // 主測試流程
    initial begin
        // 初始化
        rst_n = 0;
        test_done = 0;
        cycle_count = 0;
        uart_chars = 0;
        
        // 創建波形文件
        $dumpfile("cpu.vcd");
        $dumpvars(0, testbench);
        
        $display("=" * 60);
        $display("BearCore-V 調試測試");
        $display("期望輸出: X");
        $display("=" * 60);
        
        // 復位
        #100 rst_n = 1;
        
        // 等待測試完成或超時（10000 週期）
        for (integer i = 0; i < 10000; i = i + 1) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
            
            // 每 1000 週期報告一次狀態
            if (cycle_count % 1000 == 0) begin
                $display("[%0d] 週期: %0d, PC: 0x%08h, UART 字符: %0d", 
                        $time, cycle_count, u_core.pc, uart_chars);
            end
            
            if (test_done) begin
                $display("[TEST] 測試在 %0d 週期完成", cycle_count);
                $finish;
            end
        end
        
        // 超時
        $display("\n[TEST] ⏰ 測試超時！");
        $display("總週期: %0d", cycle_count);
        $display("PC: 0x%08h", u_core.pc);
        $display("UART 字符數: %0d", uart_chars);
        
        if (uart_chars > 0) begin
            $display("收到 UART 輸出，但未收到預期的 'P' 或 'F'");
        else
            $display("未收到任何 UART 輸出");
        end
        
        $finish;
    end
    
    // 監控 PC 變化，幫助調試
    reg [31:0] last_pc;
    initial last_pc = 32'h0;
    
    always @(posedge clk) begin
        if (rst_n && u_core.pc !== last_pc) begin
            $display("[PC] 週期 %0d: 0x%08h -> 0x%08h", 
                    cycle_count, last_pc, u_core.pc);
            last_pc = u_core.pc;
        end
    end
    
endmodule