module hazard(
    // ID Stage 讀取的來源暫存器
    input [4:0] id_rs1_addr,
    input [4:0] id_rs2_addr,

    input       ex_is_lui,
    
    // EX Stage 的指令
    input       ex_is_load,    // EX 階段是否為 LOAD？
    input [4:0] ex_rd_addr,    // EX 階段寫回誰？
    
    // 輸出
    output reg stall
);

    wire ex_needs_stall = ex_is_load || ex_is_lui; // ✅ 讓 LUI 像 LOAD 一樣危險


    always @(*) begin
        stall = 1'b0;


        // Load-Use Hazard Detection
        // 如果 EX 階段是 LOAD (is_load)，且它的寫回目標 (ex_rd_addr)
        // 剛好被 ID 階段的 rs1 或 rs2 需要，則必須 STALL 一個週期。
        if (ex_is_load && (ex_rd_addr != 0)) begin
            if ((ex_rd_addr == id_rs1_addr) || (ex_rd_addr == id_rs2_addr)) begin
                stall = 1'b1;
            end
        end
    end

endmodule