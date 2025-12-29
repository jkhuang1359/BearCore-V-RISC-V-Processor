echo "================================================================"
echo "測試原始核心"
echo "================================================================"

# 創建測試目錄
rm -rf test_original
mkdir test_original
cd test_original

# 1. 創建 firmware.hex
cat > firmware.hex << 'HEXEOF'
100002b7
02100313
0062a023
0000006f
HEXEOF

# 2. 複製所有需要的文件
cp ../src/core.v .
cp ../src/alu.v .
cp ../src/decoder.v .
cp ../src/reg_file.v .
cp ../src/rom.v .
cp ../src/data_ram.v .
cp ../src/uart_tx.v .
cp ../src/csr_registers.v .

# 3. 創建一個簡單的 testbench
cat > tb_simple.v << 'TBEOF'
`timescale 1ns/1ps

module tb_simple;
    reg clk;
    reg rst_n;
    wire uart_tx;
    
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx_o(uart_tx)
    );
    
    // 時鐘生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // 簡單的 UART 接收器，只顯示字符
    parameter BIT_PERIOD = 8680;
    
    always @(negedge uart_tx) begin
        reg [7:0] data;
        integer i;
        
        #(BIT_PERIOD * 1.5);
        
        for (i = 0; i < 8; i = i + 1) begin
            data[i] = uart_tx;
            #BIT_PERIOD;
        end
        
        $write("UART輸出: '%c' (0x%h)\n", data, data);
        $fflush();
        
        #(BIT_PERIOD * 0.5);
    end
    
    // 主測試
    initial begin
        integer i;
        
        // 創建波形文件
        $dumpfile("original_core.vcd");
        $dumpvars(0, tb_simple);
        
        $display("========================================");
        $display("原始核心測試開始");
        $display("========================================");
        
        // 復位
        rst_n = 0;
        #100;
        rst_n = 1;
        $display("[%0t] 復位釋放", $time);
        
        // 運行 1000 個週期
        for (i = 0; i < 1000; i = i + 1) begin
            @(posedge clk);
            
            // 每 100 個週期報告一次
            if (i % 100 == 0) begin
                $display("[%0t] 週期 %0d", $time, i);
            end
        end
        
        $display("[%0t] 測試完成，運行 1000 個週期", $time);
        $display("========================================");
        $finish;
    end
    
    // 監視 PC 變化（前100個週期）
    integer pc_monitor_count = 0;
    
    always @(posedge clk) begin
        if (pc_monitor_count < 100) begin
            $display("[%0t] PC = 0x%08h", $time, u_core.pc);
            pc_monitor_count = pc_monitor_count + 1;
        end
    end
    
endmodule
TBEOF

# 4. 創建文件列表
cat > files.f << 'FEOF'
./tb_simple.v
./core.v
./alu.v
./decoder.v
./reg_file.v
./rom.v
./data_ram.v
./uart_tx.v
./csr_registers.v
FEOF

# 5. 編譯
echo ""
echo "編譯原始核心..."
iverilog -g2012 -o original.vvp -f files.f -I . 2>compile.log

if [ $? -eq 0 ]; then
    echo "✅ 編譯成功"
    echo ""
    echo "運行仿真..."
    timeout 3 vvp original.vvp 2>&1 | tee sim.log
    
    echo ""
    echo "仿真輸出摘要:"
    echo "--------------"
    
    # 檢查是否有 UART 輸出
    if grep -q "UART輸出" sim.log; then
        echo "✅ 檢測到 UART 輸出"
        grep "UART輸出" sim.log
    else
        echo "❌ 沒有 UART 輸出"
    fi
    
    # 檢查 PC 變化
    if grep -q "PC = " sim.log; then
        echo "✅ PC 在變化"
        echo "前幾個 PC 值:"
        grep "PC = " sim.log | head -5
    else
        echo "❌ PC 沒有變化"
    fi
    
    # 檢查波形文件
    if [ -f "original_core.vcd" ]; then
        echo "✅ 波形文件生成: original_core.vcd"
    else
        echo "❌ 波形文件未生成"
    fi
    
else
    echo "❌ 編譯失敗"
    cat compile.log
fi

# 6. 回到上級目錄
cd ..

echo ""
echo "================================================================"
echo "原始核心測試完成"
echo "================================================================"