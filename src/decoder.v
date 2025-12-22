module decoder(
    input  [31:0] inst,

    output [4:0] rs1_addr,
    output [4:0] rs2_addr,
    output [4:0] rd_addr,
    output [31:0] imm,
    output [2:0] funct3,
    output [3:0] alu_op,     // 對應您的新 ALU
    output       alu_src_b,
    output       reg_wen,
    output       is_store,
    output       is_load,
    output       is_jal,
    output       is_jalr,
    output       is_branch,
    output       is_lui,
    output       is_auipc,  // 1. ✨ 新增這個 output
    output       is_m_ext_o  // ✨ 新增這個 output [cite: 1, 2])
);

    // Opcode 定義
    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_IMM    = 7'b0010011;
    localparam OP_REG    = 7'b0110011;

    // 您的 ALU 定義 (必須完全一致)
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b1000;
    localparam ALU_AND  = 4'b0111;
    localparam ALU_OR   = 4'b0110;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0001;
    localparam ALU_SRL  = 4'b0101;
    localparam ALU_SRA  = 4'b1101;
    localparam ALU_SLT  = 4'b0010;
    localparam ALU_SLTU = 4'b0011;
    localparam ALU_MUL  = 4'b1001;
    localparam ALU_DIV  = 4'b1010; 
    localparam ALU_REM  = 4'b1011;        

    wire [6:0] opcode = inst[6:0];
    assign funct3 = inst[14:12];
    wire [6:0] funct7 = inst[31:25];
    wire is_m_ext = (opcode == 7'b0110011 && funct7 == 7'b0000001);
    assign is_m_ext_o = is_m_ext;    


    // 欄位解碼
    assign is_lui = (opcode == OP_LUI);
    assign is_auipc  = (opcode == OP_AUIPC); // 2. ✨ 新增這行判斷    
    assign rs1_addr = (opcode == OP_LUI || opcode == OP_AUIPC) ? 5'b0 : inst[19:15];    
    assign rs2_addr = inst[24:20];
    assign rd_addr  = inst[11:7];

    // 控制信號
    assign is_jal    = (opcode == OP_JAL);
    assign is_jalr   = (opcode == OP_JALR);
    assign is_branch = (opcode == OP_BRANCH);
    assign is_load   = (opcode == OP_LOAD);
    assign is_store  = (opcode == OP_STORE);

    assign reg_wen = (opcode == OP_LUI) || (opcode == OP_AUIPC) || (opcode == OP_JAL) || 
                     (opcode == OP_JALR) || (opcode == OP_LOAD) || (opcode == OP_IMM) || (opcode == OP_REG);

    assign alu_src_b = !(opcode == OP_REG || opcode == OP_BRANCH);

    // 立即數生成 (🏆 小熊寶修正版)
    reg [31:0] imm_temp;
    always @(*) begin
        case (opcode)
            OP_LUI, OP_AUIPC: 
                imm_temp = {inst[31:12], 12'b0};
            
            OP_JAL: 
                // 🏆 修正後的 J-type: {Sign, inst[19:12], inst[20], inst[30:21], 1'b0}
                imm_temp = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
            
            OP_BRANCH: 
                // 🏆 修正後的 B-type: {Sign, inst[7], inst[30:25], inst[11:8], 1'b0}
                imm_temp = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
            
            OP_STORE: 
                imm_temp = {{20{inst[31]}}, inst[31:25], inst[11:7]};
            
            default: // 包括 OP_IMM (addi 等) 與 OP_LOAD, OP_JALR (I-type)
                imm_temp = {{20{inst[31]}}, inst[31:20]};
        endcase
    end
    assign imm = imm_temp;


    // ALU Opcode 解碼
    reg [3:0] alu_op_temp;
    always @(*) begin
        alu_op_temp = ALU_ADD; // 預設做加法

        // 1. 優先檢查是否為 M 擴展 (例如 MUL)
        if (is_m_ext) begin
            case (funct3)
                3'b000: begin
                    alu_op_temp = ALU_MUL;
                end
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
    end
    assign alu_op = alu_op_temp;

endmodule