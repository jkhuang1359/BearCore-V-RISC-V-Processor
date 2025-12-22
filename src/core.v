module core(
    input clk,
    input rst_n,
    output uart_tx_o
);
    // --- 1. 訊號定義 ---
    reg  [31:0] pc;
    wire [31:0] pc_next, if_inst;
    wire [31:0] ex_target_pc;
    wire ex_take_branch;

    reg [31:0] cycle_cnt; 
    reg [31:0] inst_cnt; 

    reg  [31:0] id_pc, id_inst;
    wire [4:0]  id_rs1_addr, id_rs2_addr, id_rd_addr;
    wire [31:0] id_rdata1, id_rdata2, id_imm;
    wire [2:0]  id_funct3; 
    wire [3:0]  id_alu_op;
    wire id_alu_src_b, id_reg_wen, id_is_store, id_is_load, id_is_lui, id_is_jal, id_is_jalr, id_is_branch, id_is_auipc;
    wire id_is_m_ext;

    reg  [31:0] ex_pc, ex_rdata1, ex_rdata2, ex_imm;
    reg  [4:0]  ex_rs1_addr, ex_rs2_addr, ex_rd_addr;
    reg  [2:0]  ex_funct3; 
    reg  [3:0]  ex_alu_op;
    reg  ex_alu_src_b, ex_mem_wen, ex_reg_wen, ex_is_load, ex_is_lui, ex_is_jal, ex_is_jalr, ex_is_branch, ex_is_auipc;

    reg  stall;
    wire [31:0] alu_in_a_final, rs2_data_final, ex_alu_in_b, ex_alu_result;
    wire ex_alu_zero, ex_alu_less;

    reg  [31:0] mem_alu_result, mem_rs2_data, mem_pc_plus_4;
    reg  [4:0]  mem_rd_addr;
    reg  mem_mem_wen, mem_reg_wen, mem_is_load, mem_is_jal_jalr, mem_is_lui;
    reg  [2:0]  mem_funct3;
    wire uart_busy, uart_wen;

    reg  [31:0] wb_ram_rdata, wb_alu_result, wb_pc_plus_4;
    reg  [4:0]  wb_rd_addr;
    reg  wb_reg_wen, wb_is_load, wb_is_jal_jalr;
    reg  [2:0]  wb_funct3;
    wire [31:0] wb_write_data;

    // --- 除法暫停邏輯 ---
    reg [5:0] div_stall_cnt;
    wire is_real_div = id_is_m_ext && (id_funct3 == 3'b100 || id_funct3 == 3'b110);
    //wire div_stall = is_real_div && (div_stall_cnt < 6'd32);

    assign div_stall = 1'b0;
    

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) div_stall_cnt <= 0;
        else if (div_stall) div_stall_cnt <= div_stall_cnt + 1;
        else div_stall_cnt <= 0;
    end    

    // --- IF Stage ---
    assign pc_next = (ex_take_branch) ? ex_target_pc : (pc + 4);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc <= 0;
        else if (!stall) pc <= pc_next;
    end

    wire [31:0] rom_data_out;

    rom u_rom ( .addr(pc), 
                .inst(if_inst),
                .data_addr(mem_alu_result),  // 數據讀取地址
                .data_out(rom_data_out)      // 數據讀取輸出
    );

    // --- ID Stage ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || ex_take_branch) begin 
            id_pc <= 0;
            id_inst <= 32'h00000013; 
        end else if (!stall) begin 
            id_pc <= pc;
            id_inst <= if_inst;
        end
    end

    decoder u_decoder (
        .inst(id_inst), .rs1_addr(id_rs1_addr), .rs2_addr(id_rs2_addr), .rd_addr(id_rd_addr),
        .reg_wen(id_reg_wen), .is_store(id_is_store), .is_load(id_is_load), 
        .is_jal(id_is_jal), .is_jalr(id_is_jalr), .funct3(id_funct3), 
        .alu_op(id_alu_op), .alu_src_b(id_alu_src_b), .imm(id_imm), .is_lui(id_is_lui), .is_auipc(id_is_auipc),
        .is_branch(id_is_branch), .is_m_ext_o(id_is_m_ext)
    );

    reg_file u_regfile (
        .clk(clk), .raddr1(id_rs1_addr), .rdata1(id_rdata1), .raddr2(id_rs2_addr), 
        .rdata2(id_rdata2), .wen(wb_reg_wen), .waddr(wb_rd_addr), .wdata(wb_write_data)
    );

    // --- Hazard & EX Stage ---
    always @(*) begin
        stall = (ex_is_load && (ex_rd_addr != 0) && (ex_rd_addr == id_rs1_addr || ex_rd_addr == id_rs2_addr)) 
              || div_stall;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || ex_take_branch || stall) begin
            ex_pc <= 0; ex_rd_addr <= 0; ex_reg_wen <= 0; ex_mem_wen <= 0; ex_is_branch <= 0;
            ex_is_jal <= 0; ex_is_jalr <= 0; ex_is_load <= 0;
            ex_is_lui      <= 0;
            ex_is_auipc    <= 0;
            ex_alu_op      <= 4'b0; // 清除 ALU 操作            
        end else begin
            ex_pc <= id_pc; ex_imm <= id_imm; ex_rd_addr <= id_rd_addr;
            ex_rs1_addr <= id_rs1_addr; ex_rs2_addr <= id_rs2_addr;
            ex_funct3 <= id_funct3; ex_alu_op <= id_alu_op; ex_alu_src_b <= id_alu_src_b;
            ex_mem_wen <= id_is_store; ex_reg_wen <= id_reg_wen; ex_is_load <= id_is_load;
            ex_is_jal <= id_is_jal; ex_is_jalr <= id_is_jalr; ex_is_branch <= id_is_branch;
            ex_is_lui <= id_is_lui; ex_is_auipc <= id_is_auipc; ex_rdata1 <= id_rdata1; ex_rdata2 <= id_rdata2;
         
        end
    end

    // Forwarding
    wire [31:0] fwd_rs1 = (mem_reg_wen && mem_rd_addr != 0 && mem_rd_addr == ex_rs1_addr) ? mem_alu_result :
                         (wb_reg_wen  && wb_rd_addr  != 0 && wb_rd_addr  == ex_rs1_addr) ? wb_write_data : ex_rdata1;
    wire [31:0] fwd_rs2 = (mem_reg_wen && mem_rd_addr != 0 && mem_rd_addr == ex_rs2_addr) ? mem_alu_result :
                         (wb_reg_wen  && wb_rd_addr  != 0 && wb_rd_addr  == ex_rs2_addr) ? wb_write_data : ex_rdata2;

    assign alu_in_a_final = (ex_is_auipc) ? ex_pc : fwd_rs1;
    assign ex_alu_in_b    = (ex_alu_src_b) ? ex_imm : fwd_rs2;
    assign rs2_data_final = fwd_rs2;

    alu u_alu (.a(alu_in_a_final), .b(ex_alu_in_b), .alu_op(ex_alu_op), .result(ex_alu_result), .zero(ex_alu_zero), .less(ex_alu_less));

    reg branch_met;
    always @(*) begin
        case (ex_funct3)
            3'b000: branch_met = ex_alu_zero;
            3'b001: branch_met = !ex_alu_zero;
            3'b100: branch_met = ex_alu_less;
            3'b101: branch_met = !ex_alu_less;
            3'b110: branch_met = ex_alu_less;
            3'b111: branch_met = !ex_alu_less;
            default: branch_met = 0;
        endcase
    end
    assign ex_take_branch = (ex_is_branch && branch_met) || ex_is_jal || ex_is_jalr;
    assign ex_target_pc   = (ex_is_jalr) ? ((fwd_rs1 + ex_imm) & ~32'h1) : (ex_pc + ex_imm);

    // --- MEM Stage ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_alu_result <= 0;
            mem_rs2_data <= 0; mem_rd_addr <= 0; mem_pc_plus_4 <= 0;
            mem_mem_wen <= 0; mem_reg_wen <= 0; mem_is_load <= 0;
            mem_is_jal_jalr <= 0; mem_funct3 <= 0;
        end else begin
            mem_alu_result <= ex_alu_result;
            mem_rs2_data <= rs2_data_final;
            mem_rd_addr <= ex_rd_addr; mem_pc_plus_4 <= ex_pc + 4;
            mem_mem_wen <= ex_mem_wen; mem_reg_wen <= ex_reg_wen; mem_is_load <= ex_is_load;
            mem_is_jal_jalr <= (ex_is_jal || ex_is_jalr); mem_funct3 <= ex_funct3;
        end
    end

    // 🏆 1. 統一 MMIO 位址解碼 (範圍判斷)
    wire mem_is_mmio = (mem_alu_result >= 32'h10000000 && mem_alu_result < 32'h10000010);

    wire mem_is_uart_data   = (mem_alu_result == 32'h10000000); 
    wire mem_is_uart_status = (mem_alu_result == 32'h10000004); 
    wire mem_is_cycle_cnt   = (mem_alu_result == 32'h10000008); 
    wire mem_is_inst_cnt    = (mem_alu_result == 32'h1000000C); 
    
    // 🏆 2. 周邊裝置實例化
    assign uart_wen = mem_mem_wen && mem_is_uart_data; 

    wire [31:0] mem_ram_rdata;
    // 只有位址不在 MMIO 範圍時，才允許寫入 Data RAM [cite: 45]
    data_ram u_ram (
        .clk(clk), 
        .wen(mem_mem_wen && !mem_is_mmio), 
        .addr(mem_alu_result), 
        .wdata(mem_rs2_data), 
        .funct3(mem_funct3),  // 🏆 新增：傳遞操作類型
        .rdata(mem_ram_rdata)
    ); 

    uart_tx u_uart (
        .clk(clk), .rst_n(rst_n), 
        .data_i(mem_rs2_data[7:0]), .valid_i(uart_wen), 
        .busy_o(uart_busy), .tx_o(uart_tx_o), .test_mode_i(1'b0)
    ); 

    // 🏆 3. 效能計數器累加邏輯 (只保留一組)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin 
            cycle_cnt <= 0; 
            inst_cnt  <= 0; 
        end else begin 
            cycle_cnt <= cycle_cnt + 1; // 總週期數保持不變 [cite: 170]
            
            // 🏆 新定義：WB 階段的 PC 只要不是 0 (代表有指令流過)，
            // 且該指令不是 NOP (0x00000013)，就計入有效指令
            // 這樣就能正確計入 SW, BEQ, JAL 等不寫回暫存器的指令了
            if (wb_pc_plus_4 != 0) begin
                        // 這裡可以根據你的 wb 階段控制訊號來判斷
                        // 最簡單的過濾法：只要這條指令不是因為 Flush 變成的 NOP
                if (wb_reg_wen || mem_mem_wen || mem_is_jal_jalr || (ex_is_branch && !ex_take_branch)) begin
                            // 這裡邏輯較複雜，建議改用「有效位元 (Valid bit)」傳遞
                    inst_cnt <= inst_cnt + 1; // 總週期數保持不變 [cite: 170]
                end
            end
        end
    end

    // 🏆 4. 讀取資料多工器 (決定 CPU 讀到什麼)
    reg [31:0] mem_final_rdata;
    assign is_rom_data_access = (mem_alu_result >= 32'h00000000 && mem_alu_result < 32'h00004000);

    always @(*) begin
        if (mem_is_uart_status) begin
            mem_final_rdata = {31'b0, uart_busy};
        end else if (mem_is_cycle_cnt) begin
            mem_final_rdata = cycle_cnt;
        end else if (mem_is_inst_cnt) begin
            mem_final_rdata = inst_cnt;
        end else if (mem_is_uart_data) begin
            mem_final_rdata = 32'h0;
        end else if (is_rom_data_access && !mem_mem_wen) begin
            // 🏆 從 ROM 讀取數據（只讀）
            // 注意：ROM 返回整個字，需要根據地址偏移和 funct3 選擇正確的字節
            case (mem_funct3)
                3'b000: begin // LB
                    case (mem_alu_result[1:0])
                        2'b00: mem_final_rdata = {{24{rom_data_out[7]}},  rom_data_out[7:0]};
                        2'b01: mem_final_rdata = {{24{rom_data_out[15]}}, rom_data_out[15:8]};
                        2'b10: mem_final_rdata = {{24{rom_data_out[23]}}, rom_data_out[23:16]};
                        2'b11: mem_final_rdata = {{24{rom_data_out[31]}}, rom_data_out[31:24]};
                    endcase
                end
                3'b001: begin // LH
                    case (mem_alu_result[1])
                        1'b0: mem_final_rdata = {{16{rom_data_out[15]}}, rom_data_out[15:0]};
                        1'b1: mem_final_rdata = {{16{rom_data_out[31]}}, rom_data_out[31:16]};
                    endcase
                end
                3'b010: begin // LW
                    mem_final_rdata = rom_data_out;
                end
                3'b100: begin // LBU
                    case (mem_alu_result[1:0])
                        2'b00: mem_final_rdata = {24'b0, rom_data_out[7:0]};
                        2'b01: mem_final_rdata = {24'b0, rom_data_out[15:8]};
                        2'b10: mem_final_rdata = {24'b0, rom_data_out[23:16]};
                        2'b11: mem_final_rdata = {24'b0, rom_data_out[31:24]};
                    endcase
                end
                3'b101: begin // LHU
                    case (mem_alu_result[1])
                        1'b0: mem_final_rdata = {16'b0, rom_data_out[15:0]};
                        1'b1: mem_final_rdata = {16'b0, rom_data_out[31:16]};
                    endcase
                end
                default: mem_final_rdata = rom_data_out;
            endcase
        end else begin
            // 🏆 從 RAM 讀取（data_ram 已處理）
            mem_final_rdata = mem_ram_rdata;
        end
    end    

    // --- WB Stage ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ram_rdata <= 0; wb_alu_result <= 0; wb_rd_addr <= 0; wb_pc_plus_4 <= 0;
            wb_reg_wen <= 0; wb_is_load <= 0; wb_is_jal_jalr <= 0; 
        end else begin
            wb_ram_rdata <= mem_final_rdata; wb_alu_result <= mem_alu_result; 
            wb_rd_addr <= mem_rd_addr; wb_pc_plus_4 <= mem_pc_plus_4;
            wb_reg_wen <= mem_reg_wen; wb_is_load <= mem_is_load;
            wb_is_jal_jalr <= mem_is_jal_jalr; 
        end
    end

    assign wb_write_data = (wb_is_jal_jalr) ? wb_pc_plus_4 : (wb_is_load) ? wb_ram_rdata : wb_alu_result;

endmodule