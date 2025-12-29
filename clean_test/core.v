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

    // 1. 添加 CSR 相關信號
    wire is_csr, is_system, csr_use_imm;
    wire [1:0] csr_op_type;
    wire [11:0] csr_addr;
    wire [31:0] csr_rdata, csr_wdata;
    wire csr_we;
    wire [31:0] mtvec, mepc;
    wire mie, timer_int, ext_int;
    wire id_is_csr;
    wire [1:0] id_csr_op;
    wire id_csr_use_imm;
    wire [11:0] id_csr_addr;

        // 4. 定義例外相關信號
    wire exc_taken = (is_system && (id_inst == 32'h00000073)) ||  // ECALL
                    (is_system && (id_inst == 32'h00100073));    // EBREAK

    wire mret_taken = (is_system && (id_inst == 32'h30200073));   // MRET

    reg [3:0] exc_cause;
    reg [31:0] exc_tval;        

    // ID/EX 流水線寄存器中的 CSR 相關信號
    reg ex_is_csr, ex_is_system;
    reg [1:0] ex_csr_op;
    reg ex_csr_use_imm;
    reg [11:0] ex_csr_addr;
    reg [31:0] mem_csr_wdata;  // 新增：在MEM階段保存CSR寫入數據

    // EX/MEM 流水線寄存器中的 CSR 相關信號
    reg mem_is_csr, mem_is_system;
    reg [1:0] mem_csr_op;
    reg mem_csr_use_imm;
    reg [11:0] mem_csr_addr;

    // MEM/WB 流水線寄存器中的 CSR 相關信號
    reg wb_is_csr, wb_is_system;
    reg [1:0] wb_csr_op;
    reg wb_csr_use_imm;
    reg [11:0] wb_csr_addr;    

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

        if (id_is_branch) begin
            $display("[ID-DETAIL] PC=%08h, inst=%08h, opcode=%07b, funct3=%03b", 
                    id_pc, id_inst, id_inst[6:0], id_funct3);
            $display("[ID-DETAIL] rs1_addr=x%d, rs2_addr=x%d, imm=%08h", 
                    id_rs1_addr, id_rs2_addr, id_imm);

            $display("[ID] 分支指令: PC=%08h, inst=%08h, rs1=x%d, rs2=x%d", 
                    id_pc, id_inst, id_rs1_addr, id_rs2_addr);
            $display("[ID] 寄存器值: x%d=%08h, x%d=%08h", 
                    id_rs1_addr, id_rdata1, id_rs2_addr, id_rdata2);
        end        
    end

    decoder u_decoder (
        .inst(id_inst), .rs1_addr(id_rs1_addr), .rs2_addr(id_rs2_addr), .rd_addr(id_rd_addr),
        .reg_wen(id_reg_wen), .is_store(id_is_store), .is_load(id_is_load), 
        .is_jal(id_is_jal), .is_jalr(id_is_jalr), .funct3(id_funct3), 
        .alu_op(id_alu_op), .alu_src_b(id_alu_src_b), .imm(id_imm), .is_lui(id_is_lui), .is_auipc(id_is_auipc),
        .is_branch(id_is_branch), .is_m_ext_o(id_is_m_ext),
        // 🏆 新增 CSR 輸出
        .is_csr(is_csr),
        .is_system(is_system),
        .csr_op_type(csr_op_type),
        .csr_use_imm(csr_use_imm),
        .csr_addr(csr_addr)
    );

    assign id_is_csr = is_csr;
    assign id_csr_op = csr_op_type;
    assign id_csr_use_imm = csr_use_imm;
    assign id_csr_addr = csr_addr;   

    csr_registers u_csr (
        .clk(clk),
        .rst_n(rst_n),
        
        // CSR 存取接口
        .csr_addr(mem_csr_addr),
        .csr_wdata(csr_wdata),
        .csr_we(csr_we),
        .csr_op(mem_csr_op),
        .csr_use_imm(mem_csr_use_imm),
        
        // 例外和中斷處理
        .pc(ex_pc),          // 使用 EX 階段的 PC
        .exc_cause(exc_cause),    // 暫時設為0，後續完善
        .exc_tval(exc_tval),    // 暫時設為0
        .mret_taken(mret_taken),
        
        // 輸出
        .csr_rdata(csr_rdata),
        .mtvec(mtvec),
        .mepc(mepc),
        .mie(mie),
        .timer_int(timer_int),
        .ext_int(ext_int)
    );    

    // 5. 處理例外原因
    always @(*) begin
        if (is_system) begin
            case (id_inst)
                32'h00000073: begin  // ECALL
                    exc_cause = 4'hB;  // 環境調用
                    exc_tval = 32'h0;
                end
                32'h00100073: begin  // EBREAK
                    exc_cause = 4'h3;  // 斷點
                    exc_tval = 32'h0;
                end
                default: begin
                    exc_cause = 4'h2;  // 非法指令
                    exc_tval = id_inst;
                end
            endcase
        end else begin
            exc_cause = 4'h0;
            exc_tval = 32'h0;
        end
    end    

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
            ex_is_csr <= 1'b0;
            ex_is_system <= 1'b0;
            ex_csr_op <= 2'b0;
            ex_csr_use_imm <= 1'b0;
            ex_csr_addr <= 12'b0;            
        end else begin
            ex_pc <= id_pc; ex_imm <= id_imm; ex_rd_addr <= id_rd_addr;
            ex_rs1_addr <= id_rs1_addr; ex_rs2_addr <= id_rs2_addr;
            ex_funct3 <= id_funct3; ex_alu_op <= id_alu_op; ex_alu_src_b <= id_alu_src_b;
            ex_mem_wen <= id_is_store; ex_reg_wen <= id_reg_wen; ex_is_load <= id_is_load;
            ex_is_jal <= id_is_jal; ex_is_jalr <= id_is_jalr; ex_is_branch <= id_is_branch;
            ex_is_lui <= id_is_lui; ex_is_auipc <= id_is_auipc; ex_rdata1 <= id_rdata1; ex_rdata2 <= id_rdata2;
            ex_is_csr <= id_is_csr;
            ex_is_system <= is_system;
            ex_csr_op <= id_csr_op;
            ex_csr_use_imm <= id_csr_use_imm;
            ex_csr_addr <= id_csr_addr; 

            if (ex_is_branch) begin
                $display("[BRANCH-FIXED] ex_is_branch=%b, branch_met=%b, ex_take_branch=%b", 
                        ex_is_branch, branch_met, ex_take_branch);
            end            

            if (ex_is_branch || (ex_alu_zero && ex_funct3 == 3'b000)) begin
                $display("[BRANCH-DEBUG] ex_is_branch=%b, branch_met=%b, ex_take_branch=%b", 
                        ex_is_branch, branch_met, ex_take_branch);
                $display("[BRANCH-DEBUG] ex_funct3=%b, ex_alu_zero=%b, ex_alu_less=%b",
                        ex_funct3, ex_alu_zero, ex_alu_less);
            end            

            $display("[EX-DETAIL] 比較 x%d(=%08h) vs x%d(=%08h)", 
                    ex_rs1_addr, fwd_rs1, ex_rs2_addr, fwd_rs2);
            $display("[EX-DETAIL] ALU zero=%b, less=%b, 跳轉=%b, 目標PC=%08h", 
                    ex_alu_zero, ex_alu_less, ex_take_branch, ex_target_pc);            

            if (ex_is_branch) begin
                $display("[EX-BRANCH] PC=%08h, funct3=%b, alu_zero=%b, alu_less=%b, take_branch=%b", 
                        ex_pc, ex_funct3, ex_alu_zero, ex_alu_less, ex_take_branch);
                $display("[EX-BRANCH] x1=%08h, x2=%08h, alu_in_a=%08h, alu_in_b=%08h", 
                        fwd_rs1, fwd_rs2, alu_in_a_final, ex_alu_in_b);
            end
            if (ex_is_branch) begin
                $display("[EX] 分支執行: PC=%08h, 前推rs1=%08h, 前推rs2=%08h", 
                        ex_pc, fwd_rs1, fwd_rs2);
                $display("[EX] 比較結果: zero=%b, less=%b, 跳轉=%b", 
                        ex_alu_zero, ex_alu_less, ex_take_branch);
            end            
/*               
            if (is_csr) begin
                $display("[CORE-DEBUG] ID stage: CSR instruction detected!");
                $display("  csr_addr = 0x%h, csr_op_type = %b, csr_use_imm = %b", 
                        csr_addr, csr_op_type, csr_use_imm);
                $display("  id_rs1_addr = %d, id_rd_addr = %d", 
                        id_rs1_addr, id_rd_addr);
            end  
*/                           
        end
    end
/*
    always @(posedge clk) begin
        if (ex_is_csr) begin
            $display("[CORE-DEBUG] EX stage: Processing CSR instruction");
            $display("  ex_csr_addr = 0x%h, csr_wdata = 0x%h, csr_we = %b", 
                    ex_csr_addr, csr_wdata, csr_we);
        end
    end    
*/
    // 計算 MEM 階段的寫回數據（用於前推）\\
    wire [31:0] mem_stage_data =   (mem_is_load) ? mem_final_rdata :
                                (mem_is_jal_jalr) ? mem_pc_plus_4 :
                                (mem_is_csr) ? csr_rdata :  // CSR 讀取數據\\
                                mem_alu_result;             // ALU 結果\\    

    // Forwarding
    wire [31:0] fwd_rs1 = (mem_reg_wen && mem_rd_addr != 0 && mem_rd_addr == ex_rs1_addr) ? mem_stage_data  :
                         (wb_reg_wen  && wb_rd_addr  != 0 && wb_rd_addr  == ex_rs1_addr) ? wb_write_data : ex_rdata1;
    wire [31:0] fwd_rs2 = (mem_reg_wen && mem_rd_addr != 0 && mem_rd_addr == ex_rs2_addr) ? mem_stage_data  :
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
            mem_is_csr <= 1'b0;
            mem_is_system <= 1'b0;
            mem_csr_op <= 2'b0;
            mem_csr_use_imm <= 1'b0;
            mem_csr_addr <= 12'b0;            
        end else begin
            mem_alu_result <= ex_alu_result;
            mem_rs2_data <= rs2_data_final;
            mem_rd_addr <= ex_rd_addr; mem_pc_plus_4 <= ex_pc + 4;
            mem_mem_wen <= ex_mem_wen; mem_reg_wen <= ex_reg_wen; mem_is_load <= ex_is_load;
            mem_is_jal_jalr <= (ex_is_jal || ex_is_jalr); mem_funct3 <= ex_funct3;
            mem_is_csr <= ex_is_csr;
            mem_is_system <= ex_is_system;
            mem_csr_op <= ex_csr_op;
            mem_csr_wdata <= (ex_csr_use_imm) ? ex_imm : fwd_rs1;
            mem_csr_use_imm <= ex_csr_use_imm;
            mem_csr_addr <= ex_csr_addr;            
        end
    end
/*
    always @(posedge clk) begin
        if (mem_is_csr) begin
            $display("[CORE-DEBUG] MEM stage: CSR access");
            $display("  mem_csr_addr = 0x%h, csr_rdata = 0x%h", 
                    mem_csr_addr, csr_rdata);
        end
    end    
*/
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
            wb_is_csr <= 1'b0;
            wb_is_system <= 1'b0;
            wb_csr_op <= 2'b0;
            wb_csr_use_imm <= 1'b0;
            wb_csr_addr <= 12'b0;            
        end else begin
            wb_ram_rdata <= mem_final_rdata; wb_alu_result <= mem_alu_result; 
            wb_rd_addr <= mem_rd_addr; wb_pc_plus_4 <= mem_pc_plus_4;
            wb_reg_wen <= mem_reg_wen; wb_is_load <= mem_is_load;
            wb_is_jal_jalr <= mem_is_jal_jalr; 
            wb_is_csr <= mem_is_csr;
            wb_is_system <= mem_is_system;
            wb_csr_op <= mem_csr_op;
            wb_csr_use_imm <= mem_csr_use_imm;
            wb_csr_addr <= mem_csr_addr;            
        end
    end

    wire [31:0] csr_rdata_forwarded = (mem_is_csr && csr_we && mem_csr_addr == wb_csr_addr) ? csr_wdata : csr_rdata;

    assign wb_write_data = (wb_is_jal_jalr) ? wb_pc_plus_4 : 
                        (wb_is_load) ? wb_ram_rdata : 
                        (wb_is_csr) ? csr_rdata_forwarded :  // 使用前推後的 CSR 數據
                        wb_alu_result;

    // 5. CSR 寫入數據選擇
    assign csr_wdata = mem_csr_wdata;
    // CSR寫使能邏輯修正
    // CSRRW/CSRRWI (op=00): 總是寫入
    // CSRRS/CSRRSI (op=01): 當rs1/imm != 0時寫入
    // CSRRC/CSRRCI (op=10): 當rs1/imm != 0時寫入
    wire csr_write_always = (mem_csr_op == 2'b00);
    wire csr_write_set    = (mem_csr_op == 2'b01) && (|csr_wdata);
    wire csr_write_clear  = (mem_csr_op == 2'b10) && (|csr_wdata);
    
    assign csr_we = mem_is_csr && (csr_write_always || csr_write_set || csr_write_clear);

/*
    always @(posedge clk) begin
        // 追蹤 CSR 讀取指令的數據流
        if (mem_is_csr && mem_reg_wen) begin
            $display("[CSR-DATAFLOW] MEM: CSR[0x%h] = 0x%h -> x%0d", 
                    mem_csr_addr, csr_rdata, mem_rd_addr);
        end
        
        if (wb_is_csr && wb_reg_wen) begin
            $display("[CSR-DATAFLOW] WB: Writing x%0d = 0x%h (from CSR)", 
                    wb_rd_addr, wb_write_data);
        end
        
        // 追蹤分支指令的數據
        if (ex_is_branch && ex_rs1_addr == 11 && ex_rs2_addr == 12) begin
            $display("[BRANCH-DATA] Comparing: x11=0x%h vs x12=0x%h, zero=%b, taken=%b",
                    fwd_rs1, fwd_rs2, ex_alu_zero, ex_take_branch);
            $display("  MEM stage: rd_addr=%d, reg_wen=%b, is_csr=%b",
                    mem_rd_addr, mem_reg_wen, mem_is_csr);
            $display("  WB stage: rd_addr=%d, reg_wen=%b, is_csr=%b",
                    wb_rd_addr, wb_reg_wen, wb_is_csr);
        end
        
        // 追蹤前推情況
        if (ex_is_csr || (ex_is_branch && (ex_rs1_addr == 11 || ex_rs2_addr == 12))) begin
            if (mem_reg_wen && mem_rd_addr != 0 && (mem_rd_addr == ex_rs1_addr || mem_rd_addr == ex_rs2_addr)) begin
                $display("[FWD-DEBUG] MEM->EX: x%0d = 0x%h, is_csr=%b",
                        mem_rd_addr, mem_stage_data, mem_is_csr);
            end
            if (wb_reg_wen && wb_rd_addr != 0 && (wb_rd_addr == ex_rs1_addr || wb_rd_addr == ex_rs2_addr)) begin
                $display("[FWD-DEBUG] WB->EX: x%0d = 0x%h, is_csr=%b",
                        wb_rd_addr, wb_write_data, wb_is_csr);
            end
        end
    end
*/
endmodule