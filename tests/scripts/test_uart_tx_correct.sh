echo "================================================================"
echo "UART TX 模塊測試 (完全修正版)"
echo "================================================================"

# 創建測試目錄
rm -rf uart_test_correct
mkdir uart_test_correct
cd uart_test_correct

# 1. 複製並修改 UART TX 模塊以支持精確計時
cat > uart_tx_correct.v << 'UARTEOF'
module uart_tx_correct #(
    parameter CLK_FREQ = 100000000,
    parameter BAUD_RATE = 1152000
)(
    input clk,
    input rst_n,
    input [7:0] data_i,
    input valid_i,
    input test_mode_i,
    output busy_o,
    output reg tx_o
);

    // 計算位元時間（時鐘週期數）
    // 100,000,000 / 1,152,000 ≈ 86.8055
    // 我們取整到 87 以確保足夠時間
    localparam BIT_PERIOD = (CLK_FREQ + BAUD_RATE/2) / BAUD_RATE;
    
    reg [15:0] clk_cnt;
    reg [3:0] bit_cnt;
    reg [7:0] tx_data;
    reg active;
    
    // 測試 ROM
    reg [3:0] test_ptr;
    reg [7:0] test_rom [0:14];
    initial begin
        test_rom[0]="H"; test_rom[1]="e"; test_rom[2]="l"; test_rom[3]="l"; test_rom[4]="o";
        test_rom[5]="!"; test_rom[6]=" "; test_rom[7]="R"; test_rom[8]="I"; test_rom[9]="S";
        test_rom[10]="C"; test_rom[11]="-"; test_rom[12]="V"; test_rom[13]="!"; test_rom[14]="\n";
    end

    wire [7:0] final_data = (test_mode_i) ? test_rom[test_ptr] : data_i;
    wire final_valid = (test_mode_i) ? (test_ptr < 15 && !active) : valid_i;

    assign busy_o = active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 0;
            bit_cnt <= 0;
            tx_o <= 1;
            active <= 0;
            test_ptr <= 0;
        end else begin
            if (!active) begin
                if (final_valid) begin
                    tx_data <= final_data;
                    active <= 1;
                    clk_cnt <= 0;
                    bit_cnt <= 0;
                    tx_o <= 0; // Start bit
                    $display("[UART] 開始發送: 0x%02h ('%c')", final_data, final_data);
                end
            end else begin
                if (clk_cnt < BIT_PERIOD - 1) begin
                    clk_cnt <= clk_cnt + 1;
                end else begin
                    clk_cnt <= 0;
                    
                    if (bit_cnt < 8) begin
                        tx_o <= tx_data[bit_cnt];
                        $display("[UART] 發送位元 %0d: %b", bit_cnt, tx_data[bit_cnt]);
                        bit_cnt <= bit_cnt + 1;
                    end else if (bit_cnt == 8) begin
                        tx_o <= 1; // Stop bit
                        $display("[UART] 發送停止位");
                        bit_cnt <= bit_cnt + 1;
                    end else begin
                        active <= 0;
                        $display("[UART] 發送完成");
                        if (test_mode_i && test_ptr < 15) begin
                            test_ptr <= test_ptr + 1;
                        end
                    end
                end
            end
        end
    end
    
    // 顯示參數
    initial begin
        $display("[UART] CLK_FREQ = %0d, BAUD_RATE = %0d", CLK_FREQ, BAUD_RATE);
        $display("[UART] BIT_PERIOD = %0d 個時鐘週期", BIT_PERIOD);
        $display("[UART] 位元時間 = %0.3f ns", (1.0 * BIT_PERIOD * 10));
    end
    
endmodule
UARTEOF

# 2. 創建正確的 testbench
cat > tb_uart_correct.v << 'TBEOF'
`timescale 1ns/1ps

module tb_uart_correct;
    reg clk;
    reg rst_n;
    reg valid_i;
    reg [7:0] data_i;
    reg test_mode_i;
    wire busy_o;
    wire tx_o;
    
    // 實例化 UART TX 模塊
    uart_tx_correct u_uart (
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
    
    // 主測試流程
    initial begin
        integer i;
        reg [7:0] received_char;
        
        // 創建波形文件
        $dumpfile("uart_correct.vcd");
        $dumpvars(0, tb_uart_correct);
        
        $display("========================================");
        $display("UART TX 正確測試");
        $display("========================================");
        
        // 初始化
        valid_i = 0;
        test_mode_i = 0;
        data_i = 8'h00;
        rst_n = 0;
        #100;
        rst_n = 1;
        #1000;
        
        $display("\n[%0t] 測試 1: 手動發送 'A' (0x41)", $time);
        
        // 啟動發送
        data_i = 8'h41;  // 'A'
        valid_i = 1;
        @(posedge clk);
        valid_i = 0;
        
        // 等待發送開始
        wait(busy_o == 1);
        
        // 手動接收 UART 數據
        $display("[%0t] 開始接收...", $time);
        
        // 等待起始位 (下降沿)
        wait(tx_o == 0);
        $display("[%0t] 檢測到起始位", $time);
        
        // 等待 1.5 個位元時間（採樣點在數據位中間）
        #(87 * 10 * 1.5);  // 87 時鐘週期 * 10ns * 1.5
        
        // 讀取 8 個數據位
        received_char = 0;
        for (i = 0; i < 8; i = i + 1) begin
            received_char[i] = tx_o;
            $display("[%0t] 讀取位元 %0d: %b (數據: 0x%02h)", $time, i, tx_o, received_char);
            #(87 * 10);  // 等待 1 個位元時間
        end
        
        $display("[%0t] 接收完成: 0x%02h ('%c')", $time, received_char, received_char);
        
        // 等待停止位
        #(87 * 10);
        if (tx_o == 1) begin
            $display("[%0t] 停止位正確", $time);
        end else begin
            $display("[%0t] 錯誤: 停止位應為1, 實際為%b", $time, tx_o);
        end
        
        // 等待發送完成
        wait(busy_o == 0);
        #1000;
        
        $display("\n[%0t] 測試 2: 手動發送 'B' (0x42)", $time);
        
        // 啟動發送
        data_i = 8'h42;  // 'B'
        valid_i = 1;
        @(posedge clk);
        valid_i = 0;
        
        // 等待發送開始
        wait(busy_o == 1);
        
        // 等待起始位
        wait(tx_o == 0);
        
        // 等待 1.5 個位元時間後開始採樣
        #(87 * 10 * 1.5);
        
        // 讀取 8 個數據位
        received_char = 0;
        for (i = 0; i < 8; i = i + 1) begin
            received_char[i] = tx_o;
            #(87 * 10);
        end
        
        $display("[%0t] 接收完成: 0x%02h ('%c')", $time, received_char, received_char);
        
        // 等待發送完成
        wait(busy_o == 0);
        #1000;
        
        $display("\n[%0t] 測試 3: 測試模式", $time);
        test_mode_i = 1;
        
        // 等待測試模式發送幾個字符
        #500000;
        
        $display("\n========================================");
        $display("測試完成");
        $display("========================================");
        $finish;
    end
    
    // 簡單的自動接收器（僅用於顯示）
    always @(negedge tx_o) begin
        integer j;
        reg [7:0] auto_rx_data;
        
        if ($time > 200000) begin  // 避免初始復位時觸發
            $display("[%0t] 自動接收器: 檢測到起始位", $time);
            
            // 延遲避免被立即觸發
            #10;
            
            // 在後台接收
            fork
                begin
                    // 等待 1.5 個位元時間
                    #(87 * 10 * 1.5);
                    
                    auto_rx_data = 0;
                    for (j = 0; j < 8; j = j + 1) begin
                        auto_rx_data[j] = tx_o;
                        #(87 * 10);
                    end
                    
                    $display("[%0t] 自動接收器: 收到 0x%02h ('%c')", 
                            $time, auto_rx_data, auto_rx_data);
                end
            join_none
        end
    end
    
endmodule
TBEOF

# 3. 編譯和運行
echo ""
echo "編譯 UART TX 正確測試..."
iverilog -g2012 -o uart_correct.vvp tb_uart_correct.v uart_tx_correct.v 2>compile.log

if [ $? -eq 0 ]; then
    echo "✅ 編譯成功"
    echo ""
    echo "運行仿真..."
    vvp uart_correct.vvp 2>&1 | tee sim.log
    
    echo ""
    echo "仿真輸出:"
    echo "----------"
    grep -E "測試|UART|發送|接收|完成|錯誤" sim.log
    
    # 檢查波形文件
    if [ -f "uart_correct.vcd" ]; then
        echo ""
        echo "✅ 波形文件生成: uart_correct.vcd"
        echo "   大小: $(wc -c < uart_correct.vcd) 字節"
        echo ""
        echo "使用以下命令查看波形:"
        echo "  gtkwave uart_correct.vcd"
    fi
else
    echo "❌ 編譯失敗"
    cat compile.log
fi

# 回到上級目錄
cd ..

echo ""
echo "================================================================"
echo "UART TX 測試完成"echo "================================================================"
echo "UART TX 模塊測試 (完全修正版)"
echo "================================================================"

# 創建測試目錄
rm -rf uart_test_correct
mkdir uart_test_correct
cd uart_test_correct

# 1. 複製並修改 UART TX 模塊以支持精確計時
cat > uart_tx_correct.v << 'UARTEOF'
module uart_tx_correct #(
    parameter CLK_FREQ = 100000000,
    parameter BAUD_RATE = 1152000
)(
    input clk,
    input rst_n,
    input [7:0] data_i,
    input valid_i,
    input test_mode_i,
    output busy_o,
    output reg tx_o
);

    // 計算位元時間（時鐘週期數）
    // 100,000,000 / 1,152,000 ≈ 86.8055
    // 我們取整到 87 以確保足夠時間
    localparam BIT_PERIOD = (CLK_FREQ + BAUD_RATE/2) / BAUD_RATE;
    
    reg [15:0] clk_cnt;
    reg [3:0] bit_cnt;
    reg [7:0] tx_data;
    reg active;
    
    // 測試 ROM
    reg [3:0] test_ptr;
    reg [7:0] test_rom [0:14];
    initial begin
        test_rom[0]="H"; test_rom[1]="e"; test_rom[2]="l"; test_rom[3]="l"; test_rom[4]="o";
        test_rom[5]="!"; test_rom[6]=" "; test_rom[7]="R"; test_rom[8]="I"; test_rom[9]="S";
        test_rom[10]="C"; test_rom[11]="-"; test_rom[12]="V"; test_rom[13]="!"; test_rom[14]="\n";
    end

    wire [7:0] final_data = (test_mode_i) ? test_rom[test_ptr] : data_i;
    wire final_valid = (test_mode_i) ? (test_ptr < 15 && !active) : valid_i;

    assign busy_o = active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 0;
            bit_cnt <= 0;
            tx_o <= 1;
            active <= 0;
            test_ptr <= 0;
        end else begin
            if (!active) begin
                if (final_valid) begin
                    tx_data <= final_data;
                    active <= 1;
                    clk_cnt <= 0;
                    bit_cnt <= 0;
                    tx_o <= 0; // Start bit
                    $display("[UART] 開始發送: 0x%02h ('%c')", final_data, final_data);
                end
            end else begin
                if (clk_cnt < BIT_PERIOD - 1) begin
                    clk_cnt <= clk_cnt + 1;
                end else begin
                    clk_cnt <= 0;
                    
                    if (bit_cnt < 8) begin
                        tx_o <= tx_data[bit_cnt];
                        $display("[UART] 發送位元 %0d: %b", bit_cnt, tx_data[bit_cnt]);
                        bit_cnt <= bit_cnt + 1;
                    end else if (bit_cnt == 8) begin
                        tx_o <= 1; // Stop bit
                        $display("[UART] 發送停止位");
                        bit_cnt <= bit_cnt + 1;
                    end else begin
                        active <= 0;
                        $display("[UART] 發送完成");
                        if (test_mode_i && test_ptr < 15) begin
                            test_ptr <= test_ptr + 1;
                        end
                    end
                end
            end
        end
    end
    
    // 顯示參數
    initial begin
        $display("[UART] CLK_FREQ = %0d, BAUD_RATE = %0d", CLK_FREQ, BAUD_RATE);
        $display("[UART] BIT_PERIOD = %0d 個時鐘週期", BIT_PERIOD);
        $display("[UART] 位元時間 = %0.3f ns", (1.0 * BIT_PERIOD * 10));
    end
    
endmodule
UARTEOF

# 2. 創建正確的 testbench
cat > tb_uart_correct.v << 'TBEOF'
`timescale 1ns/1ps

module tb_uart_correct;
    reg clk;
    reg rst_n;
    reg valid_i;
    reg [7:0] data_i;
    reg test_mode_i;
    wire busy_o;
    wire tx_o;
    
    // 實例化 UART TX 模塊
    uart_tx_correct u_uart (
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
    
    // 主測試流程
    initial begin
        integer i;
        reg [7:0] received_char;
        
        // 創建波形文件
        $dumpfile("uart_correct.vcd");
        $dumpvars(0, tb_uart_correct);
        
        $display("========================================");
        $display("UART TX 正確測試");
        $display("========================================");
        
        // 初始化
        valid_i = 0;
        test_mode_i = 0;
        data_i = 8'h00;
        rst_n = 0;
        #100;
        rst_n = 1;
        #1000;
        
        $display("\n[%0t] 測試 1: 手動發送 'A' (0x41)", $time);
        
        // 啟動發送
        data_i = 8'h41;  // 'A'
        valid_i = 1;
        @(posedge clk);
        valid_i = 0;
        
        // 等待發送開始
        wait(busy_o == 1);
        
        // 手動接收 UART 數據
        $display("[%0t] 開始接收...", $time);
        
        // 等待起始位 (下降沿)
        wait(tx_o == 0);
        $display("[%0t] 檢測到起始位", $time);
        
        // 等待 1.5 個位元時間（採樣點在數據位中間）
        #(87 * 10 * 1.5);  // 87 時鐘週期 * 10ns * 1.5
        
        // 讀取 8 個數據位
        received_char = 0;
        for (i = 0; i < 8; i = i + 1) begin
            received_char[i] = tx_o;
            $display("[%0t] 讀取位元 %0d: %b (數據: 0x%02h)", $time, i, tx_o, received_char);
            #(87 * 10);  // 等待 1 個位元時間
        end
        
        $display("[%0t] 接收完成: 0x%02h ('%c')", $time, received_char, received_char);
        
        // 等待停止位
        #(87 * 10);
        if (tx_o == 1) begin
            $display("[%0t] 停止位正確", $time);
        end else begin
            $display("[%0t] 錯誤: 停止位應為1, 實際為%b", $time, tx_o);
        end
        
        // 等待發送完成
        wait(busy_o == 0);
        #1000;
        
        $display("\n[%0t] 測試 2: 手動發送 'B' (0x42)", $time);
        
        // 啟動發送
        data_i = 8'h42;  // 'B'
        valid_i = 1;
        @(posedge clk);
        valid_i = 0;
        
        // 等待發送開始
        wait(busy_o == 1);
        
        // 等待起始位
        wait(tx_o == 0);
        
        // 等待 1.5 個位元時間後開始採樣
        #(87 * 10 * 1.5);
        
        // 讀取 8 個數據位
        received_char = 0;
        for (i = 0; i < 8; i = i + 1) begin
            received_char[i] = tx_o;
            #(87 * 10);
        end
        
        $display("[%0t] 接收完成: 0x%02h ('%c')", $time, received_char, received_char);
        
        // 等待發送完成
        wait(busy_o == 0);
        #1000;
        
        $display("\n[%0t] 測試 3: 測試模式", $time);
        test_mode_i = 1;
        
        // 等待測試模式發送幾個字符
        #500000;
        
        $display("\n========================================");
        $display("測試完成");
        $display("========================================");
        $finish;
    end
    
    // 簡單的自動接收器（僅用於顯示）
    always @(negedge tx_o) begin
        integer j;
        reg [7:0] auto_rx_data;
        
        if ($time > 200000) begin  // 避免初始復位時觸發
            $display("[%0t] 自動接收器: 檢測到起始位", $time);
            
            // 延遲避免被立即觸發
            #10;
            
            // 在後台接收
            fork
                begin
                    // 等待 1.5 個位元時間
                    #(87 * 10 * 1.5);
                    
                    auto_rx_data = 0;
                    for (j = 0; j < 8; j = j + 1) begin
                        auto_rx_data[j] = tx_o;
                        #(87 * 10);
                    end
                    
                    $display("[%0t] 自動接收器: 收到 0x%02h ('%c')", 
                            $time, auto_rx_data, auto_rx_data);
                end
            join_none
        end
    end
    
endmodule
TBEOF

# 3. 編譯和運行
echo ""
echo "編譯 UART TX 正確測試..."
iverilog -o uart_correct.vvp tb_uart_correct.v uart_tx_correct.v 2>compile.log

if [ $? -eq 0 ]; then
    echo "✅ 編譯成功"
    echo ""
    echo "運行仿真..."
    vvp uart_correct.vvp 2>&1 | tee sim.log
    
    echo ""
    echo "仿真輸出:"
    echo "----------"
    grep -E "測試|UART|發送|接收|完成|錯誤" sim.log
    
    # 檢查波形文件
    if [ -f "uart_correct.vcd" ]; then
        echo ""
        echo "✅ 波形文件生成: uart_correct.vcd"
        echo "   大小: $(wc -c < uart_correct.vcd) 字節"
        echo ""
        echo "使用以下命令查看波形:"
        echo "  gtkwave uart_correct.vcd"
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
