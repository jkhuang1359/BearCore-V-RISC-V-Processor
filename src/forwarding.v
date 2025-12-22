module forwarding(
    // 來源：目前在 EX 階段的指令需要誰？
    input [4:0] ex_rs1_addr,
    input [4:0] ex_rs2_addr,
    
    // 目標 1：MEM 階段的指令寫回誰？
    input       mem_reg_wen,
    input [4:0] mem_rd_addr,
    
    // 目標 2：WB 階段的指令寫回誰？
    input       wb_reg_wen,
    input [4:0] wb_rd_addr,

    // 輸出：00=原值, 01=來自WB, 10=來自MEM
    output reg [1:0] forward_a,
    output reg [1:0] forward_b
);

    always @(*) begin
        // default: 不前遞 (用 ID 階段讀到的值)
        forward_a = 2'b00;
        forward_b = 2'b00;

        // --- Forward A (給 rs1) ---
        // 優先權：MEM 階段 > WB 階段 (因為 MEM 比較新)
        
        // 1. 檢查 MEM 階段 (Ex Hazard)
        if (mem_reg_wen && (mem_rd_addr != 0) && (mem_rd_addr == ex_rs1_addr)) begin
            forward_a = 2'b10;
        end
        // 2. 檢查 WB 階段 (Mem Hazard)
        else if (wb_reg_wen && (wb_rd_addr != 0) && (wb_rd_addr == ex_rs1_addr)) begin
            forward_a = 2'b01;
        end

        // --- Forward B (給 rs2) ---
        
        // 1. 檢查 MEM 階段
        if (mem_reg_wen && (mem_rd_addr != 0) && (mem_rd_addr == ex_rs2_addr)) begin
            forward_b = 2'b10;
        end
        // 2. 檢查 WB 階段
        else if (wb_reg_wen && (wb_rd_addr != 0) && (wb_rd_addr == ex_rs2_addr)) begin
            forward_b = 2'b01;
        end
    end

endmodule