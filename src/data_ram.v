`timescale 1ns/1ps  // <--- 🐻 關鍵修正：定義時間單位！

module data_ram (
    input wire clk,             // 🆕 必須有時脈
    input wire wen,             // 寫入致能
    input wire [31:0] addr,     // 位址
    input wire [31:0] wdata,    // 寫入資料
    input wire [2:0]  funct3,   // 用來決定寫入寬度
    output reg [31:0] rdata     // 讀取資料 (會延遲一個 Cycle 輸出)
);

    // 定義記憶體大小 (16KB = 4096 Words)
    parameter DEPTH = 16384; 
    
    // 🏆 強制使用 Block RAM
    (* ram_style = "block" *)
    reg [31:0] mem [0:DEPTH-1];

    // 計算 Word 位址 (忽略低 2 位)
    wire [31:0] word_addr = addr >> 2;
    wire [1:0]  byte_offset = addr[1:0];

    // 產生 Byte Write Enable (bwe)
    reg [3:0] bwe;
    always @(*) begin
        if (!wen) bwe = 4'b0000;
        else begin
            case (funct3)
                3'b000: bwe = 4'b0001 << byte_offset; // SB
                3'b001: bwe = 4'b0011 << byte_offset; // SH
                3'b010: bwe = 4'b1111;                // SW
                default: bwe = 4'b0000;
            endcase
        end
    end

    // BRAM 核心行為 (同步寫入 + 同步讀取)
    reg [31:0] ram_out_raw;
    reg [2:0]  funct3_q;    // 延遲的 funct3 (給讀取格式化用)
    reg [1:0]  addr_low_q;  // 延遲的位址低位

    always @(posedge clk) begin
        // (A) 同步寫入
        if (bwe[0]) mem[word_addr][7:0]   <= wdata[7:0];
        if (bwe[1]) mem[word_addr][15:8]  <= wdata[15:8];
        if (bwe[2]) mem[word_addr][23:16] <= wdata[23:16];
        if (bwe[3]) mem[word_addr][31:24] <= wdata[31:24];

        // (B) 同步讀取 (Registered Read)
        ram_out_raw <= mem[word_addr];
        
        // 紀錄讀取當下的格式資訊，以便下個 Cycle 輸出時使用
        funct3_q    <= funct3;
        addr_low_q  <= byte_offset;
    end

    // 讀取資料後處理 (根據 funct3 做 Sign Extension)
    always @(*) begin
        case (funct3_q)
            3'b000: begin // LB
                case (addr_low_q)
                    2'b00: rdata = {{24{ram_out_raw[7]}},  ram_out_raw[7:0]};
                    2'b01: rdata = {{24{ram_out_raw[15]}}, ram_out_raw[15:8]};
                    2'b10: rdata = {{24{ram_out_raw[23]}}, ram_out_raw[23:16]};
                    2'b11: rdata = {{24{ram_out_raw[31]}}, ram_out_raw[31:24]};
                endcase
            end
            3'b001: begin // LH
                case (addr_low_q[1])
                    1'b0: rdata = {{16{ram_out_raw[15]}}, ram_out_raw[15:0]};
                    1'b1: rdata = {{16{ram_out_raw[31]}}, ram_out_raw[31:16]};
                endcase
            end
            3'b010: rdata = ram_out_raw; // LW
            3'b100: begin // LBU
                case (addr_low_q)
                    2'b00: rdata = {24'b0, ram_out_raw[7:0]};
                    2'b01: rdata = {24'b0, ram_out_raw[15:8]};
                    2'b10: rdata = {24'b0, ram_out_raw[23:16]};
                    2'b11: rdata = {24'b0, ram_out_raw[31:24]};
                endcase
            end
            3'b101: begin // LHU
                case (addr_low_q[1])
                    1'b0: rdata = {16'b0, ram_out_raw[15:0]};
                    1'b1: rdata = {16'b0, ram_out_raw[31:16]};
                endcase
            end
            default: rdata = ram_out_raw;
        endcase
    end
endmodule