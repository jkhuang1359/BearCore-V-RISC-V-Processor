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
