`timescale 1ns/1ps

module tb_detailed;
    reg clk;
    reg rst_n;
    
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx_o()
    );
    
    // 慢時鐘便於觀察
    always #100 clk = ~clk;
    
    // 顯示所有信息
    integer cycle = 0;
    always @(posedge clk) begin
        if (rst_n) begin
            cycle <= cycle + 1;
            
            $display("週期 %0d:", cycle);
            $display("  PC = 0x%08h", u_core.pc);
            $display("  指令 = 0x%08h", u_core.id_inst);
            $display("  下一PC = 0x%08h", u_core.pc_next);
            
            if (u_core.pc >= 32'h00000018) begin
                $display("⚠️  警告：PC進入了未定義區域");
                $display("  檢查ROM大小和PC計算邏輯");
            end
            
            if (cycle > 15) begin
                $display("測試結束");
                $finish;
            end
        end
    end
    
    initial begin
        $dumpfile("detailed.vcd");
        $dumpvars(0, tb_detailed);
        
        clk = 0;
        rst_n = 0;
        
        $display("CPU詳細診斷開始");
        
        #200;
        rst_n = 1;
        
        #5000;
        $finish;
    end
endmodule
