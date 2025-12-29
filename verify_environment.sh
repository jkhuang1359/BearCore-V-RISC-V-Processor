echo "================================================"
echo "RISC-V 硬體環境系統性驗證"
echo "================================================"

# 1. 創建驗證程序
cat > verify.s << 'ASM_EOF'
.text
.globl _start
_start:
    # 測試1: 寄存器操作
    li x1, 0x11111111
    li x2, 0x22222222
    li x3, 0x33333333
    
    # 測試2: 算術指令
    add x4, x1, x2      # x4 = 0x33333333
    sub x5, x2, x1      # x5 = 0x11111111
    
    # 測試3: 內存存儲/加載
    li sp, 0x00001000   # 設置堆疊指針
    sw x1, 0(sp)
    sw x2, 4(sp)
    lw x6, 0(sp)        # x6 應該 = 0x11111111
    lw x7, 4(sp)        # x7 應該 = 0x22222222
    
    # 測試4: 比較和分支
    beq x6, x1, branch_ok1
    j test_fail
    
branch_ok1:
    bne x7, x2, test_fail
    j branch_ok2
    
branch_ok2:
    # 測試5: 跳轉和鏈接
    jal x8, target_func
    j test_success
    
target_func:
    addi x9, x0, 1
    jalr x0, x8, 0
    
test_fail:
    # 失敗標記
    li x10, 0xBADBAD
    j end
    
test_success:
    # 成功標記
    li x10, 0x600D600D
    j end
    
end:
    j end
ASM_EOF

echo "✅ 創建驗證程序"

# 2. 編譯和鏈接
echo ""
echo "2. 編譯驗證程序..."
riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o verify.o verify.s
riscv64-unknown-elf-ld -Ttext=0x0 -o verify.elf verify.o

if [ $? -ne 0 ]; then
    echo "❌ 編譯失敗"
    exit 1
fi

# 3. 生成多種格式的二進制文件
echo ""
echo "3. 生成二進制文件..."
riscv64-unknown-elf-objcopy -O binary verify.elf verify.bin

# 轉換為 hex 格式（每行32位）
hexdump -v -e '1/4 "%08x\n"' verify.bin > firmware.hex

echo "生成的指令："
riscv64-unknown-elf-objdump -d verify.elf

# 4. 創建驗證 testbench
echo ""
echo "4. 創建驗證 testbench..."

cat > tb_verify.v << 'TB_EOF'
`timescale 1ns/1ps

module tb_verify;
    reg clk;
    reg rst_n;
    
    // 實例化核心
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx_o()  // 不測試UART
    );
    
    // 時鐘 (50MHz)
    always #10 clk = ~clk;
    
    // 監視重要寄存器
    wire [31:0] x1 = u_core.u_reg_file.reg_file[1];
    wire [31:0] x2 = u_core.u_reg_file.reg_file[2];
    wire [31:0] x10 = u_core.u_reg_file.reg_file[10];
    
    // 測試狀態
    reg test_passed = 0;
    reg test_failed = 0;
    
    integer cycle_count = 0;
    
    always @(posedge clk) begin
        if (rst_n) begin
            cycle_count <= cycle_count + 1;
            
            // 檢查是否設置了成功標記
            if (x10 == 32'h600D600D && !test_passed) begin
                test_passed <= 1;
                $display("[%t] ✅ 測試通過! x10 = 0x%h", $time, x10);
                $display("    總週期數: %0d", cycle_count);
            end
            
            // 檢查是否設置了失敗標記
            if (x10 == 32'hBADBAD && !test_failed) begin
                test_failed <= 1;
                $display("[%t] ❌ 測試失敗! x10 = 0x%h", $time, x10);
            end
            
            // 安全停止
            if (cycle_count > 1000) begin
                if (!test_passed && !test_failed) begin
                    $display("[%t] ⚠️  測試超時，未達到終止條件", $time);
                    $display("    PC = 0x%h", u_core.pc);
                    $display("    x10 = 0x%h", x10);
                end
                $finish;
            end
        end
    end
    
    // 主測試
    initial begin
        $dumpfile("verify.vcd");
        $dumpvars(0, tb_verify);
        
        clk = 0;
        rst_n = 0;
        
        $display("========================================");
        $display("硬體環境驗證測試");
        $display("========================================");
        
        // 復位
        #100;
        rst_n = 1;
        $display("[%t] 復位釋放", $time);
        
        // 等待測試完成
        #200000;
        
        $display("========================================");
        $display("測試完成");
        if (test_passed) begin
            $display("結果: ✅ 通過");
        end else if (test_failed) begin
            $display("結果: ❌ 失敗");
        end else begin
            $display("結果: ⚠️  未定");
        end
        $display("========================================");
        $finish;
    end
    
    // 顯示前50個週期的執行情況
    integer display_cycle = 0;
    always @(posedge clk) begin
        if (rst_n && display_cycle < 50) begin
            $display("[%t] 週期 %0d: PC=0x%08h, instr=0x%08h", 
                    $time, display_cycle, u_core.pc, u_core.instr);
            display_cycle <= display_cycle + 1;
        end
    end
endmodule
TB_EOF

echo "✅ 創建驗證 testbench"

# 5. 準備仿真文件
echo ""
echo "5. 準備仿真文件..."
cat > files_verify.f << 'FEOF'
tb_verify.v
core.v
alu.v
decoder.v
reg_file.v
rom.v
data_ram.v
uart_tx.v
csr_registers.v
FEOF

# 6. 編譯仿真
echo ""
echo "6. 編譯仿真..."
iverilog -g2012 -o verify.vvp -f files_verify.f 2> compile.log

if [ $? -ne 0 ]; then
    echo "❌ 仿真編譯失敗"
    cat compile.log
    exit 1
fi

echo "✅ 仿真編譯成功"

# 7. 運行仿真
echo ""
echo "7. 運行仿真..."
vvp verify.vvp 2>&1 | tee simulation.log

echo ""
echo "========================================"
echo "驗證結果摘要"
echo "========================================"

# 檢查結果
if grep -q "測試通過" simulation.log; then
    echo "✅ 硬體環境基本功能正常"
    echo ""
    echo "下一步：測試UART功能"
else
    echo "❌ 硬體環境有問題"
    echo ""
    echo "需要檢查："
    echo "1. 指令解碼 (decoder.v)"
    echo "2. 寄存器文件 (reg_file.v)"
    echo "3. ALU (alu.v)"
    echo "4. 記憶體接口 (rom.v, data_ram.v)"
    echo ""
    echo "查看波形："
    echo "gtkwave verify.vcd"
fi

echo ""
echo "前20條指令執行情況："
grep "週期.*PC=" simulation.log | head -20

cd ..
