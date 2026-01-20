`timescale 1ns/1ps
`include "include/riscv_defines.vh"

// =============================================================================
// 暫存器檔案模組 (Register File)
// 功能：
// 1. 實現 32 個 32-bit RISC-V 暫存器
// 2. 支援雙讀取端口和單寫入端口
// 3. 實現寫入優先 (Write-First) 內部轉發邏輯
// 4. x0 暫存器永遠為 0
// 5. 支援重置時初始化堆疊指標 (SP)
// =============================================================================
module register_file #(
    parameter STACK_TOP = 32'h0001F000
)(
    // 時脈與重置訊號
    input  wire        clk_i,                     // 時脈輸入
    input  wire        reset_ni,                  // 低態有效重置
    
    // 讀取端口 1
    input  wire [4:0]  read_address_1_i,          // 讀取地址 1
    output wire [31:0] read_data_1_o,             // 讀取資料 1
    
    // 讀取端口 2  
    input  wire [4:0]  read_address_2_i,          // 讀取地址 2
    output wire [31:0] read_data_2_o,             // 讀取資料 2
    
    // 寫入端口
    input  wire        write_enable_i,            // 寫入使能
    input  wire [4:0]  write_address_i,           // 寫入地址
    input  wire [31:0] write_data_i               // 寫入資料
);
    
    // ============================
    // 1. 內部暫存器宣告
    // ============================
    reg [31:0] register_array [0:31];             // 32 個 32-bit 暫存器
    integer initialization_index;                 // 初始化索引

    // ============================
    // 2. 為每個暫存器創建有別名的訊號（方便波形查看）
    // ============================
    
    // 關鍵暫存器別名
    wire [31:0] x0_zero = register_array[0];   // 硬體零值
    wire [31:0] x1_ra   = register_array[1];   // 返回地址
    wire [31:0] x2_sp   = register_array[2];   // 堆疊指針
    wire [31:0] x3_gp   = register_array[3];   // 全域指針
    wire [31:0] x4_tp   = register_array[4];   // 執行緒指針
    
    // 參數暫存器別名
    wire [31:0] x10_a0  = register_array[10];  // 參數/返回值0
    wire [31:0] x11_a1  = register_array[11];  // 參數/返回值1
    wire [31:0] x12_a2  = register_array[12];  // 參數2
    wire [31:0] x13_a3  = register_array[13];  // 參數3
    
    // 保存暫存器別名
    wire [31:0] x8_s0_fp = register_array[8];  // 保存暫存器0/框架指針
    wire [31:0] x9_s1    = register_array[9];  // 保存暫存器1
    
    // 臨時暫存器別名
    wire [31:0] x5_t0    = register_array[5];  // 臨時0
    wire [31:0] x6_t1    = register_array[6];  // 臨時1
    wire [31:0] x7_t2    = register_array[7];  // 臨時2    
    
    // ============================
    // 2. 寫入優先讀取邏輯 (內部轉發)
    // ============================
    
    // 讀取端口 1 邏輯
    assign read_data_1_o = 
        // 情況 1: 讀取 x0 暫存器 (永遠返回 0)
        (read_address_1_i == 5'b00000) ? 32'b0 : 
        // 情況 2: 內部轉發 (同週期寫入同一暫存器)
        (write_enable_i && (write_address_i == read_address_1_i)) ? write_data_i : 
        // 情況 3: 正常讀取
        register_array[read_address_1_i];
    
    // 讀取端口 2 邏輯  
    assign read_data_2_o = 
        // 情況 1: 讀取 x0 暫存器 (永遠返回 0)
        (read_address_2_i == 5'b00000) ? 32'b0 : 
        // 情況 2: 內部轉發 (同週期寫入同一暫存器)
        (write_enable_i && (write_address_i == read_address_2_i)) ? write_data_i : 
        // 情況 3: 正常讀取
        register_array[read_address_2_i];
    
    // ============================
    // 3. 暫存器寫入邏輯 (同步)
    // ============================
    always @(posedge clk_i or negedge reset_ni) begin
        if (!reset_ni) begin
            // 重置時初始化所有暫存器
            for (initialization_index = 0; initialization_index < 32; initialization_index = initialization_index + 1) begin
                // 特別初始化 x2 (sp) 暫存器為堆疊頂端地址
                if (initialization_index == 2) begin
                    register_array[initialization_index] <= STACK_TOP;     // 堆疊指標初始化
                end else begin
                    register_array[initialization_index] <= 32'h0;         // 其他暫存器清零
                end
            end
        end else if (write_enable_i && write_address_i != 5'b00000) begin
            // 正常寫入操作 (x0 暫存器不可寫入)
            register_array[write_address_i] <= write_data_i;
        end
    end
    
    // ============================
    // 4. 初始區塊 (僅用於模擬)
    // ============================
    initial begin
        // 模擬時初始化所有暫存器
        for (initialization_index = 0; initialization_index < 32; initialization_index = initialization_index + 1) begin
            register_array[initialization_index] = 32'h0;
        end
        
        // 初始化堆疊指標 (與重置邏輯保持一致)
        register_array[2] = 32'h0001F000;
    end
    
endmodule