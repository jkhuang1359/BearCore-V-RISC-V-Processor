`timescale 1ns/1ps

// =============================================================================
// 算術邏輯單元 (ALU)
// 功能：
// 1. 執行所有 RV32I 算術與邏輯運算
// 2. 支援乘法擴展 (M-extension)
// 3. 支援除法運算
// 4. 提供零旗標與比較旗標輸出
// 5. 支援流水線暫停請求
// =============================================================================
module arithmetic_logic_unit (
    // 時脈與重置訊號
    input  wire        clk_i,                     // 時脈輸入
    input  wire        reset_ni,                  // 低態有效重置
    
    // 操作數輸入
    input  wire [31:0] operand_a_i,               // 操作數 A
    input  wire [31:0] operand_b_i,               // 操作數 B
    
    // 控制輸入
    input  wire [3:0]  alu_operation_i,           // ALU 操作碼
    input  wire [2:0]  function_3_i,              // funct3 欄位
    input  wire [6:0]  function_7_i,              // funct7 欄位
    
    // 結果輸出
    output reg  [31:0] result_o,                  // 計算結果
    output wire        zero_flag_o,               // 零旗標 (A == B)
    output wire        less_flag_o,               // 小於旗標 (A < B)
    
    // 流水線控制
    output reg         stall_request_o            // 暫停請求 (用於除法/乘法)
);

    // ============================
    // 1. 常數與參數定義
    // ============================
    
    // 基礎運算操作碼
    localparam ALU_OP_ADD    = 4'b0000;  // 加法
    localparam ALU_OP_SUB    = 4'b1000;  // 減法
    localparam ALU_OP_AND    = 4'b0111;  // 邏輯與
    localparam ALU_OP_OR     = 4'b0110;  // 邏輯或
    localparam ALU_OP_XOR    = 4'b0100;  // 邏輯互斥或
    localparam ALU_OP_SLL    = 4'b0001;  // 邏輯左移
    localparam ALU_OP_SRL    = 4'b0101;  // 邏輯右移
    localparam ALU_OP_SRA    = 4'b1101;  // 算術右移
    localparam ALU_OP_SLT    = 4'b0010;  // 有符號小於比較
    localparam ALU_OP_SLTU   = 4'b0011;  // 無符號小於比較
    
    // 乘法擴展操作碼
    localparam ALU_OP_MUL    = 4'd9;     // 乘法 (低32位)
    localparam ALU_OP_MULH   = 4'd10;    // 乘法 (高32位，有符號×有符號)
    localparam ALU_OP_MULHSU = 4'd11;    // 乘法 (高32位，有符號×無符號)
    localparam ALU_OP_MULHU  = 4'd12;    // 乘法 (高32位，無符號×無符號)
    
    // 除法運算操作碼
    localparam ALU_OP_DIV    = 4'd14;    // 除法
    localparam ALU_OP_REM    = 4'd15;    // 餘數
    
    // ============================
    // 2. 內部訊號宣告
    // ============================
    integer loop_index;                          // 迴圈索引
    
    // 乘法相關訊號
    reg [63:0] multiplication_result_r;          // 乘法結果暫存器
    reg        multiplication_busy_r;            // 乘法忙碌標誌
    
    // 除法相關訊號
    wire        division_ready_w;                // 除法器就緒標誌
    wire        division_busy_w;                 // 除法器忙碌標誌
    wire [31:0] division_quotient_w;             // 除法商數
    wire [31:0] division_remainder_w;            // 除法餘數
    reg         division_start_r;                // 除法開始標誌
    
    // 有符號操作數轉換
    wire signed [31:0] signed_operand_a_w = operand_a_i;
    wire signed [31:0] signed_operand_b_w = operand_b_i;
    
    // 操作類型判斷
    wire is_multiplication_operation_w = (alu_operation_i >= 4'd9 && alu_operation_i <= 4'd12);
    
    // ============================
    // 3. 除法器實例化
    // ============================
    division_unit u_division_unit (
        .clk_i(clk_i),
        .reset_ni(reset_ni),
        .start_i(division_start_r),
        .dividend_i(operand_a_i),
        .divisor_i(operand_b_i),
        .signed_operation_i(~function_3_i[0]),  // funct3[0]=0 表示有符號運算
        .quotient_o(division_quotient_w),
        .remainder_o(division_remainder_w),
        .ready_o(division_ready_w),
        .busy_o(division_busy_w)
    );
    
    // ============================
    // 4. 乘法管道邏輯
    // ============================
    always @(posedge clk_i or negedge reset_ni) begin
        if (!reset_ni) begin
            multiplication_result_r <= 64'b0;
            multiplication_busy_r <= 1'b0;
        end else if (is_multiplication_operation_w && !multiplication_busy_r) begin
            multiplication_busy_r <= 1'b1;  // 開始運算
            
            case (alu_operation_i)
                ALU_OP_MUL:    multiplication_result_r <= $signed(operand_a_i) * $signed(operand_b_i);      // 有符號乘法
                ALU_OP_MULH:   multiplication_result_r <= $signed(operand_a_i) * $signed(operand_b_i);      // 有符號乘法 (高32位)
                ALU_OP_MULHSU: multiplication_result_r <= $signed(operand_a_i) * $signed({1'b0, operand_b_i});  // 有符號×無符號
                ALU_OP_MULHU:  multiplication_result_r <= operand_a_i * operand_b_i;                        // 無符號乘法
            endcase
        end else begin
            multiplication_busy_r <= 1'b0;  // 運算完成
        end
    end
    
    // ============================
    // 5. ALU 運算核心邏輯
    // ============================
    always @(*) begin
        // 預設值
        result_o = 32'd0;
        stall_request_o = 1'b0;
        division_start_r = 1'b0;
        
        // 檢查是否為乘法操作
        if (is_multiplication_operation_w) begin
            if (multiplication_busy_r) begin
                // 乘法運算完成，輸出結果
                stall_request_o = 1'b0;
                
                case (alu_operation_i)
                    ALU_OP_MUL:  result_o = multiplication_result_r[31:0];   // 乘法低32位
                    default:     result_o = multiplication_result_r[63:32];  // 乘法高32位
                endcase
            end else begin
                // 乘法運算開始，請求暫停一個週期
                stall_request_o = 1'b1;
            end
        end 
        // 檢查是否為除法或取餘操作
        else if (alu_operation_i == ALU_OP_DIV || alu_operation_i == ALU_OP_REM) begin
            if (division_ready_w) begin
                // 除法運算完成
                result_o = (alu_operation_i == ALU_OP_DIV) ? division_quotient_w : division_remainder_w;
                stall_request_o = 1'b0;
                division_start_r = 1'b0;
            end else begin
                // 除法運算中或需要啟動
                stall_request_o = 1'b1;  // 請求 CPU 暫停
                
                if (!division_busy_w) begin
                    division_start_r = 1'b1;  // 啟動除法器
                end else begin
                    division_start_r = 1'b0;  // 除法器已在運算中
                end
            end
        end
        // 基礎算術邏輯運算
        else begin
            case (alu_operation_i)
                ALU_OP_ADD:  result_o = operand_a_i + operand_b_i;                     // 加法
                ALU_OP_SUB:  result_o = operand_a_i - operand_b_i;                     // 減法
                ALU_OP_AND:  result_o = operand_a_i & operand_b_i;                     // 邏輯與
                ALU_OP_OR:   result_o = operand_a_i | operand_b_i;                     // 邏輯或
                ALU_OP_XOR:  result_o = operand_a_i ^ operand_b_i;                     // 邏輯互斥或
                ALU_OP_SLL:  result_o = operand_a_i << operand_b_i[4:0];               // 邏輯左移
                ALU_OP_SRL:  result_o = operand_a_i >> operand_b_i[4:0];               // 邏輯右移
                ALU_OP_SRA:  result_o = signed_operand_a_w >>> operand_b_i[4:0];       // 算術右移
                
                // 有符號小於比較
                ALU_OP_SLT:  result_o = (signed_operand_a_w < signed_operand_b_w) ? 32'd1 : 32'd0;
                
                // 無符號小於比較  
                ALU_OP_SLTU: result_o = (operand_a_i < operand_b_i) ? 32'd1 : 32'd0;
                
                // 未定義操作碼
                default: begin
                    result_o = 32'd0;
                end
            endcase
        end
    end
    
    // ============================
    // 6. 旗標生成邏輯
    // ============================
    
    // 零旗標 (用於 BEQ/BNE 指令)
    assign zero_flag_o = (operand_a_i == operand_b_i);
    
    // 小於旗標 (用於分支指令)
    // 注意: SLTU 使用無符號比較，其他使用有符號比較
    assign less_flag_o = (alu_operation_i == ALU_OP_SLTU) ? 
                         (operand_a_i < operand_b_i) : 
                         ($signed(operand_a_i) < $signed(operand_b_i));
    
endmodule