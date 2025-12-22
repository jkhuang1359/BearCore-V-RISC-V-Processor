module rom (
    input [31:0] addr,
    output [31:0] inst,
    input [31:0] data_addr,     // 數據讀取地址
    output [31:0] data_out      // 數據讀取輸出    
);
    reg [31:0] mem [0:16383];
    assign inst = mem[addr >> 2];

    assign data_out = mem[data_addr >> 2];


    integer i; // 🏆 確保在 initial 之外

    initial begin
        for (i = 0; i < 16384; i = i + 1) begin
            mem[i] = 32'h0;
        end
        $readmemh("firmware.hex", mem);
        
        // 🏆 這裡就是第 24 行附近，確保括號都有對齊
        $display("[ROM DEBUG] Addr 0: %h", mem[0]);
    end
endmodule