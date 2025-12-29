module alu(
    input      [31:0] a,
    input      [31:0] b,
    input      [3:0]  alu_op,
    output reg [31:0] result,
    output            zero,
    output            less   // ✨ 新增輸出：用來判斷比較結果    
);

    // 🏆 統一運算碼定義 (建議與 decoder.v 保持絕對一致)
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b1000;
    localparam ALU_AND  = 4'b0111;
    localparam ALU_OR   = 4'b0110;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0001; 
    localparam ALU_SRL  = 4'b0101; 
    localparam ALU_SRA  = 4'b1101; 
    localparam ALU_SLT  = 4'b0010; // RISC-V 標準碼
    localparam ALU_SLTU = 4'b0011; // RISC-V 標準碼
    localparam ALU_MUL  = 4'b1001; // 🏆 選一個沒用過的編碼    
    localparam ALU_DIV  = 4'b1010; 
    localparam ALU_REM  = 4'b1011;
    localparam ALU_CSR  = 4'b1110; // 🏆 新增：CSR 操作
    localparam ALU_SYS  = 4'b1111; // 🏆 新增：系統調用

    integer i; 

    // 建立有符號影子變數，確保比較邏輯正確
    wire signed [31:0] s_a = a;
    wire signed [31:0] s_b = b;

    always @(*) begin
        case (alu_op)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            ALU_SLL:  result = a << b[4:0];
            ALU_SRL:  result = a >> b[4:0];
            ALU_SRA:  result = s_a >>> b[4:0]; // 直接用 s_a 即可
            ALU_MUL:  result = a * b; // 🏆 硬體乘法

            // 🏆 修正後的比較邏輯
            ALU_SLT:  result = (s_a < s_b) ? 32'd1 : 32'd0;
            ALU_SLTU: result = (a < b)     ? 32'd1 : 32'd0;
            ALU_DIV:  result = (b == 32'd0) ? 32'hFFFFFFFF : (a / b);
            ALU_REM:  result = (b == 32'd0) ? a : (a % b);
            
            default: begin
                result = 32'd0;
                // 調試輸出：如果執行到這裡，說明 alu_op 不是預期的值
            end
        endcase
    end

// --- 修改 alu.v 最後兩行 ---
    assign zero = (a == b);
    // 🏆 確保 SLTU (0011) 走無符號比較，其他走有符號比較
    assign less = (alu_op == 4'b0011) ? (a < b) : ($signed(a) < $signed(b));

endmodule