`timescale 1ns/1ps

// =============================================================================
// 資料記憶體模組 (Data Memory - Block RAM)
// 功能：
// 1. 實現 16KB 資料記憶體 (4096 x 32-bit)
// 2. 支援位元組、半字、字讀寫操作
// 3. 使用 Block RAM 實現，適合 FPGA 合成
// 4. 同步讀寫操作，符合 FPGA 記憶體時序要求
// =============================================================================
module data_memory (
    // 時脈訊號
    input  wire        clk_i,                     // 時脈輸入
    
    // 記憶體控制訊號
    input  wire        write_enable_i,            // 寫入使能
    input  wire [31:0] address_i,                 // 記憶體地址
    input  wire [31:0] write_data_i,              // 寫入資料
    input  wire [2:0]  function_3_i,              // 操作類型 (決定讀寫寬度)
    
    // 記憶體讀取輸出
    output reg  [31:0] read_data_o                // 讀取資料 (延遲一個週期)
);
    
    // ============================
    // 1. 參數與常數定義
    // ============================
    parameter MEMORY_DEPTH = 16384;               // 記憶體深度 (16KB = 4096 words)
    parameter ADDR_WIDTH = 14;                    // 地址寬度 (2^14 = 16384)
    
    // ============================
    // 2. 記憶體陣列宣告 (使用 Block RAM 屬性)
    // ============================
    (* ram_style = "block" *)
    reg [31:0] memory_array [0:MEMORY_DEPTH-1];   // 記憶體陣列
    
    // ============================
    // 3. 內部訊號宣告
    // ============================
    wire [ADDR_WIDTH-1:0] word_address_w;         // 字地址 (忽略低2位)
    wire [1:0]            byte_offset_w;          // 位元組偏移量 (地址低2位)
    
    // 位元組寫入使能訊號
    reg [3:0] byte_write_enable_r;                // 位元組寫入使能
    
    // 讀取管道暫存器
    reg [31:0] raw_read_data_r;                   // 原始讀取資料
    reg [2:0]  delayed_function_3_r;              // 延遲的 funct3
    reg [1:0]  delayed_address_low_r;             // 延遲的地址低位
    
    // ============================
    // 4. 地址計算
    // ============================
    assign word_address_w = address_i[ADDR_WIDTH+1:2];  // 右移2位 (字對齊)
    assign byte_offset_w = address_i[1:0];               // 位元組偏移量
    
    // ============================
    // 5. 位元組寫入使能生成
    // ============================
    always @(*) begin
        if (!write_enable_i) begin
            byte_write_enable_r = 4'b0000;  // 無寫入操作
        end else begin
            case (function_3_i)
                3'b000: begin  // SB: 儲存位元組
                    byte_write_enable_r = 4'b0001 << byte_offset_w;
                end
                3'b001: begin  // SH: 儲存半字
                    if (byte_offset_w[1] == 1'b0) begin
                        byte_write_enable_r = 4'b0011;  // 低半字
                    end else begin
                        byte_write_enable_r = 4'b1100;  // 高半字
                    end
                end
                3'b010: begin  // SW: 儲存字
                    byte_write_enable_r = 4'b1111;  // 全部4個位元組
                end
                default: begin
                    byte_write_enable_r = 4'b0000;  // 無效操作
                end
            endcase
        end
    end
    
    // ============================
    // 6. Block RAM 核心行為 (同步)
    // ============================
    always @(posedge clk_i) begin
        // --------------------------------------------------
        // (A) 同步寫入操作
        // --------------------------------------------------
        if (byte_write_enable_r[0]) begin
            memory_array[word_address_w][7:0] <= write_data_i[7:0];
        end
        if (byte_write_enable_r[1]) begin
            memory_array[word_address_w][15:8] <= write_data_i[15:8];
        end
        if (byte_write_enable_r[2]) begin
            memory_array[word_address_w][23:16] <= write_data_i[23:16];
        end
        if (byte_write_enable_r[3]) begin
            memory_array[word_address_w][31:24] <= write_data_i[31:24];
        end
        
        // --------------------------------------------------
        // (B) 同步讀取操作 (Registered Read)
        // --------------------------------------------------
        raw_read_data_r <= memory_array[word_address_w];
        
        // 儲存讀取時的格式資訊，用於下個週期的資料格式化
        delayed_function_3_r <= function_3_i;
        delayed_address_low_r <= byte_offset_w;
    end
    
    // ============================
    // 7. 讀取資料後處理 (組合邏輯)
    // ============================
    always @(*) begin
        case (delayed_function_3_r)
            3'b000: begin  // LB: 載入有符號位元組
                case (delayed_address_low_r)
                    2'b00: read_data_o = {{24{raw_read_data_r[7]}}, raw_read_data_r[7:0]};
                    2'b01: read_data_o = {{24{raw_read_data_r[15]}}, raw_read_data_r[15:8]};
                    2'b10: read_data_o = {{24{raw_read_data_r[23]}}, raw_read_data_r[23:16]};
                    2'b11: read_data_o = {{24{raw_read_data_r[31]}}, raw_read_data_r[31:24]};
                endcase
            end
            3'b001: begin  // LH: 載入有符號半字
                case (delayed_address_low_r[1])
                    1'b0: read_data_o = {{16{raw_read_data_r[15]}}, raw_read_data_r[15:0]};
                    1'b1: read_data_o = {{16{raw_read_data_r[31]}}, raw_read_data_r[31:16]};
                endcase
            end
            3'b010: begin  // LW: 載入字
                read_data_o = raw_read_data_r;
            end
            3'b100: begin  // LBU: 載入無符號位元組
                case (delayed_address_low_r)
                    2'b00: read_data_o = {24'b0, raw_read_data_r[7:0]};
                    2'b01: read_data_o = {24'b0, raw_read_data_r[15:8]};
                    2'b10: read_data_o = {24'b0, raw_read_data_r[23:16]};
                    2'b11: read_data_o = {24'b0, raw_read_data_r[31:24]};
                endcase
            end
            3'b101: begin  // LHU: 載入無符號半字
                case (delayed_address_low_r[1])
                    1'b0: read_data_o = {16'b0, raw_read_data_r[15:0]};
                    1'b1: read_data_o = {16'b0, raw_read_data_r[31:16]};
                endcase
            end
            default: begin  // 預設情況
                read_data_o = raw_read_data_r;
            end
        endcase
    end
    
endmodule