`timescale 1ns/1ps

module tb_top;
    // --- 1. 系統訊號定義 ---
    reg clk;
    reg rst_n;
    wire uart_tx;

    // --- 2. 實例化核心 (BearCore-V) ---
    core u_core ( 
        .clk(clk), 
        .rst_n(rst_n), 
        .uart_tx_o(uart_tx) 
    );

    // --- 3. 時鐘產生器 (100MHz) ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 每 5ns 翻轉，週期 10ns [cite: 177]
    end

    // --- 4. 模擬主流程控制 ---
    initial begin
        $display("--- Starting BearCore-V Simulation ---");
        $dumpfile("cpu.vcd"); // 產生波形檔 [cite: 178]
        $dumpvars(0, tb_top);
        
        // 重置序列 [cite: 179]
        rst_n = 0;
        #100 rst_n = 1;
        
        // 模擬時間：45ms 足以跑完目前的 Memory Test [cite: 180]
        #50_000_000; 
        
        $display("\nSimulation finished by timeout.");
        $finish;
    end

    // --- 5. 自動化 UART 參數計算 ---
    localparam BAUDRATE   = 1152000; 
    // BIT_PERIOD = (1s / 115200) = 約 8680.55 ns [cite: 183, 215]
    localparam BIT_PERIOD = 1000000000 / BAUDRATE; 

    // --- 6. 專業虛擬 UART 終端機 ---
    reg [7:0] rx_temp_data;
    integer   bit_idx;

    initial begin
        $display("--- UART Virtual Terminal Monitoring Started (Baud: %0d) ---", BAUDRATE);
    end

    // 監控核心輸出訊號 [cite: 88, 135]
    always @(negedge u_core.uart_tx_o) begin 
        // A. 偵測到 Start Bit 下降沿，延遲 1.5 倍週期定位到 Bit 0 中央 [cite: 200, 225]
        #(BIT_PERIOD * 1.5); 
        
        // B. 依序採樣 8 個資料位元 [cite: 191, 201]
        for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
            rx_temp_data[bit_idx] = u_core.uart_tx_o;
            #(BIT_PERIOD); // 每隔一倍週期移動到下一個 Bit 中心 [cite: 192, 202, 226]
        end
        
        // C. 將解碼後的字元印出到終端機 [cite: 192, 203]
        $write("%c", rx_temp_data);
        $fflush(); 
        
        // D. 額外等待 Stop Bit 結束，避免連續字元重疊觸發 [cite: 193, 228-229]
        #(BIT_PERIOD * 0.5);
    end

endmodule