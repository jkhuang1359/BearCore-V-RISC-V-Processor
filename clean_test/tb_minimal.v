`timescale 1ns/1ps

module tb_minimal;
    reg clk;
    reg rst_n;
    wire uart_tx;
    
    // 實例化CPU核心
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx_o(uart_tx)
    );
    
    // 時鐘生成
    always #5 clk = ~clk;
    
    // 監控信號
    always @(posedge clk) begin
        if (u_core.ex_is_branch) begin
            $display("[%0t] EX階段: ex_is_branch=%b, branch_met=%b, ex_take_branch=%b", 
                    $time, u_core.ex_is_branch, u_core.branch_met, u_core.ex_take_branch);
        end
        
        if (u_core.id_is_branch) begin
            $display("[%0t] ID階段: id_is_branch=%b, PC=%08h", 
                    $time, u_core.id_is_branch, u_core.id_pc);
        end
    end
    
    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        
        // 復位
        #20;
        rst_n = 1;
        
        // 運行100個時鐘周期
        #1000;
        
        // 顯示最終PC和寄存器
        $display("\n=== 仿真結束 ===");
        $display("最終PC: %08h", u_core.pc);
        $display("寄存器 x1: %08h, x2: %08h", 
                u_core.u_regfile.regs[1], u_core.u_regfile.regs[2]);
        
        $finish;
    end
    
    // VCD波形文件
    initial begin
        $dumpfile("minimal.vcd");
        $dumpvars(0, tb_minimal);
    end
endmodule
