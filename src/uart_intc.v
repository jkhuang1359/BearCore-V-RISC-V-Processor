`timescale 1ns/1ps
`include "include/riscv_defines.vh"

// =============================================================================
// UART 中斷控制器模組
// =============================================================================
module uart_interrupt_controller (
    // 時脈與重置
    input  wire        clk_i,
    input  wire        reset_ni,
    
    // UART狀態輸入
    input  wire        uart_busy_i,
    input  wire        uart_receive_ready_i,
    input  wire        uart_read_ack_i,
    
    // 軟體控制介面
    input  wire [31:0] uart_ie_i,                // UART中斷使能寄存器
    input  wire        mem_is_uart_status_i,     // 訪問UART狀態寄存器
    input  wire        mem_write_enable_i,       // 記憶體寫入使能
    input  wire [31:0] mem_write_data_i,         // 寫入資料
    input  wire        mem_load_operation_i,     // 載入操作
    
    // 中斷輸出
    output reg         uart_tx_int_pending_o,    // TX中斷掛起
    output reg         uart_rx_int_pending_o,    // RX中斷掛起
    output wire        uart_int_raw_o            // 原始中斷信號
);
    
// uart_intc.v - 修改TX中断逻辑
always @(posedge clk_i or negedge reset_ni) begin
    if (!reset_ni) begin
        uart_tx_int_pending_o <= 1'b0;
    end else begin
        // TX中断：当发送完成（busy从1变0）且中断使能时
        if (!uart_busy_i && uart_ie_i[0]) begin
            uart_tx_int_pending_o <= 1'b1;
        end else if (mem_is_uart_status_i && mem_write_enable_i && mem_write_data_i[0]) begin
            // 软件清除
            uart_tx_int_pending_o <= 1'b0;
        end
    end
end

// RX中断逻辑保持不变
always @(posedge clk_i or negedge reset_ni) begin
    if (!reset_ni) begin
        uart_rx_int_pending_o <= 1'b0;
    end else begin
        if (uart_receive_ready_i && uart_ie_i[1]) begin
            uart_rx_int_pending_o <= 1'b1;
        end else if (uart_read_ack_i) begin
            uart_rx_int_pending_o <= 1'b0;
        end else if (mem_is_uart_status_i && mem_write_enable_i && mem_write_data_i[1]) begin
            uart_rx_int_pending_o <= 1'b0;
        end
    end
end

// 组合逻辑生成原始中断信号
assign uart_int_raw_o = (uart_tx_int_pending_o && uart_ie_i[0]) ||
                       (uart_rx_int_pending_o && uart_ie_i[1]);
    
    // 模擬調試
`ifdef SIMULATION
    always @(posedge clk_i) begin
        if (uart_tx_complete_edge_w) begin
            $display("[UART INTC] TX complete edge detected");
        end
        if (uart_rx_ready_edge_w) begin
            $display("[UART INTC] RX ready edge detected");
        end
        if (uart_tx_int_pending_o && uart_ie_i[0]) begin
            $display("[UART INTC] TX interrupt pending");
        end
        if (uart_rx_int_pending_o && uart_ie_i[1]) begin
            $display("[UART INTC] RX interrupt pending");
        end
        if (uart_int_raw_o) begin
            $display("[UART INTC] Raw interrupt asserted");
        end
    end
`endif
    
endmodule