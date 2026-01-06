`timescale 1ns/1ps  // <--- 🐻 關鍵修正：定義時間單位！
module reg_file(
    input clk,
    input rst_n,
    input [4:0] raddr1, output [31:0] rdata1,
    input [4:0] raddr2, output [31:0] rdata2,
    input wen, input [4:0] waddr, input [31:0] wdata
);
    reg [31:0] regs [0:31];
    integer i;

    initial begin
        for (i=0; i<32; i=i+1) regs[i] = 0;
        // 注意：link.ld 會初始化 SP，這裡設為 0 也可以，
        // 但保留 0x10000 作為保險是OK的。
        regs[2] = 32'h00008000; 
    end

    // 🏆 關鍵修正：實作 Write-First 邏輯 (Internal Forwarding)
    assign rdata1 = (raddr1 == 0) ? 32'b0 : 
                    (wen && (waddr == raddr1)) ? wdata : regs[raddr1];
    assign rdata2 = (raddr2 == 0) ? 32'b0 : 
                    (wen && (waddr == raddr2)) ? wdata : regs[raddr2];

    // 🏆 修正：改用同步/非同步重置，而非 initial，更符合 ASIC/FPGA 設計規範
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i=0; i<32; i=i+1) begin
                if (i == 2) regs[i] <= 32'h00008000; // 重置時初始化 SP 
                else regs[i] <= 32'h0;
            end
        end else if (wen && waddr != 0) begin
            regs[waddr] <= wdata;
        end
    end
endmodule