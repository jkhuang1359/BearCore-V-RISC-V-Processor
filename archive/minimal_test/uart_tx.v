module uart_tx #(
    parameter CLK_FREQ = 100000000,
    parameter BAUD_RATE = 115200
)(
    input clk,
    input rst_n,
    input [7:0] data_i,
    input valid_i,
    input test_mode_i, // ✨ 新增：測試模式開關
    output busy_o,
    output reg tx_o
);

    // --- 原有的 UART 邏輯暫存器 ---
    parameter BIT_PERIOD = CLK_FREQ / BAUD_RATE;
    reg [15:0] clk_cnt;
    reg [3:0] bit_cnt;
    reg [7:0] tx_data;
    reg active;

    // --- ✨ 測試模式專用邏輯 ---
    reg [3:0] test_ptr;
    reg [7:0] test_rom [0:14];
    initial begin
        test_rom[0]="H"; test_rom[1]="e"; test_rom[2]="l"; test_rom[3]="l"; test_rom[4]="o";
        test_rom[5]="!"; test_rom[6]=" "; test_rom[7]="R"; test_rom[8]="I"; test_rom[9]="S";
        test_rom[10]="C"; test_rom[11]="-"; test_rom[12]="V"; test_rom[13]="!"; test_rom[14]="\n";
    end

    // 多工器：選擇資料來源 (CPU 或是測試 ROM)
    wire [7:0] final_data = (test_mode_i) ? test_rom[test_ptr] : data_i;
    wire final_valid = (test_mode_i) ? (test_ptr < 15 && !active) : valid_i;

    assign busy_o = active;

    // UART 核心狀態機 (發送邏輯)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 0; bit_cnt <= 0; tx_o <= 1; active <= 0; test_ptr <= 0;
        end else begin
            if (!active) begin
                if (final_valid) begin
                    tx_data <= final_data;
                    active <= 1;
                    clk_cnt <= 0;
                    bit_cnt <= 0;
                    tx_o <= 0; // Start bit
                end
            end else begin
                if (clk_cnt < BIT_PERIOD - 1) begin
                    clk_cnt <= clk_cnt + 1;
                end else begin
                    clk_cnt <= 0;
                    if (bit_cnt < 8) begin
                        tx_o <= tx_data[bit_cnt];
                        bit_cnt <= bit_cnt + 1;
                    end else if (bit_cnt == 8) begin
                        tx_o <= 1; // Stop bit
                        bit_cnt <= bit_cnt + 1;
                    end else begin
                        active <= 0;
                        if (test_mode_i && test_ptr < 15) test_ptr <= test_ptr + 1;
                    end
                end
            end
        end
    end
endmodule