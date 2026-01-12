`timescale 1ns/1ps  // <--- 🐻 關鍵修正：定義時間單位！

module core(
    input clk,
    input rst_n,
    output uart_tx_o,
    input uart_rx_i
);
    // --- 1. 訊號定義 ---
    reg id_valid, ex_valid, mem_valid, wb_valid;
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
    wire is_csr, is_system, csr_use_imm;
    wire [1:0] csr_op_type;
    wire [11:0] csr_addr;
    wire [31:0] csr_rdata, csr_wdata;
    wire csr_we;
    wire [31:0] mtvec, mepc;
    wire timer_int, ext_int;
    wire id_is_csr;
    wire [1:0] id_csr_op;
    wire id_csr_use_imm;
    wire [11:0] id_csr_addr;
    wire [31:0] mie_reg;

    // --- 新增：中斷保護邏輯信號 ---
    reg interrupt_pending;
    reg [31:0] interrupt_pc;
    wire delayed_interrupt;
    wire final_exc_taken;
    wire interrupt_immediate;  // 即時中斷信號
    
    // 4. 定義例外相關信號
    wire id_is_illegal = !(id_reg_wen || id_is_load || id_is_store || 
                       id_is_branch || id_is_jal || id_is_jalr || 
                       id_is_lui || id_is_auipc || is_system || 
                       id_inst == 32'h00000013);

    // =============================================================================
    // 例外觸發邏輯 (Exception Trigger Logic)
    // =============================================================================

    // 1. 定義「軟體同步例外」：包含非法指令 (Illegal)、ECALL、EBREAK
    wire id_sw_exc = id_is_illegal ||
                     (is_system && (id_inst == 32'h00000073 || id_inst == 32'h00100073));

    // --- 6. 中斷產生邏輯 (Interrupt Logic) ---
    wire uart_irq_raw = (uart_rx_ready && reg_uart_ie[1]) ||
                        (!uart_busy && reg_uart_ie[0]);

    // 如果 EX 正在跳轉，暫時遮罩中斷，保護 EPC
    wire uart_int_final = (uart_irq_raw && mie_reg[16] && mstatus_mie && !ex_take_branch);
    
    assign interrupt_immediate = timer_int_final || uart_int_final;  // 新增
    wire exc_taken_sync = (id_sw_exc && !ex_take_branch);          // 同步例外
    wire exc_taken = exc_taken_sync || interrupt_immediate;        // 保持原有邏輯，但後面會替換

    wire mstatus_mie;                   

    reg [63:0] mtime;
    reg [63:0] mtimecmp;

    wire mem_is_mtimecmp_l = (mem_alu_result == 32'h10000010);
    wire mem_is_mtimecmp_h = (mem_alu_result == 32'h10000014);
    wire timer_int_raw = (mtime >= mtimecmp);

    wire timer_int_final = timer_int_raw && mie_reg[7] && mstatus_mie && !ex_take_branch;
    wire mret_taken = (is_system && (id_inst == 32'h30200073));   // MRET

    wire is_ret_instruction = (id_inst == 32'h00008067); // jalr x0, 0(x1)

    wire flush = (ex_take_branch || final_exc_taken || mret_taken);

    reg [31:0] exc_cause;
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

    // 1. 偵測 CPU 是否正在進行 UART 資料讀取
    // 🏆 修正：移除 !exc_taken，因為我們允許 MEM 階段指令完成
    wire uart_read_ack = (mem_alu_result == 32'h10000000) && mem_is_load && mem_valid;
    
    // 判定目前 MEM 階段的位址是否屬於 UART 範圍
    wire mem_at_uart_status = (mem_alu_result == 32'h10000004);

    // UART RX 模組實例化
    reg tx_test_en;
    reg rx_test_en;

    wire [31:0] wb_bram_rdata; // BRAM 讀出的 32-bit 資料
    reg         wb_is_ram_addr; // 判斷是否為 RAM 存取的旗標

    // 實作 RX 的路徑多工器 (MUX)
    wire final_rx_i = (rx_test_en) ? uart_tx_o : uart_rx_i;

    // =============================================================================
    // 中斷延遲保護邏輯
    // =============================================================================

    // 中斷延遲觸發邏輯
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            interrupt_pending <= 1'b0;
            interrupt_pc <= 32'b0;
        end else begin
            // 如果中斷發生但 MEM 階段忙碌（正在寫入或載入），延遲處理
            if (interrupt_immediate && (mem_mem_wen || mem_is_load)) begin
                interrupt_pending <= 1'b1;
                // 記錄當前的 PC（選擇合適的階段）
                if (ex_valid) interrupt_pc <= ex_pc;
                else if (id_valid) interrupt_pc <= id_pc;
                else interrupt_pc <= pc;
            end 
            // MEM 階段完成，觸發延遲的中斷
            else if (interrupt_pending && !(mem_mem_wen || mem_is_load)) begin
                interrupt_pending <= 1'b0;
            end
            // 如果已經處理了例外，清除掛起標誌
            else if (final_exc_taken) begin
                interrupt_pending <= 1'b0;
            end
        end
    end

    // 延遲中斷信號（當 MEM 階段不忙碌時觸發）
    assign delayed_interrupt = interrupt_pending && !(mem_mem_wen || mem_is_load);

    // 最終的例外觸發信號（包含延遲中斷）
    assign final_exc_taken = exc_taken_sync || (interrupt_immediate && !(mem_mem_wen || mem_is_load)) || delayed_interrupt;    

    wire [7:0] uart_rx_data;
    wire       uart_rx_ready;
    uart_rx #(
        .CLK_FREQ(100000000), 
        .BAUD_RATE(1152000)
    ) u_uart_rx (
        //inputs 
        .clk        (clk),
        .rst_n      (rst_n),
        .rx_i       (final_rx_i),
        .read_en_i  (uart_read_ack),
        //outputs 
        .data_o     (uart_rx_data),
        .ready_o    (uart_rx_ready)
    );

    // =============================================================================
    // BearCore-V Peripheral Control & Address Decoder
    // =============================================================================

    // --- 1. 內部暫存器定義 ---
    reg [31:0] reg_uart_ie; // 0x1000_0018 (Bit 1:RX_IE, Bit 0:TX_IE)

    // --- 2. 位址解碼訊號 ---
    wire is_mmio_access = (mem_alu_result[31:16] == 16'h1000);

    // --- 3. 寫入控制 (Peripheral Write) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_uart_ie   <= 32'h0;
        end else if (mem_mem_wen && mem_valid && mem_is_uart_ie) begin
            reg_uart_ie   <= mem_rs2_data;
        end
    end

    wire any_interrupt = interrupt_immediate || delayed_interrupt;

    wire [31:0] highest_priority_irq = 
                    timer_int_final ? 32'h80000007 :
                    uart_int_final ? 32'h80000010 :
                    32'b0;    

    wire sel_ex_target  = ex_take_branch;     
    wire sel_exc_target = !ex_take_branch && final_exc_taken; 
    wire sel_mret_target = !ex_take_branch && !final_exc_taken && mret_taken;                     
    
    // --- IF Stage ---
    // 🚨 修改後：
    assign pc_next =    (sel_ex_target) ? ex_target_pc : // 🥇 最高優先
                        (sel_exc_target) ? mtvec       : // 🥈 次要優先（使用 final_exc_taken）
                        (sel_mret_target)      ? mepc        : // 🥉 第三優先
                        (pc + 4);

    wire alu_stall_req;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc <= 0;
        else if (!stall) pc <= pc_next;
    end

    wire [31:0] rom_data_out;
    rom u_rom ( 
                //inputs
                .addr(pc), 
                .data_addr(mem_alu_result),  // 數據讀取地址
                //outputs
                .inst(if_inst),
                .data_out(rom_data_out)      // 數據讀取輸出
    );

    // --- ID Stage ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin 
            id_pc <= 0;
            id_inst <= 32'h00000013; 
            id_valid <= 1'b0; 
        end else if (!stall) begin 
            id_pc <= pc;
            id_inst <= if_inst;
            id_valid <= 1'b1; 
        end
    end

    decoder u_decoder (
        //inputs
        .inst       (id_inst),
        //outputs
        .rs1_addr   (id_rs1_addr), 
        .rs2_addr   (id_rs2_addr), 
        .rd_addr    (id_rd_addr),
        .reg_wen    (id_reg_wen), 
        .is_store   (id_is_store), 
        .is_load    (id_is_load), 
        .is_jal     (id_is_jal), 
        .is_jalr    (id_is_jalr), 
        .funct3     (id_funct3), 
        .alu_op     (id_alu_op), 
        .alu_src_b  (id_alu_src_b), 
        .imm        (id_imm), 
        .is_lui     (id_is_lui), 
        .is_auipc   (id_is_auipc),
        .is_branch  (id_is_branch), 
        .is_m_ext_o (id_is_m_ext),
        .is_csr     (is_csr),
        .is_system  (is_system),
        .csr_op_type(csr_op_type),
        .csr_use_imm(csr_use_imm),
        .csr_addr   (csr_addr)
    );

    assign id_is_csr = is_csr;
    assign id_csr_op = csr_op_type;
    assign id_csr_use_imm = csr_use_imm;
    assign id_csr_addr = csr_addr;

    wire timer_irq_trigger = mstatus_mie && mie_reg[7] && timer_int_raw;

    wire [31:0] trap_ret_pc = 
                (alu_stall_req) ? ex_pc :
                (id_sw_exc) ? id_pc :                    // 軟體例外：返回當前指令
                (delayed_interrupt) ? interrupt_pc :     // 🆕 延遲中斷：返回保存的 PC
                (interrupt_immediate && ex_valid) ? ex_pc : // 即時中斷且 EX 有指令
                (interrupt_immediate && id_valid) ? id_pc : // 即時中斷且 ID 有指令
                pc;                                      // 預設

    csr_registers u_csr (
        //inputs
        .clk        (clk), 
        .rst_n      (rst_n),
        .csr_addr   (mem_csr_addr), 
        .csr_wdata  (csr_wdata), 
        .csr_we     (csr_we), 
        .csr_op     (mem_csr_op), 
        .csr_use_imm(mem_csr_use_imm),
        .trap_in    (final_exc_taken), 
        .id_pc      (trap_ret_pc), 
        .id_exc_cause(exc_cause), 
        .timer_int_raw(timer_int_raw),
        .uart_int_raw (uart_irq_raw),
        .mret_taken (mret_taken),
        //outputs
        .csr_rdata  (csr_rdata), 
        .mtvec      (mtvec), 
        .mepc       (mepc), 
        .mie_reg    (mie_reg), 
        .mstatus_mie(mstatus_mie)
    );

    // 5. 處理例外原因
    always @(*) begin
        if (id_is_illegal) begin
            exc_cause = 32'h00000002;
            exc_tval  = id_inst;
        end    
        else if (is_system) begin
            case (id_inst)
                32'h00000073: begin  // ECALL
                    exc_cause = 32'h0000000B;
                    exc_tval = 32'h0;
                end
                32'h00100073: begin  // EBREAK
                    exc_cause = 32'h00000003;
                    exc_tval = 32'h0;
                end
                default: begin
                    exc_cause = 32'h00000002;
                    exc_tval = id_inst;
                end
            endcase
        end
        else if (any_interrupt) begin 
            if (timer_int_final) exc_cause = 32'h80000007;
            else if (uart_int_final) exc_cause = 32'h80000010;
            else exc_cause = 32'h0;

            exc_tval  = 32'h0;
        end 
        else begin
            exc_cause = 32'h0;
            exc_tval = 32'h0;
        end
    end    

    reg_file u_regfile (
        //inputs
        .clk    (clk), 
        .rst_n  (rst_n),
        .raddr1 (id_rs1_addr), 
        .raddr2 (id_rs2_addr), 
        .wen    (wb_reg_wen), 
        .waddr  (wb_rd_addr), 
        .wdata  (wb_write_data),
        //outputs
        .rdata1 (id_rdata1), 
        .rdata2 (id_rdata2) 
    );

    // 判斷 MEM 階段是否為 RAM 讀取
    wire mem_is_ram_load = mem_is_load && (mem_alu_result >= 32'h00010000) && (mem_alu_result <= 32'h0001FFFF);

    // Load Hazard 邏輯
    wire load_hazard = (ex_is_load && (ex_rd_addr != 0) && (ex_rd_addr == id_rs1_addr || ex_rd_addr == id_rs2_addr)) ||
                       (mem_is_ram_load && (mem_rd_addr != 0) && (mem_rd_addr == id_rs1_addr || mem_rd_addr == id_rs2_addr));

    // --- Hazard & EX Stage ---
    always @(*) begin
        stall = (load_hazard || alu_stall_req) && !exc_taken;
    end

    // --- EX Stage ---
    wire final_id_reg_wen = id_reg_wen || id_is_csr;

    wire [31:0] id_rdata1_fwd = (wb_valid && wb_reg_wen && wb_rd_addr != 0 && wb_rd_addr == id_rs1_addr) ?
                                wb_write_data : id_rdata1;
    wire [31:0] id_rdata2_fwd = (wb_valid && wb_reg_wen && wb_rd_addr != 0 && wb_rd_addr == id_rs2_addr) ?
                                wb_write_data : id_rdata2;                                

    // --- EX Stage (ID/EX Pipeline Register) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            ex_pc <= 0;
            ex_rd_addr <= 0; ex_reg_wen <= 0; ex_mem_wen <= 0; ex_is_branch <= 0;
            ex_is_jal <= 0; ex_is_jalr <= 0;
            ex_is_load <= 0;
            ex_is_lui      <= 0;
            ex_is_auipc    <= 0;
            ex_alu_op      <= 4'b0; 
            ex_is_csr <= 1'b0;
            ex_is_system <= 1'b0;
            ex_csr_op <= 2'b0;
            ex_csr_use_imm <= 1'b0;
            ex_csr_addr <= 12'b0;  
            ex_valid <= 1'b0;
            ex_funct3 <= 3'b0; 
        end else if (alu_stall_req) begin
            // ALU 暫停時保持原值
        end else if (load_hazard) begin
            // Load Hazard 氣泡
            ex_valid <= 1'b0;
            ex_reg_wen <= 0;
            ex_mem_wen <= 0;
            ex_is_branch <= 0;
            ex_is_jal <= 0;
            ex_is_jalr <= 0;
            ex_rd_addr <= 0;
            ex_is_csr <= 0;
            ex_is_system <= 0;            
        end else begin
            // 正常傳遞
            ex_pc <= id_pc;
            ex_imm <= id_imm; ex_rd_addr <= id_rd_addr;
            ex_rs1_addr <= id_rs1_addr; ex_rs2_addr <= id_rs2_addr;
            ex_funct3 <= id_funct3; ex_alu_op <= id_alu_op;
            ex_alu_src_b <= id_alu_src_b;
            ex_mem_wen <= id_is_store; ex_reg_wen <= final_id_reg_wen; ex_is_load <= id_is_load;
            ex_is_jal <= id_is_jal; ex_is_jalr <= id_is_jalr;
            ex_is_branch <= id_is_branch;
            ex_is_lui <= id_is_lui; ex_is_auipc <= id_is_auipc; ex_rdata1 <= id_rdata1_fwd; ex_rdata2 <= id_rdata2_fwd;
            ex_is_csr <= id_is_csr;
            ex_is_system <= is_system;
            ex_csr_op <= id_csr_op;
            ex_csr_use_imm <= id_csr_use_imm;
            ex_csr_addr <= id_csr_addr;     
            ex_valid <= id_valid;
        end
    end

    // Forwarding logic
    wire [31:0] mem_stage_data = (mem_is_load)     ? mem_final_rdata :
                                 (mem_is_jal_jalr) ? mem_pc_plus_4 :
                                 (mem_is_csr)      ? csr_rdata :
                                 mem_alu_result;

    wire [31:0] fwd_rs1 = (mem_reg_wen && mem_rd_addr != 0 && mem_rd_addr == ex_rs1_addr) ?
                          mem_stage_data  :
                         (wb_reg_wen  && wb_rd_addr  != 0 && wb_rd_addr  == ex_rs1_addr) ?
                          wb_write_data : ex_rdata1;
    wire [31:0] fwd_rs2 = (mem_reg_wen && mem_rd_addr != 0 && mem_rd_addr == ex_rs2_addr) ?
                          mem_stage_data  :
                         (wb_reg_wen  && wb_rd_addr  != 0 && wb_rd_addr  == ex_rs2_addr) ?
                          wb_write_data : ex_rdata2;

    assign alu_in_a_final = (ex_is_auipc) ? ex_pc : fwd_rs1;
    assign ex_alu_in_b    = (ex_alu_src_b) ? ex_imm : fwd_rs2;
    assign rs2_data_final = fwd_rs2;

    alu u_alu ( 
        .clk(clk), .rst_n(rst_n), .funct3(ex_funct3[2:0]),
        .a(alu_in_a_final), .b(ex_alu_in_b), 
        .alu_op(ex_alu_op), .result(ex_alu_result), 
        .zero(ex_alu_zero), .less(ex_alu_less),
        .stall_req(alu_stall_req)
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
        // 🏆 關鍵修正：移除了 exc_taken！
        // 我們讓 MEM 階段的指令在中斷發生時繼續做完，避免指令跳過。
        // 下一條 EX 指令會被 flush，並在 ISR 結束後重做，流程完美銜接！
        if (!rst_n || mret_taken) begin
            mem_alu_result <= 0;
            mem_rs2_data <= 0; mem_rd_addr <= 0; mem_pc_plus_4 <= 0;
            mem_mem_wen <= 0; mem_reg_wen <= 0; mem_is_load <= 0;
            mem_is_jal_jalr <= 0; mem_funct3 <= 0;
            mem_is_csr <= 1'b0;
            mem_is_system <= 1'b0;
            mem_csr_op <= 2'b0;
            mem_csr_use_imm <= 1'b0;
            mem_csr_addr <= 12'b0;     
            mem_valid <= 1'b0;       
        end
        else if (alu_stall_req) begin
            mem_valid <= 0;
            mem_reg_wen <= 0;
            mem_mem_wen <= 0;
            mem_is_jal_jalr <= 0;
        end    
        else begin
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
            mem_valid <= ex_valid;
        end
    end

    // MMIO 解碼
    wire mem_is_mmio = (mem_alu_result >= 32'h10000000 && mem_alu_result < 32'h10000010);
    wire is_ram_addr = (mem_alu_result >= 32'h00010000) && (mem_alu_result <= 32'h0001FFFF);

    wire mem_is_uart_data   = (mem_alu_result == 32'h10000000);
    wire mem_is_uart_status = (mem_alu_result == 32'h10000004); 
    wire mem_is_cycle_cnt   = (mem_alu_result == 32'h10000008);
    wire mem_is_inst_cnt    = (mem_alu_result == 32'h1000000C); 
    wire mem_is_uart_ie     = (mem_alu_result == 32'h10000018);

    wire [31:0] mem_ram_rdata;
    wire actual_ram_wen = mem_mem_wen && is_ram_addr;

    wire [31:0] wb_final_mem_data = (wb_is_ram_addr) ? wb_bram_rdata : wb_ram_rdata;

    assign wb_write_data = (wb_is_jal_jalr) ? wb_pc_plus_4 : 
                           (wb_is_load || wb_is_csr) ? wb_final_mem_data : 
                           wb_alu_result;

    // 寫入資料對齊邏輯
    reg [31:0] mem_ram_wdata_aligned;
    always @(*) begin
        case (mem_funct3)
            3'b000: mem_ram_wdata_aligned = {4{mem_rs2_data[7:0]}};  // SB
            3'b001: mem_ram_wdata_aligned = {2{mem_rs2_data[15:0]}}; // SH
            default: mem_ram_wdata_aligned = mem_rs2_data;           // SW
        endcase
    end                             

    data_ram u_ram (
        .clk(clk),
        .wen(actual_ram_wen), 
        .addr({16'd0, mem_alu_result[15:0]}), 
        .wdata(mem_ram_wdata_aligned), 
        .funct3(mem_funct3),  
        .rdata(wb_bram_rdata)
    );

    wire uart_reg_write = mem_mem_wen && mem_is_uart_data && mem_valid;
    wire uart_real_tx_en = uart_reg_write && (mem_rs2_data[31] == 2'b0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_test_en <= 1'b0;
            rx_test_en <= 1'b0;
        end else if (uart_reg_write) begin 
            tx_test_en <= mem_rs2_data[31];
            rx_test_en <= mem_rs2_data[30]; 
        end
    end    

    uart_tx #(  .CLK_FREQ(100000000), .BAUD_RATE(1152000) ) u_uart(
        .clk(clk), .rst_n(rst_n), 
        .data_i(mem_rs2_data[7:0]), .valid_i(uart_real_tx_en),
        .busy_o(uart_busy), .tx_o(uart_tx_o), .test_mode_i(tx_test_en)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin 
            cycle_cnt <= 0;
            inst_cnt  <= 0; 
        end else begin 
            cycle_cnt <= cycle_cnt + 1;
            if (wb_valid) begin
                inst_cnt <= inst_cnt + 1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtimecmp <= 64'hFFFFFFFF_FFFFFFFF;
        end else if (mem_mem_wen && mem_valid) begin 
            if (mem_is_mtimecmp_l) mtimecmp[31:0]  <= mem_rs2_data;
            else if (mem_is_mtimecmp_h) mtimecmp[63:32] <= mem_rs2_data;
        end
    end    

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) mtime <= 64'b0;
        else mtime <= mtime + 1'b1;
    end

    reg [31:0] mem_final_rdata;
    assign is_rom_data_access = (mem_alu_result >= 32'h00000000 && mem_alu_result < 32'h00010000);

    always @(*) begin
        if (mem_is_uart_status) begin
            mem_final_rdata = {30'b0, uart_rx_ready, uart_busy};
        end else if (mem_alu_result == 32'h10000000) begin
            mem_final_rdata = {24'b0, uart_rx_data};
        end else if (mem_alu_result == 32'h10000008) begin
            mem_final_rdata = mtime[31:0];
        end else if (mem_alu_result == 32'h1000000C) begin
            mem_final_rdata = mtime[63:32];
        end else if (mem_alu_result == 32'h10000010) begin
            mem_final_rdata = mtimecmp[31:0];
        end else if (mem_alu_result == 32'h10000014) begin
            mem_final_rdata = mtimecmp[63:32];
        end else if (mem_alu_result == 32'h10000018) begin
            mem_final_rdata = reg_uart_ie;
        end else if (mem_is_csr) begin                   
            mem_final_rdata = csr_rdata;
        end else if (is_rom_data_access && !mem_mem_wen) begin
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
            mem_final_rdata = 32'h0;
        end
    end    

    // --- WB Stage ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ram_rdata <= 0;
            wb_alu_result <= 0; wb_rd_addr <= 0; wb_pc_plus_4 <= 0;
            wb_reg_wen <= 0; wb_is_load <= 0; wb_is_jal_jalr <= 0;
            wb_is_csr <= 1'b0;
            wb_is_system <= 1'b0;
            wb_csr_op <= 2'b0;
            wb_csr_use_imm <= 1'b0;
            wb_csr_addr <= 12'b0;    
            wb_valid  <= 1'b0;
            wb_is_ram_addr <= 1'b0; 
        end else begin
            wb_ram_rdata <= mem_final_rdata;
            wb_alu_result <= mem_alu_result; 
            wb_rd_addr <= mem_rd_addr; wb_pc_plus_4 <= mem_pc_plus_4;
            wb_reg_wen <= mem_reg_wen; wb_is_load <= mem_is_load;
            wb_is_jal_jalr <= mem_is_jal_jalr;
            wb_is_csr <= mem_is_csr;
            wb_is_system <= mem_is_system;
            wb_csr_op <= mem_csr_op;
            wb_csr_use_imm <= mem_csr_use_imm;
            wb_csr_addr <= mem_csr_addr;   
            wb_valid <= mem_valid;
            wb_is_ram_addr <= is_ram_addr;
        end
    end

    wire [31:0] csr_rdata_forwarded = (mem_is_csr && csr_we && mem_csr_addr == wb_csr_addr) ?
                                      csr_wdata : csr_rdata;

    assign csr_wdata =  (mem_csr_op == 2'b00) ? mem_csr_wdata :  // CSRRW
                        (mem_csr_op == 2'b01) ? (mem_csr_wdata | csr_rdata) :  // CSRRS
                        (mem_csr_op == 2'b10) ? (~mem_csr_wdata & csr_rdata) :  // CSRRC
                        32'b0;

    wire csr_write_always = (mem_csr_op == 2'b00);
    wire csr_write_set    = (mem_csr_op == 2'b01) && (|csr_wdata);
    wire csr_write_clear  = (mem_csr_op == 2'b10) && (|csr_wdata);
    assign csr_we = mem_valid && mem_is_csr && (csr_write_always || csr_write_set || csr_write_clear);

    // ============================================================
    // 🐻 BearCore-V Debug Monitor (Simulation Only)
    // ============================================================
    // 只在模擬時生效，不會影響 FPGA 綜合
`ifdef SIMULATION
    always @(posedge clk) begin
        // 監控中斷返回
        if (mret_taken) begin
            $display("\n[🐻 MRET DEBUG] Time=%0t | PC=%h", $time, mepc);
            $display("    > MSTATUS.MIE before: %b", u_csr.reg_mstatus[7]);
            $display("    > MSTATUS.MIE after: %b", u_csr.reg_mstatus[3]);
        end
        
        // 監控例外進入
        if (exc_taken) begin
            $display("\n[🐻 EXCEPTION DEBUG] Time=%0t", $time);
            $display("    > Cause: %h", exc_cause);
            $display("    > Trap Return PC: %h", trap_ret_pc);
        end
    end

    // 添加調試信息
    always @(posedge clk) begin
        if (exc_taken) begin
            $display("[IRQ DEBUG] exc_taken=1, trap_ret_pc=%h, id_pc=%h, ex_pc=%h, pc=%h",
                    trap_ret_pc, id_pc, ex_pc, pc);
            $display("[IRQ DEBUG] id_valid=%b, ex_valid=%b, id_sw_exc=%b, alu_stall_req=%b",
                    id_valid, ex_valid, id_sw_exc, alu_stall_req);
        end
    end    

    // 監控中斷信號

    always @(posedge clk) begin
        if (uart_int_final) begin
            $display("[UART IRQ DEBUG] Time=%0t", $time);
            $display("  uart_irq_raw=%b, mie_reg[16]=%b, mstatus_mie=%b",
                    uart_irq_raw, mie_reg[16], mstatus_mie);
            $display("  uart_rx_ready=%b, uart_busy=%b, reg_uart_ie=%h",
                    uart_rx_ready, uart_busy, reg_uart_ie);
        end
    end

    always @(posedge clk) begin
        if (rst_n) begin
            // 監控關鍵信號
            if (cycle_cnt < 10) begin  // 只顯示前10個週期
                $display("[INIT] PC=%h, pc_next=%h, mret_taken=%b, mepc=%h", 
                        pc, pc_next, mret_taken, mepc);
                $display("[INIT] if_inst=%h, id_inst=%h", if_inst, id_inst);
            end
            
            // 監控指令流程
            if (wb_valid && cycle_cnt < 20) begin
                $display("[WB] PC=%h, inst=%h, rd=%d, wdata=%h", 
                        wb_alu_result - 4, if_inst, wb_rd_addr, wb_write_data);
            end
        end
    end
`endif

endmodule