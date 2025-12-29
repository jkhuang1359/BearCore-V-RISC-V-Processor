`timescale 1ns/1ps

module rom_small(
    input [31:0] addr,
    output [31:0] inst,
    input [31:0] data_addr,
    output [31:0] data_out
);
    // 很小的 ROM，只有 8 個字
    reg [31:0] mem [0:7];
    
    // 地址計算
    wire [2:0] word_addr = addr[4:2];  // 只取低位，忽略高位
    
    assign inst = mem[word_addr];
    assign data_out = mem[data_addr[4:2]];
    
    integer i;
    
    initial begin
        $display("[ROM] 初始化 8 字 ROM");
        
        // 初始化為 nop
        for (i = 0; i < 8; i = i + 1) begin
            mem[i] = 32'h00000013;  // nop
        end
        
        // 直接設置測試程序
        mem[0] = 32'h100002b7;  // lui t0, 0x10000
        mem[1] = 32'h02100313;  // li t1, 33 ('!')
        mem[2] = 32'h0062a023;  // sw t1, 0(t0)
        mem[3] = 32'h0000006f;  // j .
        
        $display("[ROM] 程序加載完成");
        for (i = 0; i < 4; i = i + 1) begin
            $display("  [%0d] 0x%08h", i, mem[i]);
        end
    end
endmodule
