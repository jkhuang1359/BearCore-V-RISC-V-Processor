`timescale 1ns/1ps

// =============================================================================
// 指令記憶體模組 (ROM)
// 功能：
// 1. 提供指令讀取介面 (4-byte aligned)
// 2. 提供資料讀取介面 (4-byte aligned)
// 3. 支援 firmware.hex 檔案載入
// 4. 包含越界保護機制
// =============================================================================
module rom (
    // 指令讀取介面
    input      [31:0] instruction_addr_i,      // 指令讀取地址
    output reg [31:0] instruction_data_o,      // 指令讀取輸出
    
    // 資料讀取介面  
    input      [31:0] data_read_addr_i,        // 資料讀取地址
    output reg [31:0] data_read_data_o         // 資料讀取輸出
);
    
    // ============================
    // 參數定義
    // ============================
    parameter ROM_DEPTH = 16384;                // ROM 深度 (16KB)
    parameter ADDR_WIDTH = 14;                  // 地址寬度 (2^14 = 16384)
    
    // ============================
    // 內部記憶體宣告
    // ============================
    reg [31:0] memory_array [0:ROM_DEPTH-1];    // ROM 記憶體陣列
    
    // ============================
    // 內部訊號宣告
    // ============================
    wire [ADDR_WIDTH-1:0] instruction_word_addr;  // 指令字地址 (4-byte aligned)
    wire [ADDR_WIDTH-1:0] data_word_addr;         // 資料字地址 (4-byte aligned)
    
    // ============================
    // 地址計算
    // ============================
    assign instruction_word_addr = instruction_addr_i[ADDR_WIDTH+1:2];  // 右移2位 (4-byte alignment)
    assign data_word_addr = data_read_addr_i[ADDR_WIDTH+1:2];           // 右移2位 (4-byte alignment)
    
    // ============================
    // 指令讀取邏輯 (組合邏輯)
    // ============================
    always @(*) begin
        if (instruction_word_addr < ROM_DEPTH) begin
            instruction_data_o = memory_array[instruction_word_addr];
        end else begin
            instruction_data_o = 32'h00000013;  // 越界時返回 nop 指令
        end
    end
    
    // ============================
    // 資料讀取邏輯 (組合邏輯)
    // ============================
    always @(*) begin
        if (data_word_addr < ROM_DEPTH) begin
            data_read_data_o = memory_array[data_word_addr];
        end else begin
            data_read_data_o = 32'h0;            // 越界時返回 0
        end
    end
    
    // ============================
    // 記憶體初始化
    // ============================
    integer initialization_index;
    
    initial begin
        // --------------------------------------------------
        // 步驟 1: 初始化所有記憶體為 nop 指令
        // --------------------------------------------------
        for (initialization_index = 0; initialization_index < ROM_DEPTH; initialization_index = initialization_index + 1) begin
            memory_array[initialization_index] = 32'h00000013;  // nop: addi x0, x0, 0
        end
        
        // --------------------------------------------------
        // 步驟 2: 載入 firmware.hex 檔案
        // --------------------------------------------------
        if ($test$plusargs("debug")) begin
            $display("[ROM] 開始載入 firmware.hex 檔案");
        end
        
        //$readmemh("firmware.hex", memory_array, 0, ROM_DEPTH-1);

        `ifdef SIMULATION
            $readmemh("firmware.hex" ,memory_array, 0, ROM_DEPTH-1);
        `else
            // 對於綜合，可能需要不同的處理方式
            $readmemh("firmware.hex", memory_array);
        `endif        
        
        // --------------------------------------------------
        // 步驟 3: 顯示前幾條指令用於調試
        // --------------------------------------------------
        if ($test$plusargs("debug")) begin
            $display("[ROM] 載入的指令內容:");
            for (initialization_index = 0; initialization_index < 16; initialization_index = initialization_index + 1) begin
                if (memory_array[initialization_index] !== 32'h00000013) begin
                    $display("  [%0d] 0x%08h: 0x%08h", initialization_index, initialization_index*4, memory_array[initialization_index]);
                end
            end
        end
    end
    
endmodule