module core(
    input clk,
    input rst_n,
    input external_int,
    input software_int,      
    output uart_tx_o

    // 新增中斷輸入
  
);
    // --- 1. 訊號定義 ---
    reg  [31:0] pc;
    wire [31:0] pc_next, if_inst;
    wire [31:0] ex_target_pc;
    wire ex_take_branch;

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
    reg  [31:0] mem_inst;      // 🏆 新增：在 MEM 階段傳遞指令
    reg  [31:0] mem_pc;        // 🏆 新增：在 MEM 階段傳遞 PC
    
    wire uart_busy, uart_wen;

    reg  [31:0] wb_ram_rdata, wb_alu_result, wb_pc_plus_4;
    reg  [4:0]  wb_rd_addr;
    reg  wb_reg_wen, wb_is_load, wb_is_jal_jalr;
    reg  [2:0]  wb_funct3;
    reg  [31:0] wb_rs1_data;   // 🏆 新增：CSR 指令需要 rs1 數據
    wire [31:0] wb_write_data;

    // --- 除法暫停邏輯 ---
    reg [5:0] div_stall_cnt;
    wire is_real_div = id_is_m_ext && (id_funct3 == 3'b100 || id_funct3 == 3'b110);
    wire div_stall = is_real_div && (div_stall_cnt < 6'd32);

    // CSR 信號
    wire [31:0] csr_rdata;
    wire [11:0] csr_raddr;
    wire [11:0] csr_waddr;
    wire [31:0] csr_wdata;
    wire csr_wen;
    wire [31:0] mtvec, mepc, mcause, mstatus, mie, mip;
    
    // 例外/中斷信號
    wire id_illegal_inst;
    reg ex_illegal_inst;
    reg mem_illegal_inst;
    wire id_ecall, id_ebreak, id_mret;  // 🏆 從 decoder 輸出
    reg ex_ecall, ex_ebreak, ex_mret;
    reg mem_ecall, mem_ebreak, mem_mret;
    
    wire if_addr_misaligned;
    wire  mem_addr_misaligned = 1'b0;
    wire mem_access_fault;
    
    reg  exception_valid;
    reg  interrupt_valid;
    reg  [31:0] exception_cause;
    reg  [31:0] exception_tval;
    reg  [31:0] exception_pc;
    wire interrupt_pending;
    
    // CSR 指令信號
    wire id_csr_wen, id_csr_ren;
    reg ex_csr_wen, ex_csr_ren;
    reg mem_csr_wen;
    reg wb_csr_wen;
    wire [11:0] id_csr_addr;
    wire [1:0]  id_csr_op;
    reg ex_csr_imm;
    wire [4:0]  id_csr_imm_val;
    reg [4:0] wb_csr_imm_val, mem_csr_imm_val, ex_csr_imm_val;
    reg [1:0] wb_csr_op, mem_csr_op, ex_csr_op;
    reg [11:0] wb_csr_addr, mem_csr_addr, ex_csr_addr;
    reg wb_csr_imm, mem_csr_imm, mem_csr_ren;
    wire id_csr_imm;
    
    // 其他信號
    wire is_rom_data_access;
    wire [31:0] rom_data_out;
    wire [31:0] mem_ram_rdata;

    // ==================== 定時器信號定義 ====================
    // 🏆 內部定時器中斷信號

    wire [31:0] timer_data_out;
    wire timer_int;
    reg  timer_wr_en;

    // 定義定時器地址（選擇未使用的 MMIO 區域）
    localparam TIMER_BASE     = 32'h20000000;  // 改為 8個0
    localparam TIMER_MTIME    = TIMER_BASE;
    localparam TIMER_MTIMECMP = TIMER_BASE + 8'h8;

    wire is_timer_access = (mem_alu_result >= TIMER_BASE && 
                            mem_alu_result < TIMER_BASE + 32'h10);

    // ==================== 實例化定時器 ====================
    timer u_timer (
        .clk(clk),
        .rst_n(rst_n),
        
        // 記憶體映射介面
        .mtime_addr({28'd0,mem_alu_result[3:0]}),      // 使用低4位作為地址偏移
        .mtimecmp_addr({28'd0,mem_alu_result[3:0]}),   // 同上
        .data_in(mem_rs2_data),
        .wr_en(timer_wr_en),
        .data_out(timer_data_out),
        
        // 中斷輸出
        .timer_interrupt(timer_int)
    );

    // ==================== 定時器寫使能 ====================
    always @(*) begin
        timer_wr_en = mem_mem_wen && is_timer_access;
    end

    
    // ==================== 實例化 CSR 模塊 ====================
    
    csr u_csr(
        .clk(clk),
        .rst_n(rst_n),
        
        .csr_raddr(csr_raddr),
        .csr_rdata(csr_rdata),
        .csr_waddr(csr_waddr),
        .csr_wdata(csr_wdata),
        .csr_wen(csr_wen),
        
        .exception(exception_valid),
        .interrupt(interrupt_valid),
        .exception_pc(exception_pc),
        .exception_cause(exception_cause),
        .exception_tval(exception_tval),
        .exception_epc(mepc), // 使用 mepc 寄存器
        
        .external_interrupt(external_int),
        .timer_interrupt(timer_int),
        .software_interrupt(software_int),
        .interrupt_pending(interrupt_pending),
        
        .mtvec(mtvec),
        .mepc(mepc),
        .mcause(mcause),
        .mstatus(mstatus),
        .mie(mie),
        .mip(mip)
    );    

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) div_stall_cnt <= 0;
        else if (div_stall) div_stall_cnt <= div_stall_cnt + 1;
        else div_stall_cnt <= 0;
    end    

    // --- IF Stage ---
    // 例外處理控制流
    wire take_trap = exception_valid || interrupt_valid;
    wire is_mret = mem_mret && !stall;
    
    // 計算下一個 PC
    assign pc_next = take_trap ? mtvec : 
                    (is_mret ? mepc : 
                    (ex_take_branch ? ex_target_pc : pc + 4));
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc <= 0;
        else if (!stall) pc <= pc_next;
    end

    // ==================== 例外偵測邏輯 ====================
    
    // 1. 指令地址未對齊檢查 (IF 階段)
    //assign if_addr_misaligned = (pc[1:0] != 2'b00);
    assign if_addr_misaligned = 1'b0; // 暫時禁用

    
    // 2. 載入/儲存地址未對齊檢查 (MEM 階段)
//    always @(*) begin
        //mem_addr_misaligned = 1'b0;
/*        
        case (mem_funct3)
            3'b001, 3'b101: begin // LH, LHU
                mem_addr_misaligned = (mem_alu_result[0] != 1'b0);
            end
            3'b010: begin // LW
                mem_addr_misaligned = (mem_alu_result[1:0] != 2'b00);
            end
            default: mem_addr_misaligned = 1'b0; // LB, LBU, SB 永遠對齊
        endcase
*/        
//    end
    
    // 3. 記憶體存取錯誤檢查 (簡化)
    assign mem_access_fault = 1'b0;
    
    // 4. 例外優先級處理
    always @(*) begin
        exception_valid = 1'b0;
        interrupt_valid = 1'b0;
        exception_cause = 32'b0;
        exception_tval = 32'b0;
        exception_pc = mem_pc; // 預設使用 MEM 階段的 PC
/*        
        // 檢查中斷 (優先於例外)
        if (interrupt_pending && mstatus[3]) begin
            interrupt_valid = 1'b1;
            // 找出最高優先級的中斷
            if (mip[11] && mie[11]) exception_cause = 32'h8000000B; // 外部中斷
            else if (mip[7] && mie[7]) exception_cause = 32'h80000007; // 定時器中斷
            else if (mip[3] && mie[3]) exception_cause = 32'h80000003; // 軟體中斷
        end
        // 指令地址未對齊
        else if (if_addr_misaligned) begin
            exception_valid = 1'b1;
            exception_cause = 32'h0;
            exception_tval = pc;
            exception_pc = pc;
        end
        // 非法指令
        else if (mem_illegal_inst) begin
            exception_valid = 1'b1;
            exception_cause = 32'h2;
            exception_tval = mem_inst;
        end
        // 斷點
        else if (mem_ebreak) begin
            exception_valid = 1'b1;
            exception_cause = 32'h3;
            exception_tval = mem_pc;
        end
        // ECALL
        else if (mem_ecall) begin
            exception_valid = 1'b1;
            exception_cause = 32'hB; // M-mode ECALL
            exception_tval = 32'b0;
        end
        // 載入地址未對齊
        else if (mem_is_load && mem_addr_misaligned) begin
            exception_valid = 1'b1;
            exception_cause = 32'h4;
            exception_tval = mem_alu_result;
        end
        // 儲存地址未對齊
        else if (mem_mem_wen && mem_addr_misaligned) begin
            exception_valid = 1'b1;
            exception_cause = 32'h6;
            exception_tval = mem_alu_result;
        end
        // 載入存取錯誤
        else if (mem_is_load && mem_access_fault) begin
            exception_valid = 1'b1;
            exception_cause = 32'h5;
            exception_tval = mem_alu_result;
        end
        // 儲存存取錯誤
        else if (mem_mem_wen && mem_access_fault) begin
            exception_valid = 1'b1;
            exception_cause = 32'h7;
            exception_tval = mem_alu_result;
        end*/
    end

    // ==================== 流水線刷新控制 ====================
    wire pipeline_flush = take_trap || is_mret;
    
    rom u_rom ( 
        .addr(pc), 
        .inst(if_inst),
        .data_addr(mem_alu_result),  // 數據讀取地址
        .data_out(rom_data_out)      // 數據讀取輸出
    );

    // --- ID Stage ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || pipeline_flush || ex_take_branch) begin 
            id_pc <= 0;
            id_inst <= 32'h00000013; 
        end else if (!stall) begin 
            id_pc <= pc;
            id_inst <= if_inst;
        end
    end

    decoder u_decoder (
        .inst(id_inst), 
        .rs1_addr(id_rs1_addr), 
        .rs2_addr(id_rs2_addr), 
        .rd_addr(id_rd_addr),
        .reg_wen(id_reg_wen), 
        .is_store(id_is_store), 
        .is_load(id_is_load), 
        .is_jal(id_is_jal), 
        .is_jalr(id_is_jalr), 
        .funct3(id_funct3), 
        .alu_op(id_alu_op), 
        .alu_src_b(id_alu_src_b), 
        .imm(id_imm), 
        .is_lui(id_is_lui), 
        .is_auipc(id_is_auipc),
        .is_branch(id_is_branch), 
        .is_m_ext_o(id_is_m_ext),
        .illegal_inst(id_illegal_inst),
        
        // CSR 相關新增輸出
        .csr_addr(id_csr_addr),
        .csr_imm(id_csr_imm),
        .csr_imm_val(id_csr_imm_val),
        .csr_wen(id_csr_wen),
        .csr_ren(id_csr_ren),
        .csr_op(id_csr_op),
        
        // 系統指令偵測
        .is_ecall(id_ecall),
        .is_ebreak(id_ebreak),
        .is_mret(id_mret)
    );

    reg_file u_regfile (
        .clk(clk), 
        .raddr1(id_rs1_addr), 
        .rdata1(id_rdata1), 
        .raddr2(id_rs2_addr), 
        .rdata2(id_rdata2), 
        .wen(wb_reg_wen), 
        .waddr(wb_rd_addr), 
        .wdata(wb_write_data)
    );

    // --- Hazard & EX Stage ---
    always @(*) begin
        stall = (ex_is_load && (ex_rd_addr != 0) && (ex_rd_addr == id_rs1_addr || ex_rd_addr == id_rs2_addr)) 
              || div_stall;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || pipeline_flush || stall) begin
            ex_pc <= 0; 
            ex_rd_addr <= 0; 
            ex_reg_wen <= 0; 
            ex_mem_wen <= 0; 
            ex_is_branch <= 0;
            ex_is_jal <= 0; 
            ex_is_jalr <= 0; 
            ex_is_load <= 0;
            ex_is_lui <= 0;
            ex_is_auipc <= 0;
            
            ex_illegal_inst <= 0;
            ex_ecall <= 0;
            ex_ebreak <= 0;
            ex_mret <= 0;
            ex_csr_wen <= 0;
            ex_csr_ren <= 0;
            ex_csr_addr <= 0;
            ex_csr_op <= 0;
            ex_csr_imm <= 0;
            ex_csr_imm_val <= 0;
            ex_rdata1 <= 0;
            ex_rdata2 <= 0;
            ex_imm <= 0;
            ex_funct3 <= 0;
            ex_alu_op <= 0;
            ex_alu_src_b <= 0;
        end else begin
            ex_pc <= id_pc; 
            ex_imm <= id_imm; 
            ex_rd_addr <= id_rd_addr;
            ex_rs1_addr <= id_rs1_addr; 
            ex_rs2_addr <= id_rs2_addr;
            ex_funct3 <= id_funct3; 
            ex_alu_op <= id_alu_op; 
            ex_alu_src_b <= id_alu_src_b;
            ex_mem_wen <= id_is_store; 
            ex_reg_wen <= id_reg_wen; 
            ex_is_load <= id_is_load;
            ex_is_jal <= id_is_jal; 
            ex_is_jalr <= id_is_jalr; 
            ex_is_branch <= id_is_branch;
            ex_is_lui <= id_is_lui; 
            ex_is_auipc <= id_is_auipc; 
            ex_rdata1 <= id_rdata1; 
            ex_rdata2 <= id_rdata2;

            ex_illegal_inst <= id_illegal_inst;
            ex_ecall <= id_ecall;
            ex_ebreak <= id_ebreak;
            ex_mret <= id_mret;
            ex_csr_wen <= id_csr_wen;
            ex_csr_ren <= id_csr_ren;
            ex_csr_addr <= id_csr_addr;
            ex_csr_op <= id_csr_op;
            ex_csr_imm <= id_csr_imm;
            ex_csr_imm_val <= id_csr_imm_val;            
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

    alu u_alu (
        .a(alu_in_a_final), 
        .b(ex_alu_in_b), 
        .alu_op(ex_alu_op), 
        .result(ex_alu_result), 
        .zero(ex_alu_zero), 
        .less(ex_alu_less)
    );

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
            mem_rs2_data <= 0; 
            mem_rd_addr <= 0; 
            mem_pc_plus_4 <= 0;
            mem_mem_wen <= 0; 
            mem_reg_wen <= 0; 
            mem_is_load <= 0;
            mem_is_jal_jalr <= 0; 
            mem_funct3 <= 0;
            mem_inst <= 0;      // 🏆 新增
            mem_pc <= 0;        // 🏆 新增
            
            mem_illegal_inst <= 0;
            mem_ecall <= 0;
            mem_ebreak <= 0;
            mem_mret <= 0;
            mem_csr_wen <= 0;
            mem_csr_ren <= 0;
            mem_csr_addr <= 0;
            mem_csr_op <= 0;
            mem_csr_imm <= 0;
            mem_csr_imm_val <= 0;
        end else begin
            mem_alu_result <= ex_alu_result;
            mem_rs2_data <= rs2_data_final;
            mem_rd_addr <= ex_rd_addr; 
            mem_pc_plus_4 <= ex_pc + 4;
            mem_mem_wen <= ex_mem_wen; 
            mem_reg_wen <= ex_reg_wen; 
            mem_is_load <= ex_is_load;
            mem_is_jal_jalr <= (ex_is_jal || ex_is_jalr); 
            mem_funct3 <= ex_funct3;
            mem_inst <= ex_pc;  // 🏆 簡化：用 PC 代替實際指令
            mem_pc <= ex_pc;    // 🏆 傳遞 PC
            
            mem_illegal_inst <= ex_illegal_inst;
            mem_ecall <= ex_ecall;
            mem_ebreak <= ex_ebreak;
            mem_mret <= ex_mret;
            mem_csr_wen <= ex_csr_wen;
            mem_csr_ren <= ex_csr_ren;
            mem_csr_addr <= ex_csr_addr;
            mem_csr_op <= ex_csr_op;
            mem_csr_imm <= ex_csr_imm;
            mem_csr_imm_val <= ex_csr_imm_val;
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

    // 只有位址不在 MMIO 範圍時，才允許寫入 Data RAM
    data_ram u_ram (
        .clk(clk), 
        .wen(mem_mem_wen && !mem_is_mmio), 
        .addr(mem_alu_result), 
        .wdata(mem_rs2_data), 
        .funct3(mem_funct3),  // 🏆 新增：傳遞操作類型
        .rdata(mem_ram_rdata)
    ); 

    uart_tx u_uart (
        .clk(clk), 
        .rst_n(rst_n), 
        .data_i(mem_rs2_data[7:0]), 
        .valid_i(uart_wen), 
        .test_mode_i(1'b0),         // ✨ 測試模式關閉
        .busy_o(uart_busy), 
        .ready_o(),                 // ✨ 可選：可以連接到其他模組
        .tx_o(uart_tx_o)
    );

    // 🏆 3. 效能計數器累加邏輯 (只保留一組)
    reg [31:0] cycle_cnt, inst_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin 
            cycle_cnt <= 0; 
            inst_cnt <= 0; 
        end else begin 
            cycle_cnt <= cycle_cnt + 1; // 總週期數
            // 如果寫回階段有寫入暫存器且目標不是 x0，視為一條有效指令
            if (wb_reg_wen && wb_rd_addr != 0) inst_cnt <= inst_cnt + 1; 
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
        end else if (is_timer_access) begin
            // 🏆 從定時器讀取
            mem_final_rdata = timer_data_out;        
        end else if (is_rom_data_access && !mem_mem_wen) begin
            // 🏆 從 ROM 讀取數據（只讀）
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

    // ==================== CSR 讀寫處理 ====================
    
    // CSR 讀取多工器
    assign csr_raddr = ex_csr_addr;
    
    // CSR 寫入邏輯
    reg [31:0] csr_write_val;
    always @(*) begin
        case (wb_csr_op)
            2'b01: csr_write_val = csr_wdata;           // CSRRW
            2'b10: csr_write_val = csr_rdata | csr_wdata; // CSRRS
            2'b11: csr_write_val = csr_rdata & ~csr_wdata; // CSRRC
            default: csr_write_val = csr_wdata;
        endcase
    end
    
    // CSR 寫入數據來源
    assign csr_wdata = wb_csr_imm ? {27'b0, wb_csr_imm_val} : wb_rs1_data;
    assign csr_waddr = wb_csr_addr;
    assign csr_wen = wb_csr_wen;

    // --- WB Stage ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ram_rdata <= 0; 
            wb_alu_result <= 0; 
            wb_rd_addr <= 0; 
            wb_pc_plus_4 <= 0;
            wb_reg_wen <= 0; 
            wb_is_load <= 0; 
            wb_is_jal_jalr <= 0;
            wb_funct3 <= 0;
            wb_rs1_data <= 0;  // 🏆 新增
            
            wb_csr_wen <= 0;
            wb_csr_addr <= 0;
            wb_csr_op <= 0;
            wb_csr_imm <= 0;
            wb_csr_imm_val <= 0;
        end else begin
            wb_ram_rdata <= mem_final_rdata; 
            wb_alu_result <= mem_alu_result; 
            wb_rd_addr <= mem_rd_addr; 
            wb_pc_plus_4 <= mem_pc_plus_4;
            wb_reg_wen <= mem_reg_wen; 
            wb_is_load <= mem_is_load;
            wb_is_jal_jalr <= mem_is_jal_jalr;
            wb_funct3 <= mem_funct3;
            wb_rs1_data <= mem_rs2_data; // 🏆 傳遞 rs1 數據 (簡化)
            
            wb_csr_wen <= mem_csr_wen;
            wb_csr_addr <= mem_csr_addr;
            wb_csr_op <= mem_csr_op;
            wb_csr_imm <= mem_csr_imm;
            wb_csr_imm_val <= mem_csr_imm_val;
        end
    end

    assign wb_write_data = (wb_is_jal_jalr) ? wb_pc_plus_4 : 
                          (wb_is_load) ? wb_ram_rdata : 
                          wb_alu_result;

endmodule