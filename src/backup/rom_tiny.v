module rom_tiny(
    input [31:0] addr,
    output reg [31:0] inst
);
    always @(*) begin
        case (addr)
            32'h0: inst = 32'h100002b7;  // lui t0, 0x10000
            32'h4: inst = 32'h02100313;  // li t1, 33 ('!')
            32'h8: inst = 32'h0062a023;  // sw t1, 0(t0)
            32'hc: inst = 32'h0000006f;  // j .
            default: inst = 32'h00000013; // nop
        endcase
    end
    
    initial begin
        $display("[ROM_TINY] 初始化完成");
    end
endmodule
