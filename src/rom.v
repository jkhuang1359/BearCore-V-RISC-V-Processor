`timescale 1ns/1ps  // <--- 🐻 關鍵修正：定義時間單位！
module rom (
    input [31:0] addr,
    output [31:0] inst,
    input [31:0] data_addr,     // 數據讀取地址
    output [31:0] data_out      // 數據讀取輸出    
);
    // 🏆 根據需要動態調整 ROM 大小
    parameter ROM_DEPTH = 16384;
    reg [31:0] mem [0:ROM_DEPTH-1];
    
    // 指令讀取
    wire [31:0] word_addr = addr >> 2;
    assign inst = (word_addr < ROM_DEPTH) ? mem[word_addr] : 32'h00000013; // nop
    
    // 數據讀取
    wire [31:0] data_word_addr = data_addr >> 2;
    assign data_out = (data_word_addr < ROM_DEPTH) ? mem[data_word_addr] : 32'h0;
    
    integer i;
    
    initial begin
        // 🏆 初始化為 nop 指令 (addi x0, x0, 0)
        for (i = 0; i < ROM_DEPTH; i = i + 1) begin
            mem[i] = 32'h00000013;  // nop
        end
        
        // 🏆 加載 firmware.hex
        if ($test$plusargs("debug")) begin
            $display("[ROM] 開始加載 firmware.hex");
        end
        
        $readmemh("firmware.hex", mem, 0, ROM_DEPTH-1);
        
        // 🏆 調試信息：顯示前幾條指令
        if ($test$plusargs("debug")) begin
            $display("[ROM] 加載的指令:");
            for (i = 0; i < 16; i = i + 1) begin
                if (mem[i] !== 32'h00000013) begin
                    $display("  [%0d] 0x%08h: 0x%08h", i, i*4, mem[i]);
                end
            end
        end
    end
endmodule