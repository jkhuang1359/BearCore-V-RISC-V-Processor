module div_unit (
    input wire clk,
    input wire rst_n,
    input wire start_i,
    input wire [31:0] dividend_i,
    input wire [31:0] divisor_i,
    input wire is_signed_i,
    output reg [31:0] quotient_o,
    output reg [31:0] remainder_o,
    output reg ready_o,
    output reg busy_o
);

    // 狀態機定義
    localparam IDLE = 2'd0, CALC = 2'd1, SIGN_FIX = 2'd2, DONE = 2'd3;
    reg [1:0] state; // 🏆 移除 next_state，直接控制 state

    reg [31:0] temp_a, temp_b;
    reg [63:0] temp_p;
    reg [5:0]  count;
    reg sign_q, sign_r;
    
    // 組合邏輯運算變數
    reg [63:0] calc_temp;

    // --------------------------------------------------------
    // 1. 純組合邏輯區塊：負責運算
    // --------------------------------------------------------
    always @(*) begin
        calc_temp = temp_p;
        if (state == CALC) begin
            calc_temp = temp_p << 1;
            if (calc_temp[63:32] >= temp_b) begin
                calc_temp[63:32] = calc_temp[63:32] - temp_b;
                calc_temp[0] = 1'b1;
            end
        end
    end

    // --------------------------------------------------------
    // 2. 核心時序邏輯 (狀態機 + 資料路徑合併)
    // --------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; // 🏆 直接重置 state
            quotient_o <= 0;
            remainder_o <= 0;
            ready_o <= 0; busy_o <= 0; count <= 0;
            temp_a <= 0; temp_b <= 0;
            temp_p <= 0;
            sign_q <= 0; sign_r <= 0;
        end else begin
            case (state)
                IDLE: begin
                    ready_o <= 0;
                    if (start_i) begin
                        busy_o <= 1;
                        count <= 32;
                        sign_q <= is_signed_i ? (dividend_i[31] ^ divisor_i[31]) : 0;
                        sign_r <= is_signed_i ? dividend_i[31] : 0;
                        temp_a = (is_signed_i && dividend_i[31]) ? -dividend_i : dividend_i;
                        temp_b = (is_signed_i && divisor_i[31]) ? -divisor_i : divisor_i;
                        temp_p <= {32'b0, temp_a};
                        
                        state <= CALC; // 🏆 直接跳轉，不再延遲！
                    end else begin
                        busy_o <= 0;
                        state <= IDLE;
                    end
                end

                CALC: begin
                    if (count > 0) begin
                        temp_p <= calc_temp; // 存入組合邏輯算好的值
                        count <= count - 1;
                    end else begin
                        state <= SIGN_FIX; // 🏆 直接跳轉
                    end
                end

                SIGN_FIX: begin
                    quotient_o  <= sign_q ? -temp_p[31:0] : temp_p[31:0];
                    remainder_o <= sign_r ? -temp_p[63:32] : temp_p[63:32];
                    state <= DONE; // 🏆 直接跳轉
                end

                DONE: begin
                    busy_o <= 0;
                    ready_o <= 1;
                    state <= IDLE; // 🏆 直接跳轉
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule