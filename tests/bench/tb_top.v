`timescale 1ns / 1ps

module tb_top();

    // --- 1. 參數定義 (統一 100MHz) ---
    parameter CLK_FREQ = 100000000;        // 100 MHz
    parameter BAUDRATE = 1152000;          
    localparam CLK_PERIOD = 10;            // 10ns
    localparam BIT_PERIOD = 1000000000 / BAUDRATE; 

    reg         clk;
    reg         rst_n;
    reg         uart_rx_line;              
    wire        uart_tx_line;              

    // --- 2. 實例化核心 ---
    riscv_core u_core (
        .core_clk_i(clk),
        .core_reset_ni(rst_n),
        .uart_rx_data_i(uart_rx_line),          
        .uart_tx_data_o(uart_tx_line)
    );

    // --- 3. 時脈產生 ---
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- 4. UART 發送任務 (Task) ---
    task send_char(input [7:0] char);
        integer i;
        begin
            $display("[TB] Sending: '%c' (0x%h)", char, char);
            uart_rx_line = 0; // Start bit
            #(BIT_PERIOD);
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx_line = char[i];
                #(BIT_PERIOD);
            end
            uart_rx_line = 1; // Stop bit
            #(BIT_PERIOD * 20);
        end
    endtask

    // --- 5. 自動檢測測試完成 ---
    reg [1023:0] output_buffer = 0;
    integer buffer_index = 0;
    integer total_chars = 0;
    integer i;
    
    // 收集 UART 輸出並檢測關鍵字
    always @(posedge uart_char_ready) begin
        // 保存字元到緩衝區
        if (buffer_index < 128) begin
            output_buffer = {output_buffer[1015:0], captured_char};
            buffer_index = buffer_index + 1;
            total_chars = total_chars + 1;
        end
        
        // 檢測測試完成標誌
        if (total_chars > 50) begin
            // 檢測 "ALL TESTS PASSED!"
            reg [7:0] buffer_array [0:127];
            integer i, j;
            
            // 將緩衝區轉換為陣列
            for (i = 0; i < 128; i = i + 1) begin
                buffer_array[i] = output_buffer[8*i +: 8];
            end
            
            // 檢查是否有 "ALL TESTS PASSED!"
            for (i = 0; i < 128-17; i = i + 1) begin
                if (buffer_array[i] == "A" && 
                    buffer_array[i+1] == "L" && 
                    buffer_array[i+2] == "L" && 
                    buffer_array[i+3] == " " && 
                    buffer_array[i+4] == "T" && 
                    buffer_array[i+5] == "E" && 
                    buffer_array[i+6] == "S" && 
                    buffer_array[i+7] == "T" && 
                    buffer_array[i+8] == "S" && 
                    buffer_array[i+9] == " " && 
                    buffer_array[i+10] == "P" && 
                    buffer_array[i+11] == "A" && 
                    buffer_array[i+12] == "S" && 
                    buffer_array[i+13] == "S" && 
                    buffer_array[i+14] == "E" && 
                    buffer_array[i+15] == "D" && 
                    buffer_array[i+16] == "!") begin
                    
                    $display("\n[TB_AUTO] ✅ 檢測到測試完成標誌！");
                    $display("[TB_AUTO] 🎉 所有測試通過！");
                    #(CLK_PERIOD * 100);
                    $finish;
                end
            end
            
            // 檢查是否有 "FAILED:"
            for (i = 0; i < 128-6; i = i + 1) begin
                if (buffer_array[i] == "F" && 
                    buffer_array[i+1] == "A" && 
                    buffer_array[i+2] == "I" && 
                    buffer_array[i+3] == "L" && 
                    buffer_array[i+4] == "E" && 
                    buffer_array[i+5] == "D" && 
                    buffer_array[i+6] == ":") begin
                    
                    $display("\n[TB_AUTO] ❌ 檢測到測試失敗！");
                    #(CLK_PERIOD * 100);
                    $finish;
                end
            end
        end
    end

    // --- 6. UART TX 解析 (改進版) ---
    reg [7:0]  captured_char;
    reg        uart_char_ready;
    integer    bit_idx;
    integer    line_chars = 0;
    
    initial begin
        uart_char_ready = 0;
        
        forever begin
            // 等待起始位
            @(negedge uart_tx_line);
            #(BIT_PERIOD / 2);
            
            // 驗證起始位
            if (uart_tx_line == 0) begin
                // 採樣數據位
                captured_char = 0;
                for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                    #(BIT_PERIOD);
                    captured_char[bit_idx] = uart_tx_line;
                end
                
                // 等待停止位
                #(BIT_PERIOD);
                
                // 檢查停止位
                if (uart_tx_line == 1) begin
                    // 🏆 關鍵改進：直接顯示字元，不額外換行
                    // 程式本身的換行符 (\r\n) 會自然換行
                    $write("%c", captured_char);
                    $fflush();
                    
                    // 觸發字元就緒信號（用於檢測）
                    uart_char_ready = 1;
                    #(CLK_PERIOD);
                    uart_char_ready = 0;
                    
                    // 計數器，每行顯示統計
                    line_chars = line_chars + 1;
                    if (line_chars >= 200) begin
                        //$display("\n[UART] 已接收 %0d 個字元...", total_chars);
                        line_chars = 0;
                    end
                end
            end
        end
    end

    // --- 7. 初始化與超時控制 ---
    initial begin
        $display("=== BearCore-V 自動化模擬啟動 ===");
        $display("[TB] 時脈: %0d MHz, 波特率: %0d bps", CLK_FREQ/1000000, BAUDRATE);
        $display("[TB] 位元週期: %0d ns", BIT_PERIOD);
        
        `ifdef WAVEFORM
            $display("[TB] 波形錄製: cpu.vcd");
            $dumpfile("cpu.vcd");
            $dumpvars(0, tb_top);
        `endif
        
        // 初始化
        rst_n = 0;
        uart_rx_line = 1;
        #(CLK_PERIOD * 20);
        rst_n = 1;
        
        $display("[TB] 系統重置完成，等待測試開始...\n");
        
        // 自動發送 'a' 執行所有測試
        #(CLK_PERIOD * 100);
        //send_char("a");
        
        // 超時控制 (10ms)
        #(70_000_000);
        
        $display("\n[TB_TIMEOUT] 模擬超時 (10ms)");
        $display("[TB_TIMEOUT] 總接收字元: %0d", total_chars);
        
        // 輸出最後的緩衝區內容
        $display("\n[TB_TIMEOUT] 最後接收的內容:");
        for ( i = 0; i < buffer_index; i = i + 1) begin
            $write("%c", output_buffer[8*i +: 8]);
        end
        $display("");
        
        $finish;
    end

endmodule