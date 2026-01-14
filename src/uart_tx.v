`timescale 1ns/1ps

// =============================================================================
// UART 發送器模組 (UART Transmitter)
// 功能：
// 1. 實現非同步串列通訊發送功能
// 2. 支援可配置的鮑率 (Baud Rate)
// 3. 支援測試模式，自動發送測試字串
// 4. 包含忙碌狀態指示
// =============================================================================
module uart_transmitter #(
    // 參數定義
    parameter CLOCK_FREQUENCY = 100000000,    // 時脈頻率 (Hz)
    parameter BAUD_RATE = 1152000             // 鮑率 (bps)
)(
    // 時脈與重置訊號
    input  wire        clk_i,                     // 時脈輸入
    input  wire        reset_ni,                  // 低態有效重置
    
    // 資料輸入與控制
    input  wire [7:0]  transmit_data_i,           // 發送資料
    input  wire        transmit_valid_i,          // 發送有效標誌
    input  wire        test_mode_i,               // 測試模式使能
    
    // 狀態與輸出
    output wire        busy_o,                    // 發送忙碌標誌
    output reg         transmit_data_o            // 串列資料輸出
);
    
    // ============================
    // 1. 內部常數計算
    // ============================
    localparam BIT_PERIOD = CLOCK_FREQUENCY / BAUD_RATE;  // 每個位元的時脈週期數
    
    // ============================
    // 2. 內部訊號宣告
    // ============================
    reg [15:0] clock_counter_r;                   // 時脈計數器
    reg [3:0]  bit_counter_r;                     // 位元計數器
    reg [7:0]  transmit_data_buffer_r;            // 發送資料緩衝區
    reg        transmission_active_r;             // 傳輸進行中標誌
    
    // 測試模式相關訊號
    reg [3:0]  test_pointer_r;                    // 測試資料指標
    reg        test_mode_previous_r;              // 測試模式前一個狀態
    reg [7:0]  test_rom_array [0:14];             // 測試 ROM 陣列
    
    // ============================
    // 3. 測試模式邊緣偵測
    // ============================
    wire test_mode_start_edge_w = test_mode_i && !test_mode_previous_r;
    
    // ============================
    // 4. 測試 ROM 初始化
    // ============================
    initial begin
        // 測試字串: "Hello! RISC-V!\n"
        test_rom_array[0]  = "H";  // H
        test_rom_array[1]  = "e";  // e
        test_rom_array[2]  = "l";  // l
        test_rom_array[3]  = "l";  // l
        test_rom_array[4]  = "o";  // o
        test_rom_array[5]  = "!";  // !
        test_rom_array[6]  = " ";  // 空格
        test_rom_array[7]  = "R";  // R
        test_rom_array[8]  = "I";  // I
        test_rom_array[9]  = "S";  // S
        test_rom_array[10] = "C";  // C
        test_rom_array[11] = "-";  // -
        test_rom_array[12] = "V";  // V
        test_rom_array[13] = "!";  // !
        test_rom_array[14] = "\n"; // 換行
    end
    
    // ============================
    // 5. 最終資料與有效訊號選擇
    // ============================
    // 測試模式時忽略 CPU 的發送請求
    wire [7:0] final_transmit_data_w = 
        (test_mode_i) ? test_rom_array[test_pointer_r] : transmit_data_i;
    
    wire final_transmit_valid_w = 
        (test_mode_i) ? (test_pointer_r < 15 && !transmission_active_r) : 
                        (transmit_valid_i && !transmission_active_r);
    
    // ============================
    // 6. 忙碌狀態輸出
    // ============================
    assign busy_o = transmission_active_r;
    
    // ============================
    // 7. UART 發送器主狀態機
    // ============================
    always @(posedge clk_i or negedge reset_ni) begin
        if (!reset_ni) begin
            // --------------------------------------------------
            // 重置狀態
            // --------------------------------------------------
            clock_counter_r <= 16'h0;
            bit_counter_r <= 4'h0;
            transmit_data_o <= 1'b1;              // 空閒狀態為高電平
            transmission_active_r <= 1'b0;
            test_pointer_r <= 4'h0;
            test_mode_previous_r <= 1'b0;
        end else begin
            // 儲存測試模式前一個狀態
            test_mode_previous_r <= test_mode_i;
            
            // --------------------------------------------------
            // 測試模式啟動邊緣偵測
            // --------------------------------------------------
            if (test_mode_start_edge_w) begin
                test_pointer_r <= 4'h0;            // 重置測試指標
            end
            
            // --------------------------------------------------
            // 傳輸狀態控制
            // --------------------------------------------------
            if (!transmission_active_r) begin
                // 空閒狀態
                if (final_transmit_valid_w) begin
                    // 開始新的傳輸
                    transmit_data_buffer_r <= final_transmit_data_w;
                    transmission_active_r <= 1'b1;
                    clock_counter_r <= 16'h0;
                    bit_counter_r <= 4'h0;
                    transmit_data_o <= 1'b0;      // 起始位元 (低電平)
                end
            end else begin
                // 傳輸進行中狀態
                if (clock_counter_r < BIT_PERIOD - 1) begin
                    // 等待位元時間
                    clock_counter_r <= clock_counter_r + 1;
                end else begin
                    // 位元時間到達
                    clock_counter_r <= 16'h0;
                    
                    if (bit_counter_r < 8) begin
                        // 發送資料位元
                        transmit_data_o <= transmit_data_buffer_r[bit_counter_r];
                        bit_counter_r <= bit_counter_r + 1;
                    end else if (bit_counter_r == 8) begin
                        // 發送停止位元
                        transmit_data_o <= 1'b1;  // 停止位元 (高電平)
                        bit_counter_r <= bit_counter_r + 1;
                    end else begin
                        // 傳輸完成
                        transmission_active_r <= 1'b0;
                        
                        // 測試模式: 移動到下一個字元
                        if (test_mode_i && test_pointer_r < 15) begin
                            test_pointer_r <= test_pointer_r + 1;
                        end
                    end
                end
            end
        end
    end
    
endmodule