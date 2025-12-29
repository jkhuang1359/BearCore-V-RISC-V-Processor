`timescale 1ns/1ps

module test_rom;
    reg [31:0] addr = 0;
    wire [31:0] inst;
    
    rom u_rom (
        .addr(addr),
        .inst(inst),
        .data_addr(0),
        .data_out()
    );
    
    integer i;
    
    initial begin
        $display("ROM測試開始");
        $display("地址    指令");
        $display("-------- --------");
        
        for (i = 0; i < 6; i = i + 1) begin
            #10;
            $display("0x%08h 0x%08h", addr, inst);
            addr = addr + 4;
        end
        
        if (inst === 32'h0000006f) begin
            $display("✅ ROM讀取成功！");
        end else begin
            $display("❌ ROM讀取失敗！");
        end
        
        $finish;
    end
endmodule
