echo "================================================================"
echo "CPU 最簡測試"
echo "================================================================"

# 創建最簡單的測試程序
cat > minitest.s << 'ASM'
.section .text
.globl _start
_start:
    # 測試1: 加載立即數到寄存器
    lui t0, 0x10000       # t0 = 0x10000000
    addi t1, zero, 0x42   # t1 = 0x42 ('B')
    
    # 測試2: 存儲到內存（UART地址）
    sw t1, 0(t0)          # 存儲到 UART
    
    # 測試3: 無窮循環（停止）
end:
    j end
ASM

# 編譯
echo "編譯測試程序..."
riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o minitest.o minitest.s
riscv64-unknown-elf-ld -Tlink.ld -o minitest.elf minitest.o
riscv64-unknown-elf-objcopy -O ihex minitest.elf minitest.hex

echo "生成的機器碼:"
hexdump -C minitest.hex

# 創建簡單的 testbench
cat > tb_mini.v << 'TBEOF'
`timescale 1ns/1ps

module tb_mini;
    reg clk;
    reg rst_n;
    wire uart_tx;
    
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx_o(uart_tx)
    );
    
    // 時鐘
    always #5 clk = ~clk;
    
    // 簡單的 UART 接收
    always @(negedge uart_tx) begin
        integer i;
        reg [7:0] data;
        
        // 簡單延遲模擬
        #8680; // 1 個位元時間（簡化）
        
        data = 0;
        for (i = 0; i < 8; i = i + 1) begin
            #8680;
            data[i] = uart_tx;
        end
        
        $display("[UART] 收到: 0x%02h ('%c')", data, data);
    end
    
    initial begin
        $dumpfile("cpu_mini.vcd");
        $dumpvars(0, tb_mini);
        
        clk = 0;
        rst_n = 0;
        
        #100;
        rst_n = 1;
        
        $display("CPU 測試開始");
        
        // 運行 1000 個時鐘週期
        #1000000;
        
        $display("測試完成");
        $finish;
    end
endmodule
TBEOF

# 更新 firmware.hex
cp minitest.hex firmware.hex

echo ""
echo "現在請手動運行測試："
echo "1. 確保 firmware.hex 已更新"
echo "2. 編譯並運行:"
echo "   iverilog -o cpu_mini.vvp tb_mini.v src/*.v"
echo "   vvp cpu_mini.vvp"
echo ""
echo "或者直接使用之前的測試腳本："
echo "   ./test_original_core.sh"