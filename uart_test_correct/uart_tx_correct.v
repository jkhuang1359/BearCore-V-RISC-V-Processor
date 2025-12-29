module uart_tx_correct #(
    parameter CLK_FREQ = 100000000,
    parameter BAUD_RATE = 1152000
)(
    input clk,
    input rst_n,
    input [7:0] data_i,
    input valid_i,
    input test_mode_i,
    output busy_o,
    output reg tx_o
);

    // 計算位元時間（時鐘週期數）
    // 100,000,000 / 1,152,000 ≈ 86.8055
    // 我們取整到 87 以確保足夠時間
    localparam BIT_PERIOD = (CLK_FREQ + BAUD_RATE/2) / BAUD_RATE;
    
    reg [15:0] clk_cnt;
    reg [3:0] bit_cnt;
    reg [7:0] tx_data;
    reg active;
    
    // 測試 ROM
    reg [3:0] test_ptr;
    reg [7:0] test_rom [0:14];
    initial begin
        test_rom[0]="H"; test_rom[1]="e"; test_rom[2]="l"; test_rom[3]="l"; test_rom[4]="o";
        test_rom[5]="!"; test_rom[6]=" "; test_rom[7]="R"; test_rom[8]="I"; test_rom[9]="S";
        test_rom[10]="C"; test_rom[11]="-"; test_rom[12]="V"; test_rom[13]="!"; test_rom[14]="\n";
    end

    wire [7:0] final_data = (test_mode_i) ? test_rom[test_ptr] : data_i;
    wire final_valid = (test_mode_i) ? (test_ptr < 15 && !active) : valid_i;

    assign busy_o = active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 0;
            bit_cnt <= 0;
            tx_o <= 1;
            active <= 0;
            test_ptr <= 0;
        end else begin
            if (!active) begin
                if (final_valid) begin
                    tx_data <= final_data;
                    active <= 1;
                    clk_cnt <= 0;
                    bit_cnt <= 0;
                    tx_o <= 0; // Start bit
                    $display("[UART] 開始發送: 0x%02h ('%c')", final_data, final_data);
                end
            end else begin
                if (clk_cnt < BIT_PERIOD - 1) begin
                    clk_cnt <= clk_cnt + 1;
                end else begin
                    clk_cnt <= 0;
                    
                    if (bit_cnt < 8) begin
                        tx_o <= tx_data[bit_cnt];
                        $display("[UART] 發送位元 %0d: %b", bit_cnt, tx_data[bit_cnt]);
                        bit_cnt <= bit_cnt + 1;
                    end else if (bit_cnt == 8) begin
                        tx_o <= 1; // Stop bit
                        $display("[UART] 發送停止位");
                        bit_cnt <= bit_cnt + 1;
                    end else begin
                        active <= 0;
                        $display("[UART] 發送完成");
                        if (test_mode_i && test_ptr < 15) begin
                            test_ptr <= test_ptr + 1;
                        end
                    end
                end
            end
        end
    end
    
    // 顯示參數
    initial begin
        $display("[UART] CLK_FREQ = %0d, BAUD_RATE = %0d", CLK_FREQ, BAUD_RATE);
        $display("[UART] BIT_PERIOD = %0d 個時鐘週期", BIT_PERIOD);
        $display("[UART] 位元時間 = %0.3f ns", (1.0 * BIT_PERIOD * 10));
    end
    
endmodule
