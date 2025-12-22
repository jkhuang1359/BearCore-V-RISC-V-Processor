// src/pipe_regs.v - Final Clean Version

// 1. IF -> ID
module pipe_if_id(
    input wire clk,
    input wire rst_n,
    input wire stall,
    input wire flush,
    input wire [31:0] pc_in,
    input wire [31:0] inst_in,
    output reg [31:0] pc_out,
    output reg [31:0] inst_out
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            pc_out   <= 0;
            inst_out <= 0;
        end else if (!stall) begin
            pc_out   <= pc_in;
            inst_out <= inst_in;
        end
    end
endmodule

// 2. ID -> EX 
module pipe_id_ex(
    input wire clk,
    input wire rst_n,
    input wire flush,
    input wire [31:0] pc_in,
    input wire [31:0] rs1_data_in,
    input wire [31:0] rs2_data_in,
    input wire [31:0] imm_in,
    input wire [4:0]  rd_addr_in,
    input wire [4:0]  rs1_addr_in, 
    input wire [4:0]  rs2_addr_in, 
    input wire [2:0]  funct3_in,
    input wire [3:0]  alu_op_in,
    input wire        alu_src_b_in,
    input wire        mem_wen_in,
    input wire        reg_wen_in,
    input wire        is_load_in,
    input wire        is_jal_in,
    input wire        is_jalr_in,
    input wire        is_branch_in,
    input wire        is_lui_in,
    
    output reg [31:0] pc_out,
    output reg [31:0] rs1_data_out,
    output reg [31:0] rs2_data_out,
    output reg [31:0] imm_out,
    output reg [4:0]  rd_addr_out,
    output reg [4:0]  rs1_addr_out, 
    output reg [4:0]  rs2_addr_out, 
    output reg [2:0]  funct3_out,
    output reg [3:0]  alu_op_out,
    output reg        alu_src_b_out,
    output reg        mem_wen_out,
    output reg        reg_wen_out,
    output reg        is_load_out,
    output reg        is_jal_out,
    output reg        is_jalr_out,
    output reg        is_branch_out,
    output reg        is_lui_out
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            pc_out <= 0; rs1_data_out <= 0; rs2_data_out <= 0; imm_out <= 0; 
            rd_addr_out <= 0; rs1_addr_out <= 0; rs2_addr_out <= 0; funct3_out <= 0;
            alu_op_out <= 0; alu_src_b_out <= 0; mem_wen_out <= 0; reg_wen_out <= 0; is_load_out <= 0;
            is_jal_out <= 0; is_jalr_out <= 0; is_branch_out <= 0; is_lui_out <= 0;
        end else begin
            pc_out <= pc_in; rs1_data_out <= rs1_data_in; rs2_data_out <= rs2_data_in; 
            imm_out <= imm_in; rd_addr_out <= rd_addr_in; 
            rs1_addr_out <= rs1_addr_in; rs2_addr_out <= rs2_addr_in; 
            funct3_out <= funct3_in;
            alu_op_out <= alu_op_in; alu_src_b_out <= alu_src_b_in; mem_wen_out <= mem_wen_in; 
            reg_wen_out <= reg_wen_in; is_load_out <= is_load_in;
            is_jal_out <= is_jal_in; is_jalr_out <= is_jalr_in; is_branch_out <= is_branch_in;
            is_lui_out <= is_lui_in;
        end
    end
endmodule

// 3. EX -> MEM
module pipe_ex_mem(
    input wire clk,
    input wire rst_n,
    input wire [31:0] alu_result_in,
    input wire [31:0] rs2_data_in,
    input wire [4:0]  rd_addr_in,
    input wire [31:0] pc_plus_4_in,
    input wire        mem_wen_in,
    input wire        reg_wen_in,
    input wire        is_load_in,
    input wire        is_jal_jalr_in,
    input wire        is_lui_in,
    output reg [31:0] alu_result_out,
    output reg [31:0] rs2_data_out,
    output reg [4:0]  rd_addr_out,
    output reg [31:0] pc_plus_4_out,
    output reg        mem_wen_out,
    output reg        reg_wen_out,
    output reg        is_load_out,
    output reg        is_jal_jalr_out,
    output reg        is_lui_out
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alu_result_out <= 0; rs2_data_out <= 0; rd_addr_out <= 0; pc_plus_4_out <= 0;
            mem_wen_out <= 0; reg_wen_out <= 0; is_load_out <= 0; is_jal_jalr_out <= 0;
            is_lui_out <= 0;
        end else begin
            alu_result_out <= alu_result_in; rs2_data_out <= rs2_data_in; 
            rd_addr_out <= rd_addr_in; pc_plus_4_out <= pc_plus_4_in;
            mem_wen_out <= mem_wen_in; reg_wen_out <= reg_wen_in; 
            is_load_out <= is_load_in; is_jal_jalr_out <= is_jal_jalr_in;
            is_lui_out <= is_lui_in;
        end
    end
endmodule

// 4. MEM -> WB
module pipe_mem_wb(
    input wire clk,
    input wire rst_n,
    input wire [31:0] ram_rdata_in,
    input wire [31:0] alu_result_in,
    input wire [4:0]  rd_addr_in,
    input wire [31:0] pc_plus_4_in,
    input wire        reg_wen_in,
    input wire        is_load_in,
    input wire        is_jal_jalr_in,
    output reg [31:0] ram_rdata_out,
    output reg [31:0] alu_result_out,
    output reg [4:0]  rd_addr_out,
    output reg [31:0] pc_plus_4_out,
    output reg        reg_wen_out,
    output reg        is_load_out,
    output reg        is_jal_jalr_out
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ram_rdata_out <= 0; alu_result_out <= 0; rd_addr_out <= 0; pc_plus_4_out <= 0;
            reg_wen_out <= 0; is_load_out <= 0; is_jal_jalr_out <= 0;
        end else begin
            ram_rdata_out <= ram_rdata_in; alu_result_out <= alu_result_in; 
            rd_addr_out <= rd_addr_in; pc_plus_4_out <= pc_plus_4_in;
            reg_wen_out <= reg_wen_in; is_load_out <= is_load_in; is_jal_jalr_out <= is_jal_jalr_in;
        end
    end
endmodule