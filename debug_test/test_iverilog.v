`timescale 1ns/1ps

module test_iverilog;
    reg clk;
    
    initial begin
        $display("Icarus Verilog 工作正常!");
        clk = 0;
        #10;
        $display("時間推進測試通過");
        $finish;
    end
endmodule
