`timescale 1ns/1ps

module rom_test;
    reg [31:0] addr;
    wire [31:0] inst;
    
    // 實例化 ROM
    simple_rom u_rom(.addr(addr), .inst(inst));
    
    initial begin
        $display("ROM 測試:");
        
        addr = 32'h0;
        #10;
        $display("  addr=0x%08h, inst=0x%08h", addr, inst);
        
        addr = 32'h4;
        #10;
        $display("  addr=0x%08h, inst=0x%08h", addr, inst);
        
        $finish;
    end
endmodule
