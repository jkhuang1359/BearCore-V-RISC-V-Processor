`timescale 1ns/1ps
`include "include/riscv_defines.vh"

// =============================================================================
// 除法器單元模組 (Division Unit)
// 功能：
// 1. 實現 32-bit 有符號/無符號除法與取餘運算
// 2. 使用非恢復式除法演算法
// 3. 支援流水線暫停請求
// 4. 提供就緒與忙碌狀態指示
// =============================================================================
module division_unit (
    // 時脈與重置訊號
    input  wire        clk_i,                     // 時脈輸入
    input  wire        reset_ni,                  // 低態有效重置
    
    // 控制訊號
    input  wire        start_i,                   // 開始運算訊號
    input  wire        signed_operation_i,        // 有符號運算標誌
    
    // 運算元輸入
    input  wire [31:0] dividend_i,                // 被除數
    input  wire [31:0] divisor_i,                 // 除數
    
    // 結果輸出
    output reg  [31:0] quotient_o,                // 商數
    output reg  [31:0] remainder_o,               // 餘數
    
    // 狀態輸出
    output reg         ready_o,                   // 運算完成就緒
    output reg         busy_o                     // 運算進行中
);
    
    // ============================
    // 1. 狀態機定義
    // ============================
    localparam STATE_IDLE      = 2'd0;  // 空閒狀態
    localparam STATE_CALCULATE = 2'd1;  // 計算狀態
    localparam STATE_SIGN_FIX  = 2'd2;  // 符號修正狀態
    localparam STATE_DONE      = 2'd3;  // 完成狀態
    
    // ============================
    // 2. 內部訊號宣告
    // ============================
    reg [1:0]  current_state_r;                  // 目前狀態
    
    // 運算暫存器
    reg [31:0] temp_dividend_r;                  // 被除數暫存器
    reg [31:0] temp_divisor_r;                   // 除數暫存器
    reg [63:0] temp_partial_r;                   // 部分結果暫存器
    
    // 控制訊號
    reg [5:0]  iteration_counter_r;              // 迭代計數器
    reg        quotient_sign_r;                  // 商數符號
    reg        remainder_sign_r;                 // 餘數符號
    
    // 組合邏輯運算結果
    reg [63:0] calculation_result_r;             // 組合邏輯計算結果
    
    // ============================
    // 3. 純組合邏輯計算區塊
    // ============================
    always @(*) begin
        calculation_result_r = temp_partial_r;
        
        if (current_state_r == STATE_CALCULATE) begin
            // 非恢復式除法演算法核心步驟
            calculation_result_r = temp_partial_r << 1;  // 左移一位
            
            if (calculation_result_r[63:32] >= temp_divisor_r) begin
                // 如果部分餘數大於等於除數
                calculation_result_r[63:32] = calculation_result_r[63:32] - temp_divisor_r;
                calculation_result_r[0] = 1'b1;  // 設定商數位元
            end
        end
    end
    
    // ============================
    // 4. 核心時序邏輯 (狀態機 + 資料路徑)
    // ============================
    always @(posedge clk_i or negedge reset_ni) begin
        if (!reset_ni) begin
            // --------------------------------------------------
            // 重置狀態
            // --------------------------------------------------
            current_state_r <= STATE_IDLE;
            quotient_o <= 32'h0;
            remainder_o <= 32'h0;
            ready_o <= 1'b0;
            busy_o <= 1'b0;
            iteration_counter_r <= 6'h0;
            temp_dividend_r <= 32'h0;
            temp_divisor_r <= 32'h0;
            temp_partial_r <= 64'h0;
            quotient_sign_r <= 1'b0;
            remainder_sign_r <= 1'b0;
        end else begin
            case (current_state_r)
                STATE_IDLE: begin
                    // 空閒狀態
                    ready_o <= 1'b0;
                    
                    if (start_i) begin
                        // 開始新的除法運算
                        busy_o <= 1'b1;
                        iteration_counter_r <= 6'd32;  // 32次迭代
                        
                        // 計算符號 (僅在有符號運算時)
                        quotient_sign_r = signed_operation_i ? 
                                         (dividend_i[31] ^ divisor_i[31]) : 1'b0;
                        remainder_sign_r = signed_operation_i ? 
                                          dividend_i[31] : 1'b0;
                        
                        // 取得絕對值 (有符號運算時)
                        if (signed_operation_i && dividend_i[31]) begin
                            temp_dividend_r = -dividend_i;  // 負數取補數
                        end else begin
                            temp_dividend_r = dividend_i;   // 正數或無符號
                        end
                        
                        if (signed_operation_i && divisor_i[31]) begin
                            temp_divisor_r = -divisor_i;    // 負數取補數
                        end else begin
                            temp_divisor_r = divisor_i;     // 正數或無符號
                        end
                        
                        // 初始化部分結果
                        temp_partial_r <= {32'b0, temp_dividend_r};
                        
                        // 轉移到計算狀態
                        current_state_r <= STATE_CALCULATE;
                    end else begin
                        busy_o <= 1'b0;
                        current_state_r <= STATE_IDLE;
                    end
                end
                
                STATE_CALCULATE: begin
                    // 計算狀態: 執行非恢復式除法演算法
                    if (iteration_counter_r > 0) begin
                        // 儲存組合邏輯計算結果
                        temp_partial_r <= calculation_result_r;
                        iteration_counter_r <= iteration_counter_r - 1;
                    end else begin
                        // 32次迭代完成，轉移到符號修正狀態
                        current_state_r <= STATE_SIGN_FIX;
                    end
                end
                
                STATE_SIGN_FIX: begin
                    // 符號修正狀態: 根據符號調整結果
                    if (quotient_sign_r) begin
                        quotient_o <= -temp_partial_r[31:0];  // 負商數
                    end else begin
                        quotient_o <= temp_partial_r[31:0];   // 正商數
                    end
                    
                    if (remainder_sign_r) begin
                        remainder_o <= -temp_partial_r[63:32];  // 負餘數
                    end else begin
                        remainder_o <= temp_partial_r[63:32];   // 正餘數
                    end
                    
                    // 轉移到完成狀態
                    current_state_r <= STATE_DONE;
                end
                
                STATE_DONE: begin
                    // 完成狀態: 設定就緒標誌
                    busy_o <= 1'b0;
                    ready_o <= 1'b1;
                    
                    // 返回空閒狀態
                    current_state_r <= STATE_IDLE;
                end
                
                default: begin
                    // 未定義狀態，返回空閒狀態
                    current_state_r <= STATE_IDLE;
                end
            endcase
        end
    end
    
endmodule