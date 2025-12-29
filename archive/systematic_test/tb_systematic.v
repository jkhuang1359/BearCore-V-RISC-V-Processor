`timescale 1ns/1ps

module tb_systematic;
    reg clk;
    reg rst_n;
    
    // 實例化核心
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx_o()
    );
    
    // 時鐘 (10MHz，便於觀察)
    always #50 clk = ~clk;
    
    integer cycle_count = 0;
    reg [31:0] last_pc = 0;
    
    // 監視PC變化
    always @(posedge clk) begin
        if (rst_n) begin
            cycle_count <= cycle_count + 1;
            
            // 顯示前20個週期
            if (cycle_count < 20) begin
                $display("週期 %0d: PC=0x%08h, 指令=0x%08h, 狀態=%s", 
                        cycle_count, 
                        u_core.pc, 
                        u_core.id_inst,
                        (u_core.pc == last_pc + 4) ? "正常" : "異常");
            end
            
            last_pc <= u_core.pc;
            
            // 安全停止
            if (cycle_count > 30) begin
                $display("測試結束");
                $finish;
            end
        end
    end
    
    initial begin
        $dumpfile("systematic.vcd");
        $dumpvars(0, tb_systematic);
        
        clk = 0;
        rst_n = 0;
        
        $display("========================================");
        $display("系統性測試 Level 1: PC遞增");
        $display("========================================");
        
        // 復位
        #100;
        rst_n = 1;
        $display("復位釋放");
        
        // 運行足夠時間
        #5000;
        $finish;
    end
    
    // 檢查PC是否正確執行
    always @(posedge clk) begin
        if (rst_n && u_core.pc >= 32'h00000014) begin
            $display("✅ PC已執行到0x%08h，基本功能正常", u_core.pc);
        end
    end
endmodule