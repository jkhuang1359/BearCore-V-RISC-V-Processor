`timescale 1ns/1ps

// =============================================================================
// UART 接收器模組 (UART Receiver)
// 功能：
// 1. 實現非同步串列通訊接收功能
// 2. 支援可配置的鮑率 (Baud Rate)
// 3. 實現亞穩態保護 (雙重同步)
// 4. 提供接收資料就緒標誌
// =============================================================================
module uart_receiver #(
    // 參數定義
    parameter CLOCK_FREQUENCY = 50000000,     // 時脈頻率 (Hz)
    parameter BAUD_RATE = 115200              // 鮑率 (bps)
)(
    // 時脈與重置訊號
    input  wire        clk_i,                     // 時脈輸入
    input  wire        reset_ni,                  // 低態有效重置
    
    // UART 接收介面
    input  wire        receive_data_i,            // 串列資料輸入
    input  wire        read_enable_i,             // 讀取使能 (清除就緒標誌)
    
    // 資料輸出與狀態
    output wire [7:0]  receive_data_o,            // 接收資料輸出
    output reg         receive_ready_o            // 接收資料就緒標誌
);
    
    // ============================
    // 1. 內部常數計算
    // ============================
    localparam CLOCKS_PER_BIT = CLOCK_FREQUENCY / BAUD_RATE;  // 每個位元的時脈週期數
    
    // ============================
    // 2. 狀態機定義
    // ============================
    localparam STATE_IDLE   = 2'b00;  // 空閒狀態
    localparam STATE_START  = 2'b01;  // 起始位元偵測
    localparam STATE_DATA   = 2'b10;  // 資料位元接收
    localparam STATE_STOP   = 2'b11;  // 停止位元接收
    
    // ============================
    // 3. 內部訊號宣告
    // ============================
    reg [1:0]  current_state_r;                  // 目前狀態
    reg [31:0] clock_counter_r;                  // 時脈計數器
    reg [2:0]  bit_counter_r;                    // 位元計數器
    reg [7:0]  receive_data_buffer_r;            // 接收資料緩衝區
    
    // 輸入同步訊號 (防止亞穩態)
    reg receive_data_sync_0_r;                   // 第一級同步
    reg receive_data_sync_1_r;                   // 第二級同步
    
    // ============================
    // 4. 輸入同步邏輯
    // ============================
    always @(posedge clk_i or negedge reset_ni) begin
        if (!reset_ni) begin
            receive_data_sync_0_r <= 1'b1;
            receive_data_sync_1_r <= 1'b1;
        end else begin
            receive_data_sync_0_r <= receive_data_i;      // 第一級同步
            receive_data_sync_1_r <= receive_data_sync_0_r; // 第二級同步
        end
    end
    
    // ============================
    // 5. UART 接收器主狀態機
    // ============================
    always @(posedge clk_i or negedge reset_ni) begin
        if (!reset_ni) begin
            // --------------------------------------------------
            // 重置狀態
            // --------------------------------------------------
            current_state_r <= STATE_IDLE;
            clock_counter_r <= 32'h0;
            bit_counter_r <= 3'h0;
            receive_data_buffer_r <= 8'b0;
            receive_ready_o <= 1'b0;
        end else begin
            // --------------------------------------------------
            // 讀取握手處理
            // --------------------------------------------------
            if (read_enable_i) begin
                receive_ready_o <= 1'b0;  // CPU 讀取後清除就緒標誌
            end
            
            // --------------------------------------------------
            // 狀態機轉移
            // --------------------------------------------------
            case (current_state_r)
                STATE_IDLE: begin
                    // 空閒狀態: 等待起始位元 (下降沿)
                    clock_counter_r <= 32'h0;
                    bit_counter_r <= 3'h0;
                    
                    if (receive_data_sync_1_r == 1'b0) begin
                        current_state_r <= STATE_START;  // 偵測到起始位元
                    end
                end
                
                STATE_START: begin
                    // 起始位元確認: 在位元中間點確認是否仍為低電平
                    if (clock_counter_r == (CLOCKS_PER_BIT / 2)) begin
                        if (receive_data_sync_1_r == 1'b0) begin
                            // 確認起始位元有效
                            clock_counter_r <= 32'h0;
                            current_state_r <= STATE_DATA;
                        end else begin
                            // 雜訊誤判，返回空閒狀態
                            current_state_r <= STATE_IDLE;
                        end
                    end else begin
                        clock_counter_r <= clock_counter_r + 1;
                    end
                end
                
                STATE_DATA: begin
                    // 資料位元接收: 在位元中間點採樣
                    if (clock_counter_r == CLOCKS_PER_BIT - 1) begin
                        clock_counter_r <= 32'h0;
                        receive_data_buffer_r[bit_counter_r] <= receive_data_sync_1_r;
                        
                        if (bit_counter_r == 7) begin
                            // 8個資料位元接收完成
                            current_state_r <= STATE_STOP;
                        end else begin
                            bit_counter_r <= bit_counter_r + 1;
                        end
                    end else begin
                        clock_counter_r <= clock_counter_r + 1;
                    end
                end
                
                STATE_STOP: begin
                    // 停止位元接收
                    if (clock_counter_r == CLOCKS_PER_BIT - 1) begin
                        // 接收完成，設定就緒標誌
                        receive_ready_o <= 1'b1;
                        current_state_r <= STATE_IDLE;
                        clock_counter_r <= 32'h0;
                    end else begin
                        clock_counter_r <= clock_counter_r + 1;
                    end
                end
                
                default: begin
                    // 未定義狀態，返回空閒狀態
                    current_state_r <= STATE_IDLE;
                end
            endcase
        end
    end
    
    // ============================
    // 6. 接收資料輸出
    // ============================
    assign receive_data_o = receive_data_buffer_r;
    
endmodule