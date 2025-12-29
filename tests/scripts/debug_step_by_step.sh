#!/bin/bash

echo "================================================================"
echo "BearCore-V 逐步調試"
echo "================================================================"

# 1. 創建測試目錄
mkdir -p debug_test
cd debug_test

# 2. 測試 Icarus Verilog 是否工作
echo ""
echo "1. 測試 Icarus Verilog 基本功能..."
cat > test_iverilog.v << 'TESTEOF'
`timescale 1ns/1ps

module test_iverilog;
    reg clk;
    
    initial begin
        $display("Icarus Verilog 工作正常!");
        clk = 0;
        #10;
        $display("時間推進測試通過");
        $finish;
    end
endmodule
TESTEOF

iverilog -o test1.vvp test_iverilog.v
vvp test1.vvp 2>&1 | grep "Icarus" && echo "✅ Icarus Verilog 測試通過" || echo "❌ Icarus Verilog 測試失敗"

# 3. 創建簡單的 ROM 測試
echo ""
echo "2. 測試 ROM 模塊..."
cat > rom_test.v << 'ROMEOF'
`timescale 1ns/1ps

module rom_test;
    reg [31:0] addr;
    wire [31:0] inst;
    
    // 實例化 ROM
    simple_rom u_rom(.addr(addr), .inst(inst));
    
    initial begin
        $display("ROM 測試:");
        
        addr = 32'h0;
        #10;
        $display("  addr=0x%08h, inst=0x%08h", addr, inst);
        
        addr = 32'h4;
        #10;
        $display("  addr=0x%08h, inst=0x%08h", addr, inst);
        
        $finish;
    end
endmodule
ROMEOF

# 複製 simple_rom.v
cp ../simple_rom.v .

iverilog -o rom_test.vvp rom_test.v simple_rom.v
vvp rom_test.vvp 2>&1 | grep -A5 "ROM 測試" && echo "✅ ROM 測試通過" || echo "❌ ROM 測試失敗"

# 4. 測試簡單核心
echo ""
echo "3. 測試簡單核心..."
cat > core_test.v << 'COREEOF'
`timescale 1ns/1ps

module core_test;
    reg clk;
    reg rst_n;
    wire uart_tx;
    
    simple_core u_core(
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx_o(uart_tx)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        $dumpfile("debug.vcd");
        $dumpvars(0, core_test);
        
        $display("簡單核心測試開始");
        
        // 復位
        rst_n = 0;
        #100;
        rst_n = 1;
        
        // 運行 50 個時鐘週期
        #5000;
        
        $display("測試完成");
        $finish;
    end
endmodule
COREEOF

# 複製 simple_core.v
cp ../simple_core.v .

echo "編譯簡單核心測試..."
iverilog -o core_test.vvp core_test.v simple_core.v simple_rom.v 2>compile.log

if [ $? -eq 0 ]; then
    echo "✅ 編譯成功"
    echo "運行仿真..."
    timeout 1 vvp core_test.vvp 2>&1 | tee sim.log
    
    if grep -q "UART 寫入" sim.log; then
        echo "✅ 檢測到 UART 寫入操作"
    else
        echo "❌ 未檢測到 UART 寫入"
        echo "仿真輸出:"
        tail -20 sim.log
    fi
else
    echo "❌ 編譯失敗"
    cat compile.log
fi

# 5. 回到上層目錄並測試真實核心
cd ..
echo ""
echo "4. 測試真實核心..."
cat > test_real_core.v << 'REALEOF'
`timescale 1ns/1ps

module test_real_core;
    reg clk;
    reg rst_n;
    wire uart_tx;
    
    // 實例化核心
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx_o(uart_tx)
    );
    
    // 時鐘生成 (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // 主測試流程
    initial begin
        integer i;
        
        // 創建波形文件
        $dumpfile("real_core.vcd");
        $dumpvars(0, test_real_core);
        
        $display("========================================");
        $display("真實核心測試開始");
        $display("========================================");
        
        // 初始狀態
        rst_n = 0;
        $display("[%0t] 系統復位中...", $time);
        
        // 保持復位 10 個時鐘週期
        repeat (10) @(posedge clk);
        
        // 釋放復位
        rst_n = 1;
        $display("[%0t] 釋放復位，開始執行程序", $time);
        
        // 運行 50 個時鐘週期並監視 PC
        for (i = 0; i < 50; i = i + 1) begin
            @(posedge clk);
            
            // 每 5 個週期報告一次狀態
            if (i % 5 == 0) begin
                $display("[%0t] 週期 %0d: PC = 0x%08h", 
                        $time, i, u_core.pc);
            end
            
            // 如果 PC 停止變化，提前結束
            if (i > 10 && u_core.pc == u_core.pc) begin
                // 檢查是否卡住
                if (u_core.pc == u_core.pc) begin
                    $display("[%0t] PC 卡在 0x%08h，提前結束", 
                            $time, u_core.pc);
                    break;
                end
            end
        end
        
        $display("[%0t] 測試完成", $time);
        $display("========================================");
        $finish;
    end
    
endmodule
REALEOF

# 使用我們的測試程序
echo "lui t0, 0x10000" > firmware.hex
echo "addi t1, x0, 33" >> firmware.hex  # 33 = '!'
echo "sw t1, 0(t0)" >> firmware.hex
echo "jal x0, 0" >> firmware.hex  # 無限循環

echo "編譯真實核心測試..."
iverilog -o real_core.vvp -f files.f -I src test_real_core.v 2>real_compile.log

if [ $? -eq 0 ]; then
    echo "✅ 真實核心編譯成功"
    echo "運行仿真..."
    timeout 2 vvp real_core.vvp 2>&1 | tee real_sim.log
    
    if [ -f "real_core.vcd" ]; then
        echo "✅ 波形文件生成成功: real_core.vcd"
        echo "  文件大小: $(wc -c < real_core.vcd) 字節"
    fi
    
    echo ""
    echo "仿真輸出摘要:"
    echo "--------------"
    grep -E "週期|PC|復位|測試" real_sim.log || tail -20 real_sim.log
else
    echo "❌ 真實核心編譯失敗"
    cat real_compile.log
fi

echo ""
echo "================================================================"
echo "調試完成"
echo "================================================================"