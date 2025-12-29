echo "CPU診斷測試"
echo "=============="

# 1. 創建診斷程序
cat > diagnose.s << 'ASM_EOF'
.text
.globl _start
_start:
    # 地址0x00: nop
    nop
    
    # 地址0x04: nop
    nop
    
    # 地址0x08: nop
    nop
    
    # 地址0x0c: nop
    nop
    
    # 地址0x10: nop
    nop
    
    # 地址0x14: jal x0, -4 (跳轉回0x10)
    # 編碼: 0xffdff06f
    # 實際使用簡單的j end
end:
    j end
ASM_EOF

# 2. 編譯並生成HEX
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -Ttext=0x0 -o diagnose.elf diagnose.s
riscv64-unknown-elf-objcopy -O binary diagnose.elf diagnose.bin
hexdump -v -e '1/4 "%08x\n"' diagnose.bin > firmware.hex

echo "生成的指令："
cat firmware.hex

# 3. 創建詳細的testbench
cat > tb_detailed.v << 'TB_EOF'
`timescale 1ns/1ps

module tb_detailed;
    reg clk;
    reg rst_n;
    
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx_o()
    );
    
    // 慢時鐘便於觀察
    always #100 clk = ~clk;
    
    // 顯示所有信息
    integer cycle = 0;
    always @(posedge clk) begin
        if (rst_n) begin
            cycle <= cycle + 1;
            
            $display("週期 %0d:", cycle);
            $display("  PC = 0x%08h", u_core.pc);
            $display("  指令 = 0x%08h", u_core.instr);
            $display("  下一PC = 0x%08h", u_core.pc_next);
            
            if (u_core.pc >= 32'h00000018) begin
                $display("⚠️  警告：PC進入了未定義區域");
                $display("  檢查ROM大小和PC計算邏輯");
            end
            
            if (cycle > 15) begin
                $display("測試結束");
                $finish;
            end
        end
    end
    
    initial begin
        $dumpfile("detailed.vcd");
        $dumpvars(0, tb_detailed);
        
        clk = 0;
        rst_n = 0;
        
        $display("CPU詳細診斷開始");
        
        #200;
        rst_n = 1;
        
        #5000;
        $finish;
    end
endmodule
TB_EOF

# 4. 運行診斷
echo "運行診斷..."
iverilog -o detailed.vvp tb_detailed.v *.v
vvp detailed.vvp
