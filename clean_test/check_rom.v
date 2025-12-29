`timescale 1ns/1ps

module check_rom;
    reg [31:0] addr = 0;
    wire [31:0] inst;
    
    rom u_rom (.addr(addr), .inst(inst), .data_addr(0), .data_out());
    
    integer i;
    
    initial begin
        $display("检查ROM内容：");
        for (i = 0; i < 32; i = i + 1) begin
            #10;
            $display("地址 0x%08h: 指令 0x%08h", addr, inst);
            addr = addr + 4;
        end
        $finish;
    end
endmodule
