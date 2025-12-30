module alu(
    input             clk,
    input             rst_n,
    input      [31:0] a,
    input      [31:0] b,
    input      [3:0]  alu_op,
    input       [2:0] funct3,
    input       [6:0] funct7,
    output reg [31:0] result,
    output            zero,
    output            less,   // ✨ 新增輸出：用來判斷比較結果   
    output reg stall_req      // 🆕 新增：請求暫停訊號 
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
    //localparam ALU_MUL  = 4'b1001; // 🏆 選一個沒用過的編碼    
    // 🏆 M-Extension (重新編號 9, 10, 11, 12)
    localparam ALU_MUL    = 4'd9;    // 🆕 修改
    localparam ALU_MULH   = 4'd10;   // 🆕 修改
    localparam ALU_MULHSU = 4'd11;   // 🆕 修改
    localparam ALU_MULHU  = 4'd12;   // 🆕 修改
    localparam ALU_DIV    = 4'd14;   // 🆕 修改 (原 10)
    localparam ALU_REM    = 4'd15;   // 🆕 修改 (原 11)

    integer i; 

    // 建立有符號影子變數，確保比較邏輯正確
    wire signed [31:0] s_a = a;
    wire signed [31:0] s_b = b;

    wire signed [63:0] full_mul_ss = $signed(a) * $signed(b);             // MULH (S*S)
    wire [63:0]        full_mul_uu = a * b;                               // MULHU (U*U)
    wire signed [63:0] full_mul_su = $signed(a) * $signed({1'b0, b});     // MULHSU (S*U)    

    // --- 實例化除法器 ---
    wire div_ready, div_busy;
    wire [31:0] div_quot, div_rem;
    reg div_start;
    wire div_signed = ~funct3[0];

    div_unit u_div (
        .clk(clk), 
        .rst_n(rst_n),
        .start_i(div_start),
        .dividend_i(a), 
        .divisor_i(b),
        .is_signed_i(div_signed),
        .quotient_o(div_quot), .remainder_o(div_rem),
        .ready_o(div_ready), .busy_o(div_busy)
    );    

    always @(*) begin
        result = 32'd0;
        stall_req = 1'b0;  // ✨ 預設不暫停
        div_start = 1'b0;  // ✨ 預設不啟動除法器

        case (alu_op)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            ALU_SLL:  result = a << b[4:0];
            ALU_SRL:  result = a >> b[4:0];
            ALU_SRA:  result = s_a >>> b[4:0]; // 直接用 s_a 即可
            ALU_MUL:    result = full_mul_ss[31:0];  // MUL: 取低位
            ALU_MULH:   result = full_mul_ss[63:32]; // MULH: 取有號高位
            ALU_MULHU:  result = full_mul_uu[63:32]; // MULHU: 取無號高位
            ALU_MULHSU: result = full_mul_su[63:32]; // MULHSU: 取混和高位

            // 🏆 修正後的比較邏輯
            ALU_SLT:  result = (s_a < s_b) ? 32'd1 : 32'd0;
            ALU_SLTU: result = (a < b)     ? 32'd1 : 32'd0;
//            ALU_DIV:  result = 32'd0;//result = (b == 32'd0) ? 32'hFFFFFFFF : (a / b);
//            ALU_REM:  result = 32'd0;//result = (b == 32'd0) ? a : (a % b);
            ALU_DIV, ALU_REM: begin
                if (div_ready) begin
                    // 計算完成，輸出結果，不請求暫停
                    result = (alu_op == ALU_DIV) ? div_quot : div_rem;
                    stall_req = 0;
                    div_start = 0;
                end else begin
                    // 計算中或剛開始
                    stall_req = 1; // 🚨 請求 CPU 暫停！
                    // 如果除法器閒置，就啟動它
                    if (!div_busy) div_start = 1; 
                    else div_start = 0;
                end
            end            
            
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