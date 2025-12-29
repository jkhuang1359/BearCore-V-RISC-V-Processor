`timescale 1ns/1ps

module core_wrapper_simple(
    input clk,
    input rst_n,
    output uart_tx
);
    // 重新定義所有需要的信號
    reg  [31:0] pc;
    wire [31:0] pc_next;
    wire [31:0] if_inst;
    wire [31:0] ex_target_pc;
    wire ex_take_branch;
    
    // ROM 實例
    wire [31:0] rom_inst;
    rom_small u_rom(
        .addr(pc),
        .inst(rom_inst),
        .data_addr(32'h0),
        .data_out()
    );
    
    assign if_inst = rom_inst;
    
    // 簡單的 PC 更新邏輯
    assign pc_next = pc + 4;
    
    // 寄存器
    reg [31:0] regs [0:31];
    
    // 解碼
    wire [6:0] opcode = if_inst[6:0];
    wire [4:0] rd = if_inst[11:7];
    wire [4:0] rs1 = if_inst[19:15];
    wire [31:0] imm_u = {if_inst[31:12], 12'b0};
    
    integer cycle_count;
    
    // 主時序邏輯
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'h0;
            cycle_count <= 0;
            
            // 初始化寄存器
            for (integer i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'h0;
            end
            
            $display("[WRAPPER] 復位完成");
        end else begin
            cycle_count <= cycle_count + 1;
            
            // 執行指令
            case (opcode)
                7'b0110111: begin // LUI
                    regs[rd] <= imm_u;
                    pc <= pc_next;
                    $display("[%0t] LUI x%0d, 0x%08h", $time, rd, imm_u);
                end
                
                default: begin
                    pc <= pc_next;
                    $display("[%0t] 未知指令: 0x%08h, PC=0x%08h", 
                            $time, if_inst, pc);
                end
            endcase
            
            // 顯示 PC 變化（前10個週期）
            if (cycle_count < 10) begin
                $display("[%0t] 週期 %0d: PC=0x%08h, 指令=0x%08h", 
                        $time, cycle_count, pc, if_inst);
            end
        end
    end
    
    // UART 暫時不連接
    assign uart_tx = 1'b1;
    
endmodule
