`timescale 1ns/1ps
module tb_debug;
    reg clk;
    reg rst_n;
    wire uart_tx;
    
    // 實例化核心
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx_o(uart_tx),
        .external_int(1'b0),
        .software_int(1'b0)
    );
    
    // 時鐘生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // 主測試序列
    initial begin
        $dumpfile("cpu_debug.vcd");
        $dumpvars(0, tb_debug);
        
        // 初始化
        rst_n = 0;
        
        // 復位
        #100 rst_n = 1;
        $display("[TEST] Reset released at time %t", $time);
        
        // 等待足夠時間
        #5000000;
        
        $display("\n[TEST] Simulation finished at time %t", $time);
        $finish;
    end
    
    // 監控PC和指令
    reg [31:0] last_pc = 32'hFFFFFFFF;
    always @(posedge clk) begin
        if (rst_n && u_core.pc !== last_pc) begin
            $display("[PC_TRACE] Time: %t, PC: %h, Inst: %h", 
                     $time, u_core.pc, u_core.if_inst);
            last_pc <= u_core.pc;
        end
    end
    
    // 監控store指令
    always @(posedge clk) begin
        if (rst_n && u_core.mem_mem_wen) begin
            $display("[STORE] Time: %t, Addr: %h, Data: %h", 
                     $time, u_core.mem_alu_result, u_core.mem_rs2_data);
        end
    end
    
    // 監控UART寫入
    always @(posedge clk) begin
        if (rst_n && u_core.mem_mem_wen && u_core.mem_alu_result == 32'h10000000) begin
            $display("[UART_WRITE] Time: %t, Data: %h, Char: %c", 
                     $time, u_core.mem_rs2_data[7:0],
                     (u_core.mem_rs2_data[7:0] >= 32 && u_core.mem_rs2_data[7:0] < 127) ? 
                     u_core.mem_rs2_data[7:0] : ".");
        end
    end
endmodule