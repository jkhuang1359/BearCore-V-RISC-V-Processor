#!/bin/bash
echo "BEQ指令專項診斷"
echo "================"

# 1. 創建最小BEQ測試程序
cat > beq_minimal.s << 'BEQ_EOF'
.text
.globl _start
_start:
    # 最小BEQ測試
    li x1, 1
    li x2, 1
    beq x1, x2, target_equal
    
    # 如果執行到這裡，BEQ失敗
    li x10, 0xBAD
    j end

target_equal:
    # BEQ成功跳轉
    li x10, 0x600D
    j end

end:
    j end
BEQ_EOF

# 2. 編譯測試程序
echo "編譯測試程序..."
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -Ttext=0x0 -o beq_minimal.elf beq_minimal.s
riscv64-unknown-elf-objcopy -O binary beq_minimal.elf beq_minimal.bin
hexdump -v -e '1/4 "%08x\n"' beq_minimal.bin > firmware.hex

echo "測試程序反彙編:"
riscv64-unknown-elf-objdump -d beq_minimal.elf

# 3. 創建BEQ專用testbench
cat > tb_beq_diagnose.v << 'TB_EOF'
`timescale 1ns/1ps

module tb_beq_diagnose;
    reg clk;
    reg rst_n;
    
    core u_core (.clk(clk), .rst_n(rst_n), .uart_tx_o());
    
    always #50 clk = ~clk;
    
    // 訪問內部信號用於診斷
    wire [31:0] if_inst = u_core.if_inst;
    wire [31:0] id_inst = u_core.id_inst;
    wire [31:0] id_rdata1 = u_core.id_rdata1;
    wire [31:0] id_rdata2 = u_core.id_rdata2;
    wire ex_alu_zero = u_core.ex_alu_zero;
    wire ex_take_branch = u_core.ex_take_branch;
    wire [31:0] ex_target_pc = u_core.ex_target_pc;
    
    integer cycle = 0;
    reg [31:0] expected_reg_x1 = 1;
    reg [31:0] expected_reg_x2 = 1;
    
    always @(posedge clk) begin
        if (rst_n) begin
            cycle = cycle + 1;
            
            case (cycle)
                1: begin
                    $display("周期 1: 初始化");
                    $display("  PC = 0x%08h, IF指令 = 0x%08h", u_core.pc, if_inst);
                end
                2: begin
                    $display("周期 2: 加載x1");
                    $display("  PC = 0x%08h, ID指令 = 0x%08h", u_core.pc, id_inst);
                end
                3: begin
                    $display("周期 3: 加載x2");
                    $display("  PC = 0x%08h", u_core.pc);
                end
                4: begin
                    $display("周期 4: BEQ指令進入ID階段");
                    $display("  PC = 0x%08h, ID指令 = 0x%08h (BEQ)", u_core.pc, id_inst);
                    $display("  寄存器值: x1 = 0x%08h, x2 = 0x%08h", id_rdata1, id_rdata2);
                end
                5: begin
                    $display("周期 5: BEQ在EX階段");
                    $display("  PC = 0x%08h", u_core.pc);
                    $display("  ALU零標誌: %b, 分支跳轉: %b", ex_alu_zero, ex_take_branch);
                    if (ex_take_branch) begin
                        $display("  目標PC: 0x%08h", ex_target_pc);
                    end
                end
                6: begin
                    $display("周期 6: 檢查是否跳轉");
                    if (u_core.pc == 32'h0000000c) begin
                        $display("  ✅ BEQ成功跳轉到target_equal (0x0c)");
                    end else if (u_core.pc == 32'h00000010) begin
                        $display("  ❌ BEQ未跳轉，進入錯誤分支 (0x10)");
                    end
                end
            endcase
            
            if (cycle > 15) $finish;
        end
    end
    
    initial begin
        $dumpfile("beq_diagnose.vcd");
        $dumpvars(0, tb_beq_diagnose);
        
        clk = 0;
        rst_n = 0;
        
        $display("BEQ指令診斷測試");
        $display("=================");
        
        #200;
        rst_n = 1;
        
        #5000;
        $finish;
    end
    
    // 監控寄存器值變化
    always @(posedge clk) begin
        if (rst_n && id_inst == 32'h00208863) begin  // BEQ指令的機器碼
            $display("[BEQ檢測] ID階段: 比較 x%0d(0x%08h) 和 x%0d(0x%08h)",
                    id_inst[19:15], id_rdata1,
                    id_inst[24:20], id_rdata2);
        end
    end
endmodule
TB_EOF

# 4. 編譯並運行
echo ""
echo "運行BEQ診斷..."
./compile_professional.sh 2>/dev/null

if [ -f "beq_diagnose.vvp" ]; then
    vvp beq_diagnose.vvp
elif [ -f "auto.vvp" ]; then
    vvp auto.vvp
else
    echo "編譯失敗，請手動運行:"
    echo "  iverilog -g2012 -o beq_diagnose.vvp tb_beq_diagnose.v *.v"
    echo "  vvp beq_diagnose.vvp"
fi

echo ""
echo "診斷完成"
echo "如果BEQ仍然有問題，請檢查:"
echo "1. decoder.v中的BEQ解碼"
echo "2. alu.v中的比較邏輯"
echo "3. core.v中的分支條件計算"
