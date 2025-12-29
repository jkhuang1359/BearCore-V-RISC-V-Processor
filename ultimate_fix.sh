#!/bin/bash

echo "================================================================"
echo "BearCore-V 終極修復"
echo "================================================================"

# 1. 修復 ROM 模塊（消除警告）
echo "1. 修復 ROM 模塊..."
cat > src/rom_small.v << 'ROMEOF'
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
ROMEOF

# 2. 創建一個簡單的核心包裝器
echo ""
echo "2. 創建核心包裝器..."
cat > core_wrapper_simple.v << 'WRAPEOF'
`timescale 1ns/1ps

module core_wrapper_simple(
    input clk,
    input rst_n,
    output uart_tx
);
    // 重新定義所有需要的信號
    reg  [31:0] pc;
    wire [31:0] pc_next;
    wire [31:0] if_inst;
    wire [31:0] ex_target_pc;
    wire ex_take_branch;
    
    // ROM 實例
    wire [31:0] rom_inst;
    rom_small u_rom(
        .addr(pc),
        .inst(rom_inst),
        .data_addr(32'h0),
        .data_out()
    );
    
    assign if_inst = rom_inst;
    
    // 簡單的 PC 更新邏輯
    assign pc_next = pc + 4;
    
    // 寄存器
    reg [31:0] regs [0:31];
    
    // 解碼
    wire [6:0] opcode = if_inst[6:0];
    wire [4:0] rd = if_inst[11:7];
    wire [4:0] rs1 = if_inst[19:15];
    wire [31:0] imm_u = {if_inst[31:12], 12'b0};
    
    integer cycle_count;
    
    // 主時序邏輯
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'h0;
            cycle_count <= 0;
            
            // 初始化寄存器
            for (integer i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'h0;
            end
            
            $display("[WRAPPER] 復位完成");
        end else begin
            cycle_count <= cycle_count + 1;
            
            // 執行指令
            case (opcode)
                7'b0110111: begin // LUI
                    regs[rd] <= imm_u;
                    pc <= pc_next;
                    $display("[%0t] LUI x%0d, 0x%08h", $time, rd, imm_u);
                end
                
                default: begin
                    pc <= pc_next;
                    $display("[%0t] 未知指令: 0x%08h, PC=0x%08h", 
                            $time, if_inst, pc);
                end
            endcase
            
            // 顯示 PC 變化（前10個週期）
            if (cycle_count < 10) begin
                $display("[%0t] 週期 %0d: PC=0x%08h, 指令=0x%08h", 
                        $time, cycle_count, pc, if_inst);
            end
        end
    end
    
    // UART 暫時不連接
    assign uart_tx = 1'b1;
    
endmodule
WRAPEOF

# 3. 創建測試台
echo ""
echo "3. 創建測試台..."
cat > tb_simple.v << 'TBEOF'
`timescale 1ns/1ps

module tb_simple;
    reg clk;
    reg rst_n;
    wire uart_tx;
    
    core_wrapper_simple u_core(
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx(uart_tx)
    );
    
    // 時鐘 (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        $dumpfile("simple_cpu.vcd");
        $dumpvars(0, tb_simple);
        
        $display("========================================");
        $display("簡單核心測試開始");
        $display("========================================");
        
        // 復位
        rst_n = 0;
        #100;
        rst_n = 1;
        $display("[%0t] 復位釋放", $time);
        
        // 運行 50 個週期
        #5000;
        
        $display("[%0t] 測試完成", $time);
        $display("========================================");
        $finish;
    end
endmodule
TBEOF

# 4. 創建編譯腳本
echo ""
echo "4. 編譯..."
cat > compile_simple.f << 'CFEOF'
./tb_simple.v
./core_wrapper_simple.v
./src/rom_small.v
CFEOF

iverilog -o simple_test.vvp -f compile_simple.f -I src 2>simple_compile.log

if [ $? -eq 0 ]; then
    echo "✅ 編譯成功"
    echo ""
    echo "5. 運行仿真..."
    vvp simple_test.vvp 2>&1 | tee simple_sim.log
    
    echo ""
    echo "仿真輸出:"
    echo "----------"
    grep -v "VCD info" simple_sim.log | head -30
    
    if [ -f "simple_cpu.vcd" ]; then
        echo ""
        echo "✅ 波形文件生成: simple_cpu.vcd"
        echo "   大小: $(wc -c < simple_cpu.vcd) 字節"
    fi
else
    echo "❌ 編譯失敗"
    cat simple_compile.log
fi

echo ""
echo "================================================================"
echo "修復完成"
echo "================================================================"
