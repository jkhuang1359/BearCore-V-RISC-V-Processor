echo "================================================================"
echo "最簡單測試 - 從零開始"
echo "================================================================"

# 清理
rm -f *.vcd *.vvp

# 1. 創建最簡單的 ROM
cat > rom_tiny.v << 'ROMEOF'
module rom_tiny(
    input [31:0] addr,
    output reg [31:0] inst
);
    always @(*) begin
        case (addr)
            32'h0: inst = 32'h100002b7;  // lui t0, 0x10000
            32'h4: inst = 32'h02100313;  // li t1, 33 ('!')
            32'h8: inst = 32'h0062a023;  // sw t1, 0(t0)
            32'hc: inst = 32'h0000006f;  // j .
            default: inst = 32'h00000013; // nop
        endcase
    end
    
    initial begin
        $display("[ROM_TINY] 初始化完成");
    end
endmodule
ROMEOF

# 2. 創建最簡單的 CPU
cat > cpu_tiny.v << 'CPUEOF'
module cpu_tiny(
    input clk,
    input rst_n,
    output reg uart_tx
);
    reg [31:0] pc;
    wire [31:0] inst;
    
    rom_tiny u_rom(.addr(pc), .inst(inst));
    
    // 解碼
    wire [6:0] opcode = inst[6:0];
    wire [4:0] rd = inst[11:7];
    wire [31:0] imm_u = {inst[31:12], 12'b0};
    
    integer cycle;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 0;
            cycle <= 0;
            uart_tx <= 1;
            $display("[CPU] 復位完成");
        end else begin
            cycle <= cycle + 1;
            
            case (opcode)
                7'b0110111: begin // LUI
                    pc <= pc + 4;
                    $display("[%0t] 週期 %0d: PC=0x%08h, LUI x%0d, 0x%08h", 
                            $time, cycle, pc, rd, imm_u);
                end
                7'b0010011: begin // ADDI
                    pc <= pc + 4;
                    $display("[%0t] 週期 %0d: PC=0x%08h, ADDI", 
                            $time, cycle, pc);
                end
                7'b0100011: begin // SW
                    pc <= pc + 4;
                    $display("[%0t] 週期 %0d: PC=0x%08h, SW", 
                            $time, cycle, pc);
                end
                7'b1101111: begin // JAL
                    pc <= pc + 4;
                    $display("[%0t] 週期 %0d: PC=0x%08h, JAL", 
                            $time, cycle, pc);
                end
                default: begin
                    pc <= pc + 4;
                    $display("[%0t] 週期 %0d: PC=0x%08h, 指令=0x%08h", 
                            $time, cycle, pc, inst);
                end
            endcase
            
            // 只運行 20 個週期
            if (cycle >= 20) begin
                $display("[CPU] 完成 20 個週期");
                $finish;
            end
        end
    end
endmodule
CPUEOF

# 3. 創建測試台
cat > tb_tiny.v << 'TBEOF'
`timescale 1ns/1ps

module tb_tiny;
    reg clk;
    reg rst_n;
    wire uart_tx;
    
    cpu_tiny u_cpu(
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx(uart_tx)
    );
    
    // 時鐘 (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        $dumpfile("tiny.vcd");
        $dumpvars(0, tb_tiny);
        
        $display("========================================");
        $display("最簡單 CPU 測試開始");
        $display("========================================");
        
        // 復位
        rst_n = 0;
        #100;
        rst_n = 1;
        $display("[%0t] 復位釋放", $time);
        
        // 運行足夠長時間
        #10000;
        
        $display("[%0t] 測試完成", $time);
        $display("========================================");
        $finish;
    end
endmodule
TBEOF

# 4. 編譯並運行
echo ""
echo "編譯..."
iverilog -o tiny.vvp tb_tiny.v cpu_tiny.v rom_tiny.v 2>compile.log

if [ $? -eq 0 ]; then
    echo "✅ 編譯成功"
    echo ""
    echo "運行仿真..."
    vvp tiny.vvp 2>&1 | tee sim.log
    
    echo ""
    echo "仿真輸出:"
    echo "----------"
    grep -E "週期|CPU|復位|測試" sim.log || tail -20 sim.log
    
    if [ -f "tiny.vcd" ]; then
        echo ""
        echo "✅ 波形文件生成: tiny.vcd"
        echo "   大小: $(wc -c < tiny.vcd) 字節"
    fi
else
    echo "❌ 編譯失敗"
    cat compile.log
fi

echo ""
echo "================================================================"
echo "測試完成"
echo "================================================================"