echo "================================================================"
echo "正確的 UART 測試"
echo "================================================================"

# 錯誤處理函數
error_exit() {
    echo "❌ 錯誤: $1"
    exit 1
}

# 1. 檢查 core.v 介面
echo "1. 檢查 core.v 介面..."
if [ ! -f "src/core.v" ]; then
    error_exit "src/core.v 不存在"
fi

echo "core.v 模塊定義:"
grep -A 5 "^module core" src/core.v

# 2. 生成正確格式的 firmware.hex
echo ""
echo "2. 生成正確格式的 firmware.hex..."

# 創建簡單的測試程序（直接寫入指令碼）
cat > firmware.hex << 'HEX'
10000537  # lui a0, 0x10000
04100593  # addi a1, zero, 0x41
00b52023  # sw a1, 0(a0)
04200593  # addi a1, zero, 0x42
00b52023  # sw a1, 0(a0)
04300593  # addi a1, zero, 0x43
00b52023  # sw a1, 0(a0)
0000006f  # j 0 (無限循環)
HEX

echo "firmware.hex 內容 (純十六進制):"
cat firmware.hex

# 3. 創建簡單的 testbench（只使用已知介面）
echo ""
echo "3. 創建 testbench..."

cat > tb_correct.v << 'TBEOF'
`timescale 1ns/1ps

module tb_correct;
    reg clk;
    reg rst_n;
    wire uart_tx;
    
    // 只使用已知的端口
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx_o(uart_tx)
    );
    
    // 時鐘 (100MHz)
    always #5 clk = ~clk;
    
    // 簡單的 UART 接收器
    reg [7:0] rx_data;
    reg [3:0] rx_bit_cnt;
    reg rx_receiving;
    
    always @(negedge uart_tx) begin
        if (!rx_receiving) begin
            rx_receiving = 1;
            rx_bit_cnt = 0;
            rx_data = 0;
            
            // 等待 1.5 個位元時間後開始採樣
            #13020; // 1.5 * 8680ns
            
            // 使用 fork 在後台接收
            fork
                begin
                    // 接收 8 個數據位
                    repeat(8) begin
                        #8680; // 1 個位元時間
                        rx_data[rx_bit_cnt] = uart_tx;
                        rx_bit_cnt = rx_bit_cnt + 1;
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
        $dumpfile("correct.vcd");
        $dumpvars(0, tb_correct);
        
        clk = 0;
        rst_n = 0;
        
        $display("========================================");
        $display("正確 UART 測試開始");
        $display("應該輸出: A B C");
        $display("========================================");
        
        // 復位
        #100;
        rst_n = 1;
        $display("[%t] 復位釋放", $time);
        
        // 監視前幾個週期
        repeat(20) @(posedge clk);
        
        // 等待足夠時間讓 UART 發送
        #500000; // 0.5ms
        
        $display("========================================");
        $display("測試完成");
        $display("========================================");
        $finish;
    end
    
    // 監視 PC 變化
    integer cycle = 0;
    always @(posedge clk) begin
        if (cycle < 15) begin
            $display("[%t] 週期 %d: PC = 0x%08h", $time, cycle, u_core.pc);
            cycle = cycle + 1;
        end
    end
endmodule
TBEOF

# 4. 複製所需文件到測試目錄
echo ""
echo "4. 準備測試環境..."
rm -rf test_correct
mkdir test_correct
cd test_correct

cp ../firmware.hex .
cp ../tb_correct.v .
cp ../src/*.v .

# 5. 編譯
echo ""
echo "5. 編譯仿真..."
cat > files_correct.f << FEOF
tb_correct.v
core.v
alu.v
decoder.v
reg_file.v
rom.v
data_ram.v
uart_tx.v
csr_registers.v
FEOF

iverilog -g2012 -o correct.vvp -f files_correct.f 2> compile.log
COMPILE_RESULT=$?

echo "編譯結果:"
if [ $COMPILE_RESULT -eq 0 ]; then
    echo "✅ 編譯成功"
    cat compile.log
    
    echo ""
    echo "6. 運行仿真..."
    timeout 3 vvp correct.vvp 2>&1 | tee sim.log
    
    echo ""
    echo "測試結果摘要:"
    echo "--------------"
    
    if grep -q "UART 收到" sim.log; then
        echo "✅ UART 輸出檢測到:"
        grep "UART 收到" sim.log
    else
        echo "❌ 沒有檢測到 UART 輸出"
        echo "最後 20 行輸出:"
        tail -20 sim.log
    fi
    
    if [ -f "correct.vcd" ]; then
        echo ""
        echo "✅ 波形文件: correct.vcd"
        echo "大小: $(wc -c < correct.vcd) 字節"
    fi
else
    echo "❌ 編譯失敗"
    echo "錯誤訊息:"
    cat compile.log
    exit 1
fi

cd ..
echo ""
echo "================================================================"
echo "測試流程完成"
echo "================================================================"
