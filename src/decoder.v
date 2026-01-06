`timescale 1ns/1ps  // <--- 🐻 關鍵修正：定義時間單位！
module decoder(
    input  [31:0] inst,

    output [4:0]  rs1_addr,
    output [4:0]  rs2_addr,
    output [4:0]  rd_addr,
    output [31:0] imm,
    output [2:0]  funct3,
    output [3:0]  alu_op,           // 對應您的新 ALU
    output        alu_src_b,
    output        reg_wen,
    output        is_store,
    output        is_load,
    output        is_jal,
    output        is_jalr,
    output        is_branch,
    output        is_lui,
    output        is_auipc,
    output        is_m_ext_o,
    
    // 🏆 新增 CSR 相關輸出
    output        is_csr,           // 是否為 CSR 指令
    output        is_system,        // 是否為系統指令 (ECALL/EBREAK/MRET)
    output [1:0]  csr_op_type,      // CSR 操作類型
    output        csr_use_imm,      // CSR 使用立即數
    output [11:0] csr_addr          // CSR 地址
);

    // Opcode 定義 (新增 CSR 相關)
    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_IMM    = 7'b0010011;
    localparam OP_REG    = 7'b0110011;
    localparam OP_SYSTEM = 7'b1110011;  // 🏆 新增：系統指令（包括 CSR）

    // 🏆 ALU 定義 - 修正版（確保沒有重複且語法正確）
    // 🏆 0~8：基礎運算
    localparam ALU_ADD    = 4'b0000; // 0
    localparam ALU_SUB    = 4'b1000; // 8
    localparam ALU_SLL    = 4'b0001; // 1
    localparam ALU_SLT    = 4'b0010; // 2
    localparam ALU_SLTU   = 4'b0011; // 3
    localparam ALU_XOR    = 4'b0100; // 4
    localparam ALU_SRL    = 4'b0101; // 5
    localparam ALU_OR     = 4'b0110; // 6
    localparam ALU_AND    = 4'b0111; // 7
    localparam ALU_SRA    = 4'b1101; // 13

    // 🏆 9~12：乘法群 (M-Extension)
    localparam ALU_MUL    = 4'd9;    
    localparam ALU_MULH   = 4'd10;   
    localparam ALU_MULHSU = 4'd11;   
    localparam ALU_MULHU  = 4'd12;   

    // 🏆 14~15：除法與系統
    localparam ALU_DIV    = 4'd14;   
    localparam ALU_REM    = 4'd15;

    // 🏆 CSR 操作類型定義
    localparam CSR_OP_RW  = 2'b00;  // CSRRW, CSRRWI
    localparam CSR_OP_RS  = 2'b01;  // CSRRS, CSRRSI
    localparam CSR_OP_RC  = 2'b10;  // CSRRC, CSRRCI

    wire [6:0] opcode = inst[6:0];
    assign funct3 = inst[14:12];
    wire [6:0] funct7 = inst[31:25];
    wire is_m_ext = (opcode == OP_REG && funct7 == 7'b0000001);
    assign is_m_ext_o = is_m_ext;

    // 🏆 CSR 相關信號提取
    assign csr_addr = inst[31:20];  // CSR 地址在指令的高位

    // 🏆 判斷是否為 CSR 指令和系統指令
    wire is_system_inst = (opcode == OP_SYSTEM);
    wire is_csr_inst = is_system_inst && (funct3 != 3'b000);
    wire is_syscall_inst = is_system_inst && (funct3 == 3'b000);
    
    assign is_csr = is_csr_inst;
    assign is_system = is_syscall_inst;
    
    // 🏆 CSR 操作類型解碼
    reg [1:0] csr_op_temp;
    reg csr_imm_temp;
    
    always @(*) begin
        if (is_csr_inst) begin
            case (funct3)
                3'b001: begin  // CSRRW
                    csr_op_temp = CSR_OP_RW;
                    csr_imm_temp = 1'b0;
                end
                3'b010: begin  // CSRRS
                    csr_op_temp = CSR_OP_RS;
                    csr_imm_temp = 1'b0;
                end
                3'b011: begin  // CSRRC
                    csr_op_temp = CSR_OP_RC;
                    csr_imm_temp = 1'b0;
                end
                3'b101: begin  // CSRRWI
                    csr_op_temp = CSR_OP_RW;
                    csr_imm_temp = 1'b1;
                end
                3'b110: begin  // CSRRSI
                    csr_op_temp = CSR_OP_RS;
                    csr_imm_temp = 1'b1;
                end
                3'b111: begin  // CSRRCI
                    csr_op_temp = CSR_OP_RC;
                    csr_imm_temp = 1'b1;
                end
                default: begin
                    csr_op_temp = 2'b00;
                    csr_imm_temp = 1'b0;
                end
            endcase
        end else begin
            csr_op_temp = 2'b00;
            csr_imm_temp = 1'b0;
        end
    end
    
    assign csr_op_type = csr_op_temp;
    assign csr_use_imm = csr_imm_temp;

    // 欄位解碼
    assign is_lui = (opcode == OP_LUI);
    assign is_auipc  = (opcode == OP_AUIPC);
    
    // 🏆 對於 CSR 指令，rs1_addr 可能被用作立即數源
    assign rs1_addr = (opcode == OP_LUI || opcode == OP_AUIPC ) ? 5'b0 : inst[19:15];
    
    assign rs2_addr = inst[24:20];
    assign rd_addr  = inst[11:7];

    // 控制信號
    assign is_jal    = (opcode == OP_JAL);
    assign is_jalr   = (opcode == OP_JALR);
    assign is_branch = (opcode == OP_BRANCH);
    assign is_load   = (opcode == OP_LOAD);
    assign is_store  = (opcode == OP_STORE);

    // 🏆 更新 reg_wen：CSR 指令也會寫入寄存器
    assign reg_wen = (opcode == OP_LUI) || (opcode == OP_AUIPC) || (opcode == OP_JAL) || 
                     (opcode == OP_JALR) || (opcode == OP_LOAD) || (opcode == OP_IMM) || 
                     (opcode == OP_REG) || (is_csr_inst);

    // 🏆 CSR 指令不需要 ALU 的 b 輸入（使用立即數或 rs1）
    assign alu_src_b = !(opcode == OP_REG || opcode == OP_BRANCH || is_csr_inst);

    // 立即數生成 (🏆 新增 CSR 立即數支援)
    reg [31:0] imm_temp;
    always @(*) begin
        case (opcode)
            OP_LUI, OP_AUIPC: 
                imm_temp = {inst[31:12], 12'b0};
            
            OP_JAL: 
                imm_temp = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
            
            OP_BRANCH: 
                imm_temp = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
            
            OP_STORE: 
                imm_temp = {{20{inst[31]}}, inst[31:25], inst[11:7]};
            
            OP_SYSTEM: 
                // 🏆 CSR 立即數來自 rs1 欄位（零擴展）
                imm_temp = {27'b0, inst[19:15]};
            
            default: // 包括 OP_IMM (addi 等) 與 OP_LOAD, OP_JALR (I-type)
                imm_temp = {{20{inst[31]}}, inst[31:20]};
        endcase
    end
    assign imm = imm_temp;

    // ALU Opcode 解碼
    reg [3:0] alu_op_temp;
    always @(*) begin
        alu_op_temp = ALU_ADD; // 預設做加法

        // 🏆 優先檢查是否為 CSR 指令
        if (is_csr_inst) begin
            alu_op_temp = ALU_ADD; // CSR 操作
        end
        // 1. 檢查是否為 M 擴展 (例如 MUL)
        else if (is_m_ext) begin
            case (funct3)
                3'b000: begin
                    alu_op_temp = ALU_MUL;
                end
                3'b001: alu_op_temp = ALU_MULH;   // 🏆 新增 
                3'b010: alu_op_temp = ALU_MULHSU; // 🏆 新增 (建議一併實作)           
                3'b011: alu_op_temp = ALU_MULHU;  // 🏆 新增    
                3'b100: begin
                    alu_op_temp = ALU_DIV;
                end
                3'b101: begin
                    alu_op_temp = ALU_DIV;
                end
                3'b110: begin
                    alu_op_temp = ALU_REM;
                end
                3'b111: begin
                    alu_op_temp = ALU_REM;
                end
                default: begin
                    alu_op_temp = ALU_ADD;
                end
            endcase
        end 
        // 2. 處理 Branch 指令
        else if (opcode == OP_BRANCH) begin
            case (funct3)
                3'b000: alu_op_temp = ALU_SUB;  // BEQ
                3'b001: alu_op_temp = ALU_SUB;  // BNE
                3'b100: alu_op_temp = ALU_SLT;  // BLT
                3'b101: alu_op_temp = ALU_SLT;  // BGE
                3'b110: alu_op_temp = ALU_SLTU; // BLTU
                3'b111: alu_op_temp = ALU_SLTU; // BGEU
                default: alu_op_temp = ALU_SUB;
            endcase
        end 
        // 3. 處理標準 R-type (OP_REG) 與 I-type (OP_IMM)
        else if ((opcode == OP_REG && !is_m_ext) || opcode == OP_IMM) begin             
            case (funct3)
                 3'b000: begin
                     if (opcode == OP_REG && funct7[5]) alu_op_temp = ALU_SUB;
                     else alu_op_temp = ALU_ADD;
                 end
                 3'b001: alu_op_temp = ALU_SLL;
                 3'b010: alu_op_temp = ALU_SLT;
                 3'b011: alu_op_temp = ALU_SLTU;
                 3'b100: alu_op_temp = ALU_XOR;
                 3'b101: begin
                     if (funct7[5]) alu_op_temp = ALU_SRA;
                     else alu_op_temp = ALU_SRL;
                 end
                 3'b110: alu_op_temp = ALU_OR;
                 3'b111: alu_op_temp = ALU_AND;
             endcase
        end
        // 🏆 系統調用指令（ECALL/EBREAK/MRET）
        else if (is_syscall_inst) begin
            alu_op_temp = ALU_ADD; // 系統調用操作碼
        end
    end
    assign alu_op = alu_op_temp;

endmodule