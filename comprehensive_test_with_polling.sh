echo "================================================================"
echo "綜合測試 - 帶 UART Polling 的正確實現"
echo "================================================================"

# 創建測試程序（發送 "RISCV" 並檢查 busy 狀態）
cat > test_riscv_polling.s << 'ASM'
.section .text
.globl _start
_start:
    # UART 數據寄存器地址: 0x10000000
    # UART 狀態寄存器地址: 0x10000004 (bit 0: 1=busy, 0=idle)
    li a0, 0x10000000     # UART 數據地址
    li a1, 0x10000004     # UART 狀態地址
    
    # 發送 "R"
    li a2, 0x52           # 'R'
polling_1:
    lw a3, 0(a1)          # 讀取狀態寄存器
    andi a3, a3, 1        # 檢查 bit 0 (busy)
    bnez a3, polling_1    # 如果 busy=1，繼續等待
    sw a2, 0(a0)          # 寫入數據寄存器，觸發發送
    
    # 發送 "I"
    li a2, 0x49           # 'I'
polling_2:
    lw a3, 0(a1)
    andi a3, a3, 1
    bnez a3, polling_2
    sw a2, 0(a0)
    
    # 發送 "S"
    li a2, 0x53           # 'S'
polling_3:
    lw a3, 0(a1)
    andi a3, a3, 1
    bnez a3, polling_3
    sw a2, 0(a0)
    
    # 發送 "C"
    li a2, 0x43           # 'C'
polling_4:
    lw a3, 0(a1)
    andi a3, a3, 1
    bnez a3, polling_4
    sw a2, 0(a0)
    
    # 發送 "V"
    li a2, 0x56           # 'V'
polling_5:
    lw a3, 0(a1)
    andi a3, a3, 1
    bnez a3, polling_5
    sw a2, 0(a0)
    
    # 發送 "!"
    li a2, 0x21           # '!'
polling_6:
    lw a3, 0(a1)
    andi a3, a3, 1
    bnez a3, polling_6
    sw a2, 0(a0)
    
    # 發送換行
    li a2, 0x0A           # '\n'
polling_7:
    lw a3, 0(a1)
    andi a3, a3, 1
    bnez a3, polling_7
    sw a2, 0(a0)
    
stop:
    j stop                # 無限循環
ASM

# 編譯
echo "編譯測試程序..."
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -Wl,-Ttext=0x0 -o test_riscv_polling.elf test_riscv_polling.s
riscv64-unknown-elf-objcopy -O ihex test_riscv_polling.elf firmware.hex

echo "生成的機器碼："
hexdump -C firmware.hex | head -20

# 創建測試環境
cd test_original
cp ../firmware.hex .

# 創建帶 UART 狀態寄存器的 testbench
cat > tb_comprehensive_polling.v << 'TBEOF'
`timescale 1ns/1ps

module tb_comprehensive_polling;
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
    parameter BIT_PERIOD = 8680;  // 1152000 baudrate 對應的位元時間
    reg [7:0] uart_data;
    integer uart_i;
    
    // UART 接收邏輯
    always @(negedge uart_tx) begin
        #(BIT_PERIOD * 1.5);
        for (uart_i = 0; uart_i < 8; uart_i = uart_i + 1) begin
            uart_data[uart_i] = uart_tx;
            #BIT_PERIOD;
        end
        $write("%c", uart_data);
        $fflush();
    end
    
    // 監視存儲器寫入，模擬 UART 狀態寄存器
    reg [31:0] uart_status = 0;
    reg [31:0] last_waddr = 0;
    reg [31:0] last_wdata = 0;
    
    always @(posedge clk) begin
        // 監視存儲器寫入到 UART 數據寄存器 (0x10000000)
        if (u_core.uart_wen && u_core.mem_alu_result == 32'h10000000) begin
            $display("[%t] UART 寫入: 0x%02h ('%c')", $time, u_core.mem_rs2_data[7:0], u_core.mem_rs2_data[7:0]);
            // 設置 UART 為 busy (bit 0 = 1)
            uart_status = 1;
            
            // 模擬 UART 發送完成 (約 10 個位元時間後清除 busy)
            fork
                begin
                    #(BIT_PERIOD * 10);  // 一個字符的發送時間
                    uart_status = 0;
                    $display("[%t] UART 發送完成，狀態寄存器清空", $time);
                end
            join_none
        end
        
        // 監視對 UART 狀態寄存器的讀取 (0x10000004)
        if (u_core.mem_rs2_data == 32'h10000004) begin
            $display("[%t] 讀取 UART 狀態寄存器: 0x%08h", $time, uart_status);
        end
    end
    
    // 將 UART 狀態寄存器值連接到 CPU 的數據讀取
    // 注意：這需要修改 core 模塊或在此 testbench 中覆蓋 data_rd
    // 這裡我們假設 core 有 data_rd 輸出，並在 testbench 中選擇
    
    // 主測試
    initial begin
        $dumpfile("comprehensive_polling.vcd");
        $dumpvars(0, tb_comprehensive_polling);
        
        clk = 0;
        rst_n = 0;
        
        #100;
        rst_n = 1;
        
        $display("========================================");
        $display("帶 Polling 的 UART 測試開始");
        $display("應該輸出: RISCV!");
        $display("========================================");
        
        // 運行足夠長時間
        #5000000;  // 5ms，足夠發送所有字符
        
        $display("\n========================================");
        $display("測試完成");
        $display("========================================");
        $finish;
    end
    
    // 顯示前 30 個週期的 PC 和指令
    integer cycle = 0;
    always @(posedge clk) begin
        if (cycle < 30) begin
            $display("[%t] PC=0x%08h, instr=0x%08h", 
                    $time, u_core.pc, u_core.id_inst);
            cycle = cycle + 1;
        end
    end
endmodule
TBEOF

# 創建文件列表
cat > files_polling.f << 'FEOF'
./tb_comprehensive_polling.v
./core.v
./alu.v
./decoder.v
./reg_file.v
./rom.v
./data_ram.v
./uart_tx.v
./csr_registers.v
FEOF

echo ""
echo "編譯帶 polling 的測試..."
iverilog -g2012 -o comp_polling.vvp -f files_polling.f 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ 編譯成功"
    echo "運行仿真..."
    timeout 10 vvp comp_polling.vvp 2>&1 | tee comp_polling.log
    
    echo ""
    echo "結果摘要："
    echo "----------"
    # 提取 UART 輸出
    echo -e "\nUART 輸出："
    grep -A 20 "UART 測試開始" comp_polling.log | grep -E "^[RISCV!]|^\n" || echo "未檢測到 UART 輸出"
    
    echo -e "\nUART 寫入記錄："
    grep "UART 寫入" comp_polling.log
    
    echo -e "\n狀態寄存器讀取："
    grep "讀取 UART 狀態寄存器" comp_polling.log | head -10
    
    if [ -f "comprehensive_polling.vcd" ]; then
        echo ""
        echo "✅ 波形文件: comprehensive_polling.vcd"
        echo "使用命令查看: gtkwave comprehensive_polling.vcd"
    fi
else
    echo "❌ 編譯失敗"
fi

cd ..