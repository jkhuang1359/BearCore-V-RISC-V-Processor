echo "================================================================"
echo "UART TX 模塊測試 (修正版)"
echo "================================================================"

# 創建測試目錄
rm -rf uart_test_fixed
mkdir uart_test_fixed
cd uart_test_fixed

# 1. 複製 UART TX 模塊
cp ../src/uart_tx.v .

# 2. 創建修正的 UART TX testbench
cat > tb_uart_tx.v << 'TBEOF'
`timescale 1ns/1ps

module tb_uart_tx;
    reg clk;
    reg rst_n;
    reg valid_i;
    reg [7:0] data_i;
    reg test_mode_i;
    wire busy_o;
    wire tx_o;
    
    // 實例化 UART TX 模塊，設置 baudrate 為 1152000
    uart_tx #(
        .CLK_FREQ(100_000_000),   // 100 MHz 時鐘
        .BAUD_RATE(1_152_000)     // 1.152 Mbps
    ) u_uart_tx (
        .clk(clk),
        .rst_n(rst_n),
        .data_i(data_i),
        .valid_i(valid_i),
        .test_mode_i(test_mode_i),
        .busy_o(busy_o),
        .tx_o(tx_o)
    );
    
    // 時鐘生成 (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // UART 接收器（軟件模擬）
    task receive_uart;
        output [7:0] received_data;
        begin
            integer i;
            received_data = 0;
            
            // 等待起始位
            while (tx_o == 1) @(posedge clk);
            
            // 等待 1.5 個位元時間（1152000 baudrate 的位元時間約 868ns）
            repeat(8680/10) @(posedge clk); // 8680ns / 10ns = 868 個時鐘週期
            
            // 讀取 8 個數據位
            for (i = 0; i < 8; i = i + 1) begin
                repeat(868/10) @(posedge clk); // 等待 1 個位元時間
                received_data[i] = tx_o;
            end
            
            // 等待停止位
            repeat(868/10) @(posedge clk); // 等待 1 個位元時間
        end
    endtask
    
    // 主測試流程
    initial begin
        integer i;
        reg [7:0] rx_data;
        
        // 創建波形文件
        $dumpfile("uart_tx.vcd");
        $dumpvars(0, tb_uart_tx);
        
        $display("========================================");
        $display("UART TX 測試開始");
        $display("========================================");
        
        // 初始化
        valid_i = 0;
        test_mode_i = 0;
        data_i = 8'h00;
        rst_n = 0;
        #100;
        rst_n = 1;
        #100;
        
        $display("[%0t] 復位完成，開始測試", $time);
        
        // 測試 1: 發送字符 'A' (0x41)
        $display("\n--- 測試 1: 發送 'A' (0x41) ---");
        data_i = 8'h41;  // 'A'
        valid_i = 1;
        @(posedge clk);
        valid_i = 0;
        
        // 等待發送開始
        wait(busy_o == 1);
        $display("[%0t] TX 開始: 數據=0x%02h ('%c')", $time, data_i, data_i);
        
        // 接收數據
        receive_uart(rx_data);
        $display("[%0t] UART RX: 收到數據 0x%02h ('%c')", $time, rx_data, rx_data);
        
        // 等待發送完成
        wait(busy_o == 0);
        $display("[%0t] TX 完成", $time);
        #1000;
        
        // 測試 2: 發送字符 'B' (0x42)
        $display("\n--- 測試 2: 發送 'B' (0x42) ---");
        data_i = 8'h42;  // 'B'
        valid_i = 1;
        @(posedge clk);
        valid_i = 0;
        
        // 等待發送開始
        wait(busy_o == 1);
        $display("[%0t] TX 開始: 數據=0x%02h ('%c')", $time, data_i, data_i);
        
        // 接收數據
        receive_uart(rx_data);
        $display("[%0t] UART RX: 收到數據 0x%02h ('%c')", $time, rx_data, rx_data);
        
        // 等待發送完成
        wait(busy_o == 0);
        $display("[%0t] TX 完成", $time);
        #1000;
        
        // 測試 3: 測試模式
        $display("\n--- 測試 3: 測試模式 (發送 'Hello! RISCV!') ---");
        test_mode_i = 1;
        #10;
        
        // 等待測試模式發送完成
        wait(u_uart_tx.test_ptr == 15);
        wait(busy_o == 0);
        #1000;
        
        $display("\n========================================");
        $display("UART TX 測試完成");
        $display("========================================");
        $finish;
    end
    
endmodule
TBEOF

# 3. 創建編譯文件
cat > compile.f << 'FEOF'
tb_uart_tx.v
uart_tx.v
FEOF

# 4. 編譯和運行
echo ""
echo "編譯 UART TX 測試..."
iverilog -g2012 -o uart_tx.vvp -f compile.f 2>compile.log

if [ $? -eq 0 ]; then
    echo "✅ 編譯成功"
    echo ""
    echo "運行仿真..."
    vvp uart_tx.vvp 2>&1 | tee sim.log
    
    echo ""
    echo "仿真輸出:"
    echo "----------"
    grep -E "測試|TX|RX|完成" sim.log
    
    # 檢查波形文件
    if [ -f "uart_tx.vcd" ]; then
        echo ""
        echo "✅ 波形文件生成: uart_tx.vcd"
        echo "   大小: $(wc -c < uart_tx.vcd) 字節"
        echo ""
        echo "使用以下命令查看波形:"
        echo "  gtkwave uart_tx.vcd"
    fi
else
    echo "❌ 編譯失敗"
    cat compile.log
fi

# 回到上級目錄
cd ..

echo ""
echo "================================================================"
echo "UART TX 測試完成"
echo "================================================================"
