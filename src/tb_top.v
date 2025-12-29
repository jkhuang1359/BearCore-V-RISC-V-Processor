`timescale 1ns / 1ps

module tb_top();

    // --- 1. 參數定義 (統一 100MHz) ---
    parameter CLK_FREQ = 100000000;        // 100 MHz
    parameter BAUDRATE = 1152000;          
    localparam CLK_PERIOD = 10;            // 10ns
    localparam BIT_PERIOD = 1000000000 / BAUDRATE; 

    reg         clk;
    reg         rst_n;
    reg         uart_rx_line;              
    wire        uart_tx_line;              

    // --- 2. 實例化核心 ---
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx_i(uart_rx_line),          
        .uart_tx_o(uart_tx_line)
    );


    // --- 3. 時脈產生 ---
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- 4. UART 發送任務 (Task) ---
    task send_user_input(input [7:0] char);
        integer i;
        begin
            $display("\n[TB_AUTO] >>> 傳送指令: '%c' (0x%h) <<<", char, char);
            uart_rx_line = 0; // Start
            #(BIT_PERIOD);
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx_line = char[i];
                #(BIT_PERIOD);
            end
            uart_rx_line = 1; // Stop
            #(BIT_PERIOD);
            #(BIT_PERIOD * 10); // 等待 CPU 處理
        end
    endtask

    // --- 5. 統一的自動測試腳本 (由指令觸發) ---
    reg [255:0] tx_string_buffer;
    integer     test_stage = 0;

    always @(posedge uart_char_ready) begin
        // 🏆 唯一的地方更新緩衝區
        tx_string_buffer = {tx_string_buffer[247:0], captured_char};
        
        // 偵測到選單提示
        if (tx_string_buffer[103:0] == "Select Test: ") begin
            test_stage = test_stage + 1;
            #(BIT_PERIOD * 100); 

            case (test_stage)
                1: send_user_input("a"); // 第一次選 CSR
                3: send_user_input(" "); //
                5: send_user_input(" "); // 
                7: send_user_input(" "); // 
                9: send_user_input(" "); // 
                11: send_user_input(" "); // 
                default: send_user_input(" ");
            endcase
            tx_string_buffer = 0; 
        end

        // 偵測到結束標籤
        if (tx_string_buffer[111:0] == "--- Test Completed ---") begin
            $display("\n[TB_AUTO] 🎉 恭喜主人！所有測試案例皆已自動通過。");
            #(CLK_PERIOD * 10); // 🏆 縮短到 10 週期，讓它立刻結束
            $finish;
        end
    end

    // --- 6. UART TX 解析 (Virtual Terminal) ---
    reg [7:0]  captured_char;
    reg        uart_char_ready;
    integer    bit_idx;

    initial begin
        uart_char_ready = 0;
        forever begin
            @(negedge uart_tx_line); 
            #(BIT_PERIOD / 2);       
            if (uart_tx_line == 0) begin
                #(BIT_PERIOD);       
                for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                    captured_char[bit_idx] = uart_tx_line;
                    #(BIT_PERIOD);
                end
                $write("%c", captured_char);
                $fflush();
                uart_char_ready = 1;
                #(CLK_PERIOD);
                uart_char_ready = 0;
            end
        end
    end

    // --- 7. 初始化與超時控制 ---
    initial begin
        //force u_core.u_uart.test_mode_i = 1;

        $display("--- BearCore-V 自動化模擬啟動 (100MHz / %0d Baud) ---", BAUDRATE);
        $dumpfile("cpu.vcd");
        $dumpvars(0, tb_top);

        rst_n = 0;
        uart_rx_line = 1;
        #(CLK_PERIOD * 20);
        rst_n = 1;

        // 🏆 如果 50ms 沒跑完就強制結束
        #(50_000_000); 
        $display("\n[TIMEOUT] 模擬超時，強制終止。");
        $finish; 
    end


endmodule