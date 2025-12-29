echo "=== RISC-V CPU 編譯和測試腳本 ==="

# 檢查必要文件
echo "1. 檢查必要文件..."
REQUIRED_FILES=("alu.v" "decoder.v" "reg_file.v" "rom.v" "data_ram.v" "csr_registers.v" "uart_tx.v" "core.v")
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ 缺少: $file"
        exit 1
    fi
done

# 檢查測試程序
echo -e "\n2. 檢查測試程序..."
if [ -f "firmware.hex" ]; then
    echo "  ✅ firmware.hex 已存在"
    echo "  前5行內容:"
    head -5 firmware.hex
else
    echo "  ⚠️  未找到 firmware.hex，將創建一個簡單的測試程序"
    # 創建一個簡單的測試程序
    echo "00100093" > firmware.hex  # addi x1, x0, 1
    echo "00100113" >> firmware.hex # addi x2, x0, 1  
    echo "00808063" >> firmware.hex # beq x1, x2, 16
    echo "00000013" >> firmware.hex # nop
    echo "00000013" >> firmware.hex # nop
    echo "00000013" >> firmware.hex # nop
    echo "00500093" >> firmware.hex # 跳轉目標: addi x1, x0, 5
fi

# 檢查Testbench
echo -e "\n3. 選擇Testbench..."
if [ -f "tb_debug.v" ]; then
    TB_FILE="tb_debug.v"
    OUTPUT="debug.vvp"
    echo "  ✅ 使用: tb_debug.v -> $OUTPUT"
elif [ -f "tb_core.v" ]; then
    TB_FILE="tb_core.v"
    OUTPUT="core_test.vvp"
    echo "  ✅ 使用: tb_core.v -> $OUTPUT"
else
    echo "  ❌ 未找到Testbench文件"
    echo "  創建一個簡單的Testbench..."
    cat > tb_simple.v << 'EOF'
`timescale 1ns/1ps

module tb_simple;
    reg clk;
    reg rst_n;
    wire uart_tx;
    
    // 實例化CPU核心
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
    
    // 復位和測試
    initial begin
        // 初始化
        rst_n = 0;
        #20 rst_n = 1;
        
        // 運行一定周期
        $display("=== 開始仿真 ===");
        $display("時間 | PC       | 指令     | 備註");
        $display("-----------------------------------");
        
        // 監控關鍵信號
        $monitor("[%0t] PC=%08h, IF指令=%08h, EX分支=%b", 
                $time, u_core.pc, u_core.if_inst, u_core.ex_take_branch);
        
        // 運行1000個時鐘周期
        #1000;
        
        // 顯示結果
        $display("\n=== 仿真結束 ===");
        $display("總周期數: %0d", u_core.cycle_cnt);
        $display("總指令數: %0d", u_core.inst_cnt);
        
        // 檢查寄存器值
        $display("\n寄存器狀態:");
        for (int i = 1; i < 5; i++) begin
            $display("  x%0d = 0x%08h", i, u_core.u_regfile.regs[i]);
        end
        
        $finish;
    end
    
    // VCD波形文件
    initial begin
        $dumpfile("debug.vcd");
        $dumpvars(0, tb_simple);
    end
    
endmodule
EOF
    TB_FILE="tb_simple.v"
    OUTPUT="simple_test.vvp"
    echo "  ✅ 創建: tb_simple.v -> $OUTPUT"
fi

# 編譯
echo -e "\n4. 編譯..."
echo "  編譯命令:"
echo "  iverilog -g2012 -Wall -o $OUTPUT $TB_FILE alu.v decoder.v reg_file.v rom.v data_ram.v csr_registers.v uart_tx.v core.v"

# 語法檢查
echo -e "\n5. 語法檢查..."
iverilog -g2012 -Wall -syntax-only $TB_FILE alu.v decoder.v reg_file.v rom.v data_ram.v csr_registers.v uart_tx.v core.v 2>&1 | head -20

if [ $? -eq 0 ]; then
    echo "  ✅ 語法檢查通過"
else
    echo "  ❌ 語法檢查失敗"
    exit 1
fi

# 正式編譯
echo -e "\n6. 正式編譯..."
iverilog -g2012 -Wall -o $OUTPUT $TB_FILE alu.v decoder.v reg_file.v rom.v data_ram.v csr_registers.v uart_tx.v core.v

if [ $? -eq 0 ]; then
    echo "  ✅ 編譯成功: $OUTPUT"
else
    echo "  ❌ 編譯失敗"
    exit 1
fi

# 創建運行腳本
echo -e "\n7. 創建運行腳本..."
cat > run_simulation.sh << EOF
#!/bin/bash
echo "運行仿真..."
vvp $OUTPUT
echo "仿真完成！"
echo "波形文件: debug.vcd"
echo "查看波形: gtkwave debug.vcd"
EOF
chmod +x run_simulation.sh

# 創建診斷腳本
echo -e "\n8. 創建診斷腳本..."
cat > diagnose.sh << 'EOF'
#!/bin/bash
echo "=== RISC-V CPU 診斷工具 ==="
echo "1. 檢查信號完整性..."
echo "2. 驗證指令解碼..."
echo "3. 測試數據通路..."
echo "4. 查看波形文件..."
echo "請選擇操作 (1-4): "
read choice

case $choice in
    1)
        echo "檢查關鍵信號..."
        if [ -f "debug.vcd" ]; then
            vcd2vpd debug.vcd debug.vpd
            echo "創建了VPD文件: debug.vpd"
        else
            echo "未找到波形文件"
        fi
        ;;
    2)
        echo "驗證指令解碼..."
        echo "檢查decoder.v中的opcode定義..."
        grep -n "OP_BRANCH" decoder.v
        grep -n "7'b1100011" decoder.v
        ;;
    3)
        echo "測試數據通路..."
        echo "創建測試程序..."
        cat > test_beq.hex << 'TEST'
00100093  # addi x1, x0, 1
00100113  # addi x2, x0, 1
00808063  # beq x1, x2, 16
00000013  # nop
00000013  # nop
00000013  # nop
00500093  # 跳轉目標: addi x1, x0, 5
TEST
        echo "測試程序已創建: test_beq.hex"
        ;;
    4)
        if command -v gtkwave &> /dev/null; then
            gtkwave debug.vcd &
        else
            echo "未安裝gtkwave，請先安裝: sudo apt-get install gtkwave"
        fi
        ;;
    *)
        echo "無效選擇"
        ;;
esac
EOF
chmod +x diagnose.sh

echo -e "\n=== 準備完成 ==="
echo "✅ 編譯完成: $OUTPUT"
echo "✅ 測試程序: firmware.hex"
echo -e "\n運行仿真:"
echo "  ./run_simulation.sh"
echo -e "\n診斷問題:"
echo "  ./diagnose.sh"
echo -e "\n清理文件:"
echo "  rm -f *.vvp *.vcd *.log tb_simple.v"

# 提示如何測試BEQ
echo -e "\n=== BEQ 指令測試建議 ==="
echo "要測試BEQ指令，請創建以下測試程序 (firmware.hex):"
echo "00100093  # addi x1, x0, 1"
echo "00100113  # addi x2, x0, 1"
echo "00808063  # beq x1, x2, 16  (如果x1==x2，跳過3條指令)"
echo "00200193  # addi x3, x0, 2  (不應該執行)"
echo "00300213  # addi x4, x0, 3  (不應該執行)"
echo "00400293  # addi x5, x0, 4  (不應該執行)"
echo "00500093  # 跳轉目標: addi x1, x0, 5"