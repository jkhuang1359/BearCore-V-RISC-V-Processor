echo "================================================================"
echo "修復所有問題並測試"
echo "================================================================"

# 回到項目根目錄
cd ~/projects/my_riscv_core

# 1. 創建正確的 firmware.hex（無註釋）
echo "創建正確的 firmware.hex..."
cat > correct_firmware.hex << 'HEX'
100002b7
02100313
0062a023
00000013
00000013
00000013
00000013
00000013
HEX

echo "正確的 firmware.hex 內容："
cat correct_firmware.hex

# 2. 修復 tb_simple.v 中的語法錯誤
echo ""
echo "修復 tb_simple.v 中的語法錯誤..."
cd test_original

cat > tb_simple_fixed.v << 'TBEOF'
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
    
    reg [7:0] uart_data;
    integer uart_i;
    
    always @(negedge uart_tx) begin
        #(BIT_PERIOD * 1.5);
        
        for (uart_i = 0; uart_i < 8; uart_i = uart_i + 1) begin
            uart_data[uart_i] = uart_tx;
            #BIT_PERIOD;
        end
        
        $write("UART輸出: '%c' (0x%h)\n", uart_data, uart_data);
        $fflush();
    end
    
    // 主測試
    initial begin
        integer i;
        
        // 創建波形文件
        $dumpfile("original_core_fixed.vcd");
        $dumpvars(0, tb_simple);
        
        $display("========================================");
        $display("原始核心測試（修復版）");
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
        #1000000
        $finish;
    end
    
    // 監視 PC 變化（前100個週期）
    integer pc_monitor_count = 0;
    always @(posedge clk) begin
        if (pc_monitor_count < 100) begin
            $display("[%0t] PC = 0x%08h, instr = 0x%08h", $time, u_core.pc, u_core.id_inst);
            pc_monitor_count = pc_monitor_count + 1;
        end
    end
    
endmodule
TBEOF

# 3. 更新 firmware.hex
cp ../correct_firmware.hex firmware.hex

# 4. 創建修復的文件列表
cat > files_fixed.f << 'FEOF'
./tb_simple_fixed.v
./core.v
./alu.v
./decoder.v
./reg_file.v
./rom.v
./data_ram.v
./uart_tx.v
./csr_registers.v
FEOF

# 5. 編譯和運行
echo ""
echo "編譯修復版本..."
iverilog -g2012 -o original_fixed.vvp -f files_fixed.f 2>compile_fixed.log

if [ $? -eq 0 ]; then
    echo "✅ 編譯成功"
    echo ""
    echo "運行仿真..."
    timeout 3 vvp original_fixed.vvp 2>&1 | tee sim_fixed.log
    
    echo ""
    echo "仿真輸出摘要:"
    echo "--------------"
    
    # 檢查是否有 UART 輸出
    if grep -q "UART輸出" sim_fixed.log; then
        echo "✅ 檢測到 UART 輸出"
        grep "UART輸出" sim_fixed.log
    else
        echo "❌ 沒有 UART 輸出"
    fi
    
    # 檢查 PC 和指令
    echo ""
    echo "前幾個 PC 和指令:"
    grep "PC = " sim_fixed.log | head -10
    
    # 檢查波形文件
    if [ -f "original_core_fixed.vcd" ]; then
        echo ""
        echo "✅ 波形文件生成: original_core_fixed.vcd"
    else
        echo "❌ 波形文件未生成"
    fi
    
    # 檢查是否有錯誤
    if grep -q "error" sim_fixed.log; then
        echo ""
        echo "❌ 仿真中有錯誤:"
        grep "error" sim_fixed.log
    fi
    
else
    echo "❌ 編譯失敗"
    cat compile_fixed.log
fi

# 回到項目根目錄
cd ..

echo ""
echo "================================================================"
echo "修復完成"
echo "================================================================"
