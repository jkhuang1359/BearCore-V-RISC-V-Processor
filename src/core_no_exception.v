// 在core.v的基礎上修改，完全禁用例外
module core(
    input clk,
    input rst_n,
    input external_int,
    input software_int,      
    output uart_tx_o
);

    // 複製原始core.v的內容，但修改例外處理部分
    // 由於core.v很長，我們直接修改原始文件
    // 但為了簡單，我們先嘗試在測試中禁用例外
endmodule
