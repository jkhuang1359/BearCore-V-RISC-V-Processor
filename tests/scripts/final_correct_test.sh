echo "================================================================"
echo "最終正確測試 - 確保 firmware.hex 格式正確"
echo "================================================================"

# 錯誤處理函數
error_exit() {
    echo "❌ 錯誤: $1"
    exit 1
}

# 1. 生成正確格式的 firmware.hex（每行一個32位指令，沒有註釋）
echo "1. 生成正確格式的 firmware.hex..."
cat > firmware.hex << 'HEX'
10000537
04100593
00b52023
04200593
00b52023
04300593
00b52023
0000006f
HEX

echo "firmware.hex 內容 (正確格式):"
cat firmware.hex
echo ""
echo "每行指令:"
echo "10000537 = lui a0, 0x10000"
echo "04100593 = addi a1, zero, 0x41 ('A')"
echo "00b52023 = sw a1, 0(a0)"
echo "04200593 = addi a1, zero, 0x42 ('B')"
echo "00b52023 = sw a1, 0(a0)"
echo "04300593 = addi a1, zero, 0x43 ('C')"
echo "00b52023 = sw a1, 0(a0)"
echo "0000006f = jal zero, 0 (無限循環)"

# 2. 創建簡單的 testbench
echo ""
echo "2. 創建 testbench..."

cat > tb_final.v << 'TBEOF'
`timescale 1ns/1ps

module tb_final;
    reg clk;
    reg rst_n;
    wire uart_tx;
    
    // 實例化 core
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx_o(uart_tx)
    );
    
    // 時鐘 (100MHz)
    always #5 clk = ~clk;
    
    // UART 接收器
    reg [7:0] rx_data;
    reg [3:0] rx_bit_cnt;
    reg rx_receiving;
    integer rx_i;
    
    always @(negedge uart_tx) begin
        if (!rx_receiving) begin
            rx_receiving = 1;
            
            fork
                begin
                    // 等待 1.5 個位元時間
                    #13020;
                    
                    // 接收 8 個數據位
                    rx_data = 0;
                    for (rx_i = 0; rx_i < 8; rx_i = rx_i + 1) begin
                        #8680;
                        rx_data[rx_i] = uart_tx;
                    end
                    
                    // 等待停止位
                    #8680;
                    
                    $display("[%t] UART 收到: 0x%02h ('%c')", $time, rx_data, rx_data);
                    rx_receiving = 0;
                end
            join_none
        end
    end
    
    // 主測試
    initial begin
        $dumpfile("final.vcd");
        $dumpvars(0, tb_final);
        
        clk = 0;
        rst_n = 0;
        
        $display("========================================");
        $display("最終測試開始");
        $display("應該輸出: A B C");
        $display("========================================");
        
        // 復位
        #100;
        rst_n = 1;
        $display("[%t] 復位釋放", $time);
        
        // 等待足夠時間
        #2000000; // 2ms
        
        $display("========================================");
        $display("測試完成");
        $display("========================================");
        $finish;
    end
    
    // 監視 PC 變化
    integer cycle = 0;
    always @(posedge clk) begin
        if (cycle < 20) begin
            $display("[%t] 週期 %d: PC = 0x%08h", $time, cycle, u_core.pc);
            cycle = cycle + 1;
        end
    end
endmodule
TBEOF

# 3. 準備測試目錄
echo ""
echo "3. 準備測試環境..."
rm -rf test_final
mkdir test_final
cd test_final

# 複製檔案
cp ../firmware.hex .
cp ../tb_final.v .
cp ../src/*.v .

# 4. 編譯
echo ""
echo "4. 編譯仿真..."

# 創建文件列表
cat > files_final.f << 'FEOF'
tb_final.v
core.v
alu.v
decoder.v
reg_file.v
rom.v
data_ram.v
uart_tx.v
csr_registers.v
FEOF

echo "執行編譯命令: iverilog -o final.vvp -f files_final.f"
iverilog -g2012 -o final.vvp -f files_final.f 2> compile.log
COMPILE_RESULT=$?

echo ""
echo "編譯結果:"
if [ $COMPILE_RESULT -eq 0 ]; then
    echo "✅ 編譯成功"
    
    # 檢查是否有警告
    if [ -s compile.log ]; then
        echo "編譯警告:"
        cat compile.log
    fi
    
    echo ""
    echo "5. 運行仿真..."
    echo "執行: vvp final.vvp"
    vvp final.vvp 2>&1 | tee sim.log
    
    echo ""
    echo "測試結果摘要:"
    echo "--------------"
    
    # 檢查 UART 輸出
    if grep -q "UART 收到" sim.log; then
        echo "✅ 檢測到 UART 輸出:"
        grep "UART 收到" sim.log
    else
        echo "❌ 沒有檢測到 UART 輸出"
        echo ""
        echo "檢查 PC 是否正確執行指令:"
        grep "週期.*PC =" sim.log | head -10
    fi
    
    # 檢查波形文件
    if [ -f "final.vcd" ]; then
        echo ""
        echo "✅ 波形文件: final.vcd"
        echo "大小: $(wc -c < final.vcd) 字節"
    fi
else
    echo "❌ 編譯失敗"
    echo ""
    echo "錯誤訊息:"
    cat compile.log
    exit 1
fi

cd ..
echo ""
echo "================================================================"
echo "測試流程完成"
echo "================================================================"