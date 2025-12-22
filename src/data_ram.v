module data_ram(
    input clk,
    input wen,
    input [31:0] addr,
    input [31:0] wdata,
    input [2:0] funct3, // 🏆 新增：操作類型
    output [31:0] rdata
);
    reg [31:0] memory [0:16383];
    
    wire [13:0] word_addr = addr[15:2];
    wire [1:0] byte_sel = addr[1:0];
    
    // 🏆 讀取邏輯：根據 funct3 和偏移量選擇正確的數據
    reg [31:0] read_data;
    always @(*) begin
        case (funct3)
            3'b000: begin // LB (Signed byte)
                case (byte_sel)
                    2'b00: read_data = {{24{memory[word_addr][7]}},  memory[word_addr][7:0]};
                    2'b01: read_data = {{24{memory[word_addr][15]}}, memory[word_addr][15:8]};
                    2'b10: read_data = {{24{memory[word_addr][23]}}, memory[word_addr][23:16]};
                    2'b11: read_data = {{24{memory[word_addr][31]}}, memory[word_addr][31:24]};
                endcase
            end
            3'b001: begin // LH (Signed halfword)
                case (byte_sel[1])
                    1'b0: read_data = {{16{memory[word_addr][15]}}, memory[word_addr][15:0]};
                    1'b1: read_data = {{16{memory[word_addr][31]}}, memory[word_addr][31:16]};
                endcase
            end
            3'b010: begin // LW
                read_data = memory[word_addr];
            end
            3'b100: begin // LBU (Unsigned byte)
                case (byte_sel)
                    2'b00: read_data = {24'b0, memory[word_addr][7:0]};
                    2'b01: read_data = {24'b0, memory[word_addr][15:8]};
                    2'b10: read_data = {24'b0, memory[word_addr][23:16]};
                    2'b11: read_data = {24'b0, memory[word_addr][31:24]};
                endcase
            end
            3'b101: begin // LHU (Unsigned halfword)
                case (byte_sel[1])
                    1'b0: read_data = {16'b0, memory[word_addr][15:0]};
                    1'b1: read_data = {16'b0, memory[word_addr][31:16]};
                endcase
            end
            default: read_data = memory[word_addr];
        endcase
    end
    
    assign rdata = read_data;

    // 🏆 寫入邏輯：根據 funct3 和偏移量寫入
    always @(posedge clk) begin
        if (wen) begin
            case (funct3)
                3'b000, 3'b100: begin // SB
                    case (byte_sel)
                        2'b00: memory[word_addr][7:0]   <= wdata[7:0];
                        2'b01: memory[word_addr][15:8]  <= wdata[7:0];
                        2'b10: memory[word_addr][23:16] <= wdata[7:0];
                        2'b11: memory[word_addr][31:24] <= wdata[7:0];
                    endcase
                end
                3'b001, 3'b101: begin // SH
                    case (byte_sel[1])
                        1'b0: memory[word_addr][15:0]  <= wdata[15:0];
                        1'b1: memory[word_addr][31:16] <= wdata[15:0];
                    endcase
                end
                3'b010: begin // SW
                    memory[word_addr] <= wdata;
                end
                // 其他情況不寫入
            endcase
        end
    end

    integer i;
    initial begin
        for (i = 0; i < 16384; i = i + 1) memory[i] = 32'h0;
    end
endmodule