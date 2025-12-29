`timescale 1ns/1ps

module tb_uart_simple;

reg clk;
reg rst_n;
reg valid_i;
reg [7:0] data_i;
reg test_mode_i;
wire busy_o;
wire tx_o;

// 實例化 UART TX 模塊
uart_tx #(
    .CLK_FREQ(100000000),
    .BAUD_RATE(1152000)
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
always begin
    #5 clk = ~clk;
end

// 主測試流程
initial begin
    // 創建波形文件
    $dumpfile("uart_simple.vcd");
    $dumpvars(0, tb_uart_simple);
    
    $display("========================================");
    $display("UART TX 簡單測試");
    $display("========================================");
    
    // 初始化
    clk = 0;
    rst_n = 0;
    valid_i = 0;
    test_mode_i = 0;
    data_i = 8'h00;
    
    // 復位
    #100;
    rst_n = 1;
    #100;
    
    $display("[%0t] 測試 1: 發送字符 'A'", $time);
    
    // 發送 'A'
    data_i = "A";
    valid_i = 1;
    #10;
    valid_i = 0;
    
    // 等待發送完成
    #20000;
    
    $display("[%0t] 測試 2: 發送字符 'B'", $time);
    
    // 發送 'B'
    data_i = "B";
    valid_i = 1;
    #10;
    valid_i = 0;
    
    // 等待發送完成
    #20000;
    
    $display("[%0t] 測試 3: 測試模式", $time);
    test_mode_i = 1;
    
    // 等待測試模式發送
    #100000;
    
    $display("========================================");
    $display("測試完成");
    $display("========================================");
    $finish;
end

// 簡單的 UART 接收監控
integer bit_count;
reg [7:0] rx_byte;
integer state; // 0=等待起始位, 1=接收數據

initial begin
    bit_count = 0;
    rx_byte = 0;
    state = 0;
end

always @(negedge clk) begin
    case (state)
        0: begin // 等待起始位
            if (tx_o === 0) begin
                $display("[%0t] 檢測到起始位", $time);
                state = 1;
                bit_count = 0;
                rx_byte = 0;
            end
        end
        1: begin // 接收數據位
            // 簡單計數器 - 每 87 個時鐘週期採樣一次
            if (bit_count < 8) begin
                if (bit_count == 0) begin
                    // 等待 1.5 個位元時間後採樣第一個位元
                    #1300; // 1.5 * 868 ≈ 1300ns
                    rx_byte[0] = tx_o;
                    $display("[%0t] 採樣位元 0: %b", $time, tx_o);
                end else begin
                    #868; // 1 個位元時間
                    rx_byte[bit_count] = tx_o;
                    $display("[%0t] 採樣位元 %0d: %b", $time, bit_count, tx_o);
                end
                bit_count = bit_count + 1;
            end else begin
                // 接收完成
                #868; // 等待停止位
                $display("[%0t] 接收完成: 0x%02h ('%c')", $time, rx_byte, rx_byte);
                state = 0;
            end
        end
    endcase
end

endmodule
