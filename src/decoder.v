`timescale 1ns/1ps

// =============================================================================
// 指令解碼器模組 (Instruction Decoder)
// 功能：
// 1. 解碼 32-bit RISC-V 指令
// 2. 產生所有控制訊號
// 3. 提取立即數值
// 4. 支援 CSR 指令解碼
// 5. 支援乘法擴展 (M-extension)
// =============================================================================
module instruction_decoder (
    // 指令輸入
    input  wire [31:0] instruction_i,             // 32-bit 指令輸入
    
    // 暫存器地址輸出
    output wire [4:0]  rs1_address_o,             // 來源暫存器 1 地址
    output wire [4:0]  rs2_address_o,             // 來源暫存器 2 地址
    output wire [4:0]  rd_address_o,              // 目的暫存器地址
    
    // 立即數與功能欄位輸出
    output wire [31:0] immediate_value_o,         // 解碼後的立即數值
    output wire [2:0]  function_3_o,              // funct3 欄位
    output wire [3:0]  alu_operation_o,           // ALU 操作碼
    
    // 控制訊號輸出
    output wire        alu_source_b_select_o,     // ALU B 輸入選擇 (0:rs2, 1:imm)
    output wire        register_write_enable_o,   // 暫存器寫入使能
    output wire        store_operation_o,         // 儲存操作標誌
    output wire        load_operation_o,          // 載入操作標誌
    output wire        jump_and_link_o,           // JAL 指令標誌
    output wire        jump_and_link_register_o,  // JALR 指令標誌
    output wire        branch_operation_o,        // 分支指令標誌
    output wire        load_upper_immediate_o,    // LUI 指令標誌
    output wire        add_upper_immediate_to_pc_o, // AUIPC 指令標誌
    output wire        multiplication_extension_o, // M 擴展標誌
    
    // CSR 相關輸出
    output wire        csr_instruction_o,         // CSR 指令標誌
    output wire        system_instruction_o,      // 系統指令標誌 (ECALL/EBREAK/MRET)
    output wire [1:0]  csr_operation_type_o,      // CSR 操作類型 (00:RW, 01:RS, 10:RC)
    output wire        csr_use_immediate_o,       // CSR 使用立即數標誌
    output wire [11:0] csr_address_o              // CSR 地址
);
    
    // ============================
    // 1. 指令欄位定義
    // ============================
    wire [6:0] opcode_field_w = instruction_i[6:0];      // 操作碼欄位
    wire [4:0] rs1_field_w    = instruction_i[19:15];    // rs1 欄位
    wire [4:0] rs2_field_w    = instruction_i[24:20];    // rs2 欄位
    wire [4:0] rd_field_w     = instruction_i[11:7];     // rd 欄位
    wire [2:0] funct3_field_w = instruction_i[14:12];    // funct3 欄位
    wire [6:0] funct7_field_w = instruction_i[31:25];    // funct7 欄位
    
    // ============================
    // 2. 操作碼定義 (RISC-V 標準)
    // ============================
    localparam OPCODE_LUI     = 7'b0110111;  // 載入高位立即數
    localparam OPCODE_AUIPC   = 7'b0010111;  // PC + 高位立即數
    localparam OPCODE_JAL     = 7'b1101111;  // 跳躍並連結
    localparam OPCODE_JALR    = 7'b1100111;  // 暫存器跳躍並連結
    localparam OPCODE_BRANCH  = 7'b1100011;  // 分支指令
    localparam OPCODE_LOAD    = 7'b0000011;  // 載入指令
    localparam OPCODE_STORE   = 7'b0100011;  // 儲存指令
    localparam OPCODE_IMM     = 7'b0010011;  // 立即數運算
    localparam OPCODE_REG     = 7'b0110011;  // 暫存器運算
    localparam OPCODE_SYSTEM  = 7'b1110011;  // 系統指令 (包含 CSR)
    
    // ============================
    // 3. ALU 操作碼定義 (與 ALU 模組一致)
    // ============================
    
    // 基礎運算操作碼
    localparam ALU_OP_ADD    = 4'b0000;  // 加法
    localparam ALU_OP_SUB    = 4'b1000;  // 減法
    localparam ALU_OP_SLL    = 4'b0001;  // 邏輯左移
    localparam ALU_OP_SLT    = 4'b0010;  // 有符號小於比較
    localparam ALU_OP_SLTU   = 4'b0011;  // 無符號小於比較
    localparam ALU_OP_XOR    = 4'b0100;  // 邏輯互斥或
    localparam ALU_OP_SRL    = 4'b0101;  // 邏輯右移
    localparam ALU_OP_OR     = 4'b0110;  // 邏輯或
    localparam ALU_OP_AND    = 4'b0111;  // 邏輯與
    localparam ALU_OP_SRA    = 4'b1101;  // 算術右移
    
    // 乘法擴展操作碼
    localparam ALU_OP_MUL    = 4'd9;     // 乘法 (低32位)
    localparam ALU_OP_MULH   = 4'd10;    // 乘法 (高32位，有符號×有符號)
    localparam ALU_OP_MULHSU = 4'd11;    // 乘法 (高32位，有符號×無符號)
    localparam ALU_OP_MULHU  = 4'd12;    // 乘法 (高32位，無符號×無符號)
    
    // 除法運算操作碼
    localparam ALU_OP_DIV    = 4'd14;    // 除法
    localparam ALU_OP_REM    = 4'd15;    // 餘數
    
    // ============================
    // 4. CSR 操作類型定義
    // ============================
    localparam CSR_OP_RW = 2'b00;  // CSRRW, CSRRWI (讀寫)
    localparam CSR_OP_RS = 2'b01;  // CSRRS, CSRRSI (讀後置位)
    localparam CSR_OP_RC = 2'b10;  // CSRRC, CSRRCI (讀後清除)
    
    // ============================
    // 5. 指令類型判斷
    // ============================
    wire is_multiplication_extension_w = (opcode_field_w == OPCODE_REG) && (funct7_field_w == 7'b0000001);
    assign multiplication_extension_o = is_multiplication_extension_w;
    
    // CSR 相關訊號提取
    assign csr_address_o = instruction_i[31:20];  // CSR 地址位於指令的高12位
    
    // 系統指令判斷
    wire is_system_instruction_w = (opcode_field_w == OPCODE_SYSTEM);
    wire is_csr_instruction_w = is_system_instruction_w && (funct3_field_w != 3'b000);
    wire is_system_call_instruction_w = is_system_instruction_w && (funct3_field_w == 3'b000);
    
    assign csr_instruction_o = is_csr_instruction_w;
    assign system_instruction_o = is_system_call_instruction_w;
    
    // ============================
    // 6. CSR 操作解碼
    // ============================
    reg [1:0] csr_operation_type_r;
    reg       csr_use_immediate_r;
    
    always @(*) begin
        if (is_csr_instruction_w) begin
            case (funct3_field_w)
                3'b001: begin  // CSRRW
                    csr_operation_type_r = CSR_OP_RW;
                    csr_use_immediate_r = 1'b0;
                end
                3'b010: begin  // CSRRS
                    csr_operation_type_r = CSR_OP_RS;
                    csr_use_immediate_r = 1'b0;
                end
                3'b011: begin  // CSRRC
                    csr_operation_type_r = CSR_OP_RC;
                    csr_use_immediate_r = 1'b0;
                end
                3'b101: begin  // CSRRWI
                    csr_operation_type_r = CSR_OP_RW;
                    csr_use_immediate_r = 1'b1;
                end
                3'b110: begin  // CSRRSI
                    csr_operation_type_r = CSR_OP_RS;
                    csr_use_immediate_r = 1'b1;
                end
                3'b111: begin  // CSRRCI
                    csr_operation_type_r = CSR_OP_RC;
                    csr_use_immediate_r = 1'b1;
                end
                default: begin
                    csr_operation_type_r = 2'b00;
                    csr_use_immediate_r = 1'b0;
                end
            endcase
        end else begin
            csr_operation_type_r = 2'b00;
            csr_use_immediate_r = 1'b0;
        end
    end
    
    assign csr_operation_type_o = csr_operation_type_r;
    assign csr_use_immediate_o = csr_use_immediate_r;
    
    // ============================
    // 7. 基本指令類型判斷
    // ============================
    assign load_upper_immediate_o = (opcode_field_w == OPCODE_LUI);
    assign add_upper_immediate_to_pc_o = (opcode_field_w == OPCODE_AUIPC);
    
    // ============================
    // 8. 暫存器地址提取
    // ============================
    // 對於 LUI/AUIPC 指令，rs1 欄位不使用
    assign rs1_address_o = (opcode_field_w == OPCODE_LUI || opcode_field_w == OPCODE_AUIPC) ? 
                           5'b00000 : rs1_field_w;
    
    assign rs2_address_o = rs2_field_w;
    assign rd_address_o = rd_field_w;
    
    // ============================
    // 9. 控制訊號生成
    // ============================
    assign jump_and_link_o = (opcode_field_w == OPCODE_JAL);
    assign jump_and_link_register_o = (opcode_field_w == OPCODE_JALR);
    assign branch_operation_o = (opcode_field_w == OPCODE_BRANCH);
    assign load_operation_o = (opcode_field_w == OPCODE_LOAD);
    assign store_operation_o = (opcode_field_w == OPCODE_STORE);
    
    // 暫存器寫入使能 (CSR 指令也會寫入暫存器)
    assign register_write_enable_o = 
        (opcode_field_w == OPCODE_LUI) || 
        (opcode_field_w == OPCODE_AUIPC) || 
        (opcode_field_w == OPCODE_JAL) || 
        (opcode_field_w == OPCODE_JALR) || 
        (opcode_field_w == OPCODE_LOAD) || 
        (opcode_field_w == OPCODE_IMM) || 
        (opcode_field_w == OPCODE_REG) || 
        (is_csr_instruction_w);
    
    // ALU B 輸入選擇 (CSR 指令不使用 ALU 的 B 輸入)
    assign alu_source_b_select_o = 
        !(opcode_field_w == OPCODE_REG || opcode_field_w == OPCODE_BRANCH || is_csr_instruction_w);
    
    // ============================
    // 10. 立即數生成邏輯
    // ============================
    reg [31:0] immediate_value_r;
    
    always @(*) begin
        case (opcode_field_w)
            OPCODE_LUI, OPCODE_AUIPC: 
                // U-type: 高位立即數
                immediate_value_r = {instruction_i[31:12], 12'b0};
            
            OPCODE_JAL: 
                // J-type: 跳躍立即數
                immediate_value_r = {{11{instruction_i[31]}}, 
                                     instruction_i[31], 
                                     instruction_i[19:12], 
                                     instruction_i[20], 
                                     instruction_i[30:21], 
                                     1'b0};
            
            OPCODE_BRANCH: 
                // B-type: 分支立即數
                immediate_value_r = {{20{instruction_i[31]}}, 
                                     instruction_i[7], 
                                     instruction_i[30:25], 
                                     instruction_i[11:8], 
                                     1'b0};
            
            OPCODE_STORE: 
                // S-type: 儲存立即數
                immediate_value_r = {{20{instruction_i[31]}}, 
                                     instruction_i[31:25], 
                                     instruction_i[11:7]};
            
            OPCODE_SYSTEM: 
                // CSR 立即數 (來自 rs1 欄位，零擴展)
                immediate_value_r = {27'b0, instruction_i[19:15]};
            
            default: 
                // I-type: 載入/立即數運算/JALR
                immediate_value_r = {{20{instruction_i[31]}}, instruction_i[31:20]};
        endcase
    end
    
    assign immediate_value_o = immediate_value_r;
    
    // ============================
    // 11. ALU 操作碼解碼邏輯
    // ============================
    reg [3:0] alu_operation_r;
    
    always @(*) begin
        alu_operation_r = ALU_OP_ADD;  // 預設為加法
        
        // 優先檢查是否為 CSR 指令
        if (is_csr_instruction_w) begin
            alu_operation_r = ALU_OP_ADD;  // CSR 操作使用加法通路
        end
        // 檢查是否為乘法擴展指令
        else if (is_multiplication_extension_w) begin
            case (funct3_field_w)
                3'b000: alu_operation_r = ALU_OP_MUL;     // MUL
                3'b001: alu_operation_r = ALU_OP_MULH;    // MULH
                3'b010: alu_operation_r = ALU_OP_MULHSU;  // MULHSU
                3'b011: alu_operation_r = ALU_OP_MULHU;   // MULHU
                3'b100: alu_operation_r = ALU_OP_DIV;     // DIV
                3'b101: alu_operation_r = ALU_OP_DIV;     // DIVU (使用相同操作碼)
                3'b110: alu_operation_r = ALU_OP_REM;     // REM
                3'b111: alu_operation_r = ALU_OP_REM;     // REMU (使用相同操作碼)
                default: alu_operation_r = ALU_OP_ADD;
            endcase
        end 
        // 處理分支指令
        else if (opcode_field_w == OPCODE_BRANCH) begin
            case (funct3_field_w)
                3'b000: alu_operation_r = ALU_OP_SUB;   // BEQ (使用減法)
                3'b001: alu_operation_r = ALU_OP_SUB;   // BNE (使用減法)
                3'b100: alu_operation_r = ALU_OP_SLT;   // BLT (有符號小於比較)
                3'b101: alu_operation_r = ALU_OP_SLT;   // BGE (有符號大於等於)
                3'b110: alu_operation_r = ALU_OP_SLTU;  // BLTU (無符號小於)
                3'b111: alu_operation_r = ALU_OP_SLTU;  // BGEU (無符號大於等於)
                default: alu_operation_r = ALU_OP_SUB;
            endcase
        end 
        // 處理標準 R-type 和 I-type 指令
        else if ((opcode_field_w == OPCODE_REG && !is_multiplication_extension_w) || 
                 opcode_field_w == OPCODE_IMM) begin
            case (funct3_field_w)
                3'b000: begin
                    if (opcode_field_w == OPCODE_REG && funct7_field_w[5]) begin
                        alu_operation_r = ALU_OP_SUB;  // SUB
                    end else begin
                        alu_operation_r = ALU_OP_ADD;  // ADD/ADDI
                    end
                end
                3'b001: alu_operation_r = ALU_OP_SLL;   // SLL/SLLI
                3'b010: alu_operation_r = ALU_OP_SLT;   // SLT/SLTI
                3'b011: alu_operation_r = ALU_OP_SLTU;  // SLTU/SLTUI
                3'b100: alu_operation_r = ALU_OP_XOR;   // XOR/XORI
                3'b101: begin
                    if (funct7_field_w[5]) begin
                        alu_operation_r = ALU_OP_SRA;  // SRA/SRAI
                    end else begin
                        alu_operation_r = ALU_OP_SRL;  // SRL/SRLI
                    end
                end
                3'b110: alu_operation_r = ALU_OP_OR;    // OR/ORI
                3'b111: alu_operation_r = ALU_OP_AND;   // AND/ANDI
            endcase
        end
        // 系統調用指令 (ECALL/EBREAK/MRET)
        else if (is_system_call_instruction_w) begin
            alu_operation_r = ALU_OP_ADD;  // 系統調用使用加法通路
        end
    end
    
    assign alu_operation_o = alu_operation_r;
    assign function_3_o = funct3_field_w;
    
endmodule