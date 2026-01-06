`timescale 1ns/1ps  // <--- 🐻 關鍵修正：定義時間單位！
module uart_rx #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD_RATE = 115200
)(
    input        clk,
    input        rst_n,
    input        rx_i,        // UART RX 實體引腳
    input        read_en_i,   // CPU 讀取使能 (讀取後清除 ready)
    output [7:0] data_o,      // 收到的資料
    output reg   ready_o      // 資料準備好標誌
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    // 狀態機定義
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0]  state;
    reg [31:0] clk_cnt;
    reg [2:0]  bit_cnt;
    reg [7:0]  rx_data;
    
    // 🏆 採樣同步：防止亞穩態
    reg rx_sync_0, rx_sync_1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync_0 <= 1'b1;
            rx_sync_1 <= 1'b1;
        end else begin
            rx_sync_0 <= rx_i;
            rx_sync_1 <= rx_sync_0;
        end
    end

    // 🏆 主狀態機
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            clk_cnt  <= 0;
            bit_cnt  <= 0;
            rx_data  <= 8'b0;
            ready_o  <= 1'b0;
        end else begin
            // 讀取握手：一旦 CPU 讀取，就清除 ready 位元
            if (read_en_i) ready_o <= 1'b0;

            case (state)
                IDLE: begin
                    clk_cnt <= 0;
                    bit_cnt <= 0;
                    if (rx_sync_1 == 1'b0) begin // 偵測到起始位元 (下降沿)
                        state <= START;
                    end
                end

                START: begin
                    if (clk_cnt == (CLKS_PER_BIT / 2)) begin
                        if (rx_sync_1 == 1'b0) begin // 確認中點仍為低電平
                            clk_cnt <= 0;
                            state   <= DATA;
                        end else begin
                            state   <= IDLE; // 雜訊誤判，回到 IDLE
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                DATA: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        rx_data[bit_cnt] <= rx_sync_1; // 在位元中點採樣
                        if (bit_cnt == 7) begin
                            state <= STOP;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                STOP: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        ready_o <= 1'b1; // 接收完成
                        state   <= IDLE;
                        clk_cnt <= 0;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    assign data_o = rx_data;

endmodule