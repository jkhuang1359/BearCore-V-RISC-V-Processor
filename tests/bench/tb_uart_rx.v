`timescale 1ns / 1ps

module tb_uart_rx();

    // --- 1. 參數定義 ---
    parameter CLK_FREQ  = 50000000;         // 50 MHz
    parameter BAUD_RATE = 115200;           // 115200 Baud
    localparam CLK_PERIOD = 20;             // 50MHz 時脈週期 = 20ns
    localparam BIT_PERIOD = 1000000000 / BAUD_RATE; // 每個位元的持續時間 (約 8680 ns)

    // --- 2. 訊號宣告 ---
    reg        clk;
    reg        rst_n;
    reg        rx_i;
    reg        read_en_i;
    wire [7:0] data_o;
    wire       ready_o;

    // --- 3. 實例化被測模組 (DUT) ---
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx_i(rx_i),
        .read_en_i(read_en_i),
        .data_o(data_o),
        .ready_o(ready_o)
    );

    // --- 4. 時脈產生 ---
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- 5. 傳送位元任務 (Task) ---
    task send_byte(input [7:0] data);
        integer i;
        begin
            $display("[TB] 開始傳送 Byte: 0x%h", data);
            
            // Start Bit (邏輯 0)
            rx_i = 1'b0;
            #(BIT_PERIOD);
            
            // Data Bits (LSB First)
            for (i = 0; i < 8; i = i + 1) begin
                rx_i = data[i];
                #(BIT_PERIOD);
            end
            
            // Stop Bit (邏輯 1)
            rx_i = 1'b1;
            #(BIT_PERIOD);
            
            $display("[TB] Byte 傳送完成");
        end
    endtask

    // --- 6. 測試流程 ---
    initial begin
        // 初始化
        rst_n = 0;
        rx_i  = 1; // UART 空閒狀態為高電平
        read_en_i = 0;
        
        // 釋放重置
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 5);

        // 測試傳送 0xA5 (二進制: 10100101)
        send_byte(8'hA5);

        // 等待模組回報資料準備就緒
        wait(ready_o == 1'b1);
        $display("[TB] 偵測到 ready_o 為高電平！");
        
        // 驗證收到的資料
        if (data_o === 8'hA5) begin
            $display("✅ [驗證通過] 成功接收到資料: 0x%h", data_o);
        end else begin
            $display("❌ [驗證失敗] 預期 0xA5，但收到 0x%h", data_o);
        end

        // 模擬 CPU 讀取動作，清除 ready 標誌
        #(CLK_PERIOD * 2);
        read_en_i = 1;
        #(CLK_PERIOD);
        read_en_i = 0;
        
        if (ready_o === 1'b0) begin
            $display("[TB] 讀取握手成功，ready_o 已清除。");
        end

        // 測試傳送另一個數值 (例如 0x55)
        #(BIT_PERIOD * 2);
        send_byte(8'h55);
        wait(ready_o == 1'b1);
        $display("✅ [驗證通過] 二次接收資料: 0x%h", data_o);

        #(CLK_PERIOD * 100);
        $display("[TB] 所有測試結束。");
        $finish;
    end

    // 監控波形
    initial begin
        $dumpfile("uart_rx_test.vcd");
        $dumpvars(0, tb_uart_rx);
    end

endmodule