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

    // 1. 添加 CSR 相關信號
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

    // 4. 定義例外相關信號
    wire id_is_illegal = !(id_reg_wen || id_is_load || id_is_store || 
                       id_is_branch || id_is_jal || id_is_jalr || 
                       id_is_lui || id_is_auipc || is_system || 
                       id_inst == 32'h00000013);

    // =============================================================================
    // 🏆 優化：例外觸發邏輯 (Exception Trigger Logic)
    // =============================================================================

    // 1. 定義「軟體同步例外」：包含非法指令 (Illegal)、ECALL、EBREAK [cite: 75, 106-113]
    wire id_sw_exc = id_is_illegal || (is_system && (id_inst == 32'h00000073 || id_inst == 32'h00100073));

    // 2. 最終例外判定：
    //    - 關鍵優化：如果 EX 階段正在「跳轉」(!ex_take_branch)，則忽略 ID 階段的例外。
    //    - 理由：跳轉指令後的下一條指令是「預取雜訊」，不應觸發 Illegal TRAP 。
    //    - 外部中斷 (timer_int_final) 則不受此限，隨時可觸發 

    // --- 6. 中斷產生邏輯 (Interrupt Logic) ---
    // 當 (接收到資料且開啟 RX_IE) 或 (發送空閒且開啟 TX_IE) 時觸發
    wire uart_irq_raw = (uart_rx_ready && reg_uart_ie[1]) || 
                        (!uart_busy && reg_uart_ie[0]);

    wire uart_int_final = tx_test_en ? 1'b0 : (uart_irq_raw && mie_reg[16] && mstatus_mie && !ex_take_branch);

    wire exc_taken = (id_sw_exc && !ex_take_branch) || timer_int_final || uart_int_final;

    wire mstatus_mie;                   

    reg [63:0] mtime; // 🏆 升級為 64 位元生理時鐘
    reg [63:0] mtimecmp; // 🏆 64 位元比較暫存器 (鬧鐘設定值)

    wire mem_is_mtimecmp_l = (mem_alu_result == 32'h10000010);
    wire mem_is_mtimecmp_h = (mem_alu_result == 32'h10000014);    

    wire timer_int_raw = (mtime >= mtimecmp);

    // 🏆 修正：只有在 EX 階段「沒有」要跳轉時，才允許觸發中斷
    // 這樣可以確保 EPC (mepc) 抓到的是穩定的位址，而不是被 Flush 掉的 0
    wire timer_int_final = timer_int_raw && mie_reg[7] && mstatus_mie && !ex_take_branch;


    wire mret_taken = (is_system && (id_inst == 32'h30200073));   // MRET

    wire flush = (ex_take_branch || exc_taken || mret_taken); // 當跳轉或例外發生時，沖刷流水線    


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
    wire uart_read_ack = (mem_alu_result == 32'h10000000) && mem_is_load && mem_valid;

    // 判定目前 MEM 階段的位址是否屬於 UART 範圍
    wire mem_at_uart_status = (mem_alu_result == 32'h10000004);

    // 🏆 讀取確認邏輯 (Read Ack)
    // 條件：1.位址在資料暫存器 2.是一條載入指令 (LOAD) 3.該流水線階段指令有效

    // UART RX 模組實例化
    // 🏆 1. 定義測試模式寄存器
    reg tx_test_en;
    reg rx_test_en;


    // 🏆 2. 實作 RX 的路徑多工器 (MUX)
    // 如果進入測試模式，RX 訊號直接抓 TX 的輸出
    wire final_rx_i = (rx_test_en) ? uart_tx_o : uart_rx_i;


    wire [7:0] uart_rx_data;
    wire       uart_rx_ready;

    uart_rx #(
        .CLK_FREQ(100000000), 
        .BAUD_RATE(1152000) // 🏆 這裡要跟你之前日誌的 1152000 一致
    ) u_uart_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx_i(final_rx_i),
        .read_en_i(uart_read_ack), // 🏆 當讀取成功時，自動通知模組清除 Ready
        .data_o(uart_rx_data),
        .ready_o(uart_rx_ready)
    );    

    // =============================================================================
    // BearCore-V Peripheral Control & Address Decoder
    // =============================================================================

    // --- 1. 內部暫存器定義 ---
    reg [31:0] reg_uart_ie;   // 0x1000_0018 (Bit 1:RX_IE, Bit 0:TX_IE)

    // --- 2. 位址解碼訊號 ---
    // 我們檢查高位址是否為 0x1000xxxx
    wire is_mmio_access = (mem_alu_result[31:16] == 16'h1000);

    // --- 3. 寫入控制 (Peripheral Write) ---
    // 當 mem_we 為 1 且位址正確時，根據偏移量寫入暫存器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_uart_ie   <= 32'h0; // Reset 中斷預設全關
        end else if (mem_mem_wen && mem_valid && mem_is_uart_ie) begin
            reg_uart_ie   <= mem_rs2_data; // 寫入中斷致能
                // 0x04 (Status) 是唯讀的，不處理寫入
                // Timer 部分通常有獨立的 MTIME/MTIMECMP 暫存器邏輯
            
        end
    end

    // --- 4. 觸發 UART 傳送脈衝 ---
    // 當寫入 0x1000_0000 且沒開啟 BIST 時，觸發一次正常的 UART 傳送

    // --- 5. 讀取多路選擇器 (Read Mux) ---
    // 根據位址決定回傳給 CPU 的資料
/*    
    always @(*) begin
        if (is_mmio) begin
            case (mem_addr[7:0])
                8'h00: mem_mmio_rdata = {reg_uart_ctrl[31:8], uart_rx_data_o}; // 資料與模式位元
                8'h04: mem_mmio_rdata = {30'b0, uart_rx_ready_i, uart_tx_busy_i};
                8'h08: mem_mmio_rdata = mtime[31:0];
                8'h0C: mem_mmio_rdata = mtime[63:32];
                8'h10: mem_mmio_rdata = mtimecmp[31:0];
                8'h14: mem_mmio_rdata = mtimecmp[63:32];
                8'h18: mem_mmio_rdata = reg_uart_ie;
                default: mem_mmio_rdata = 32'h0;
            endcase
        end else begin
            mem_mmio_rdata = 32'h0;
        end
    end
*/    



    // 🛡️ 安全機制：當 BIST Mode (Bit 31) 開啟時，自動遮罩中斷防止 CPU 崩潰
    // 將此訊號連往您的 CSR 模組中的 mip[16] (或是自定義的外部中斷位元)

    // --- IF Stage ---

    // =============================================================================
    // 🏆 優化：下一跳 PC 選擇器 (PC Next Multiplexer)
    // =============================================================================

    assign pc_next = (ex_take_branch) ? ex_target_pc : // 🥇 最高優先：EX 階段確定的跳轉/分支
                     (exc_taken)      ? mtvec        : // 🥈 次要優先：例外或中斷跳轉至 mtvec
                     (mret_taken)     ? mepc         : // 🥉 第三優先：從中斷返回至 mepc
                     (pc + 4);                          // 預設：正常執行下一條指令
    wire alu_stall_req;

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
        if (!rst_n || flush) begin 
            id_pc <= 0;
            id_inst <= 32'h00000013; 
            id_valid <= 1'b0; // 🏆 Flush 時清除有效位
        end else if (!stall) begin 
            id_pc <= pc;
            id_inst <= if_inst;
            id_valid <= 1'b1; // 🏆 取指成功
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

    wire timer_irq_trigger = mstatus_mie && mie_reg[7] && timer_int_raw;

    // 🏆 修正：決定正確的 Trap 返回位址
    // 如果 id_valid 為 1，代表 ID 階段有有效指令，返回 id_pc。
    // 如果 id_valid 為 0 (剛被 Flush)，代表我們應該返回目前正在 IF 階段抓取的 pc 位址。
    wire [31:0] trap_ret_pc = (id_valid) ? id_pc : pc;    

    csr_registers u_csr (
        .clk(clk), .rst_n(rst_n),
        .csr_addr(mem_csr_addr), .csr_wdata(csr_wdata), .csr_we(csr_we), .csr_op(mem_csr_op), .csr_use_imm(mem_csr_use_imm),
        .trap_in(exc_taken), .id_pc(trap_ret_pc), .id_exc_cause(exc_cause), .timer_int_raw(timer_int_raw),// 硬體自動存檔 
        .mret_taken(mret_taken), .csr_rdata(csr_rdata), .mtvec(mtvec), .mepc(mepc), .mie_reg(mie_reg), .mstatus_mie(mstatus_mie)
    );

    // 5. 處理例外原因
    always @(*) begin
        if (id_is_illegal) begin
            exc_cause = 32'h00000002;  // 例外：非法指令 (Cause = 2, Bit 31 = 0)
            exc_tval  = id_inst;   // 把錯誤的機器碼存進 tval
        end    
        else if (is_system) begin
            case (id_inst)
                32'h00000073: begin  // ECALL
                    exc_cause = 32'h0000000B;  // 環境調用
                    exc_tval = 32'h0;
                end
                32'h00100073: begin  // EBREAK
                    exc_cause = 32'h00000003;  // 斷點
                    exc_tval = 32'h0;
                end
                default: begin
                    exc_cause = 32'h00000002;  // 例外：非法指令 (Cause = 2, Bit 31 = 0) 
                    exc_tval = id_inst;
                end
            endcase

        end
        // 🏆 新增：處理計時器中斷
        else if (timer_int_final) begin 
            exc_cause = 32'h80000007;  // 中斷：Machine Timer (Bit 31 = 1, Code = 7)
            exc_tval  = 32'h0;
        end 
        else if (uart_int_final) begin // 🥇 這裡是我們新加的！
            exc_cause = 32'h80000010; // 中斷編號 16 (0x10)
            exc_tval  = 32'h0;        
        end else begin
            exc_cause = 32'h0;
            exc_tval = 32'h0;
        end
    end    

    reg_file u_regfile (
        .clk(clk), .raddr1(id_rs1_addr), .rdata1(id_rdata1), .raddr2(id_rs2_addr), 
        .rdata2(id_rdata2), .wen(wb_reg_wen), .waddr(wb_rd_addr), .wdata(wb_write_data),
        .rst_n(rst_n)
    );

    wire load_hazard = (ex_is_load && (ex_rd_addr != 0) && (ex_rd_addr == id_rs1_addr || ex_rd_addr == id_rs2_addr));
    // --- Hazard & EX Stage ---
    always @(*) begin
        stall = load_hazard || alu_stall_req;
    end
    // --- EX Stage ---
    wire final_id_reg_wen = id_reg_wen || id_is_csr;
/*
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush || stall) begin
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
            ex_valid <= 1'b0; // 🏆 Stall 或 Flush 時，向後級傳遞無效信號    
            ex_funct3 <= 3'b0; // 記得清空這個      
        end else begin
            ex_pc <= id_pc; ex_imm <= id_imm; ex_rd_addr <= id_rd_addr;
            ex_rs1_addr <= id_rs1_addr; ex_rs2_addr <= id_rs2_addr;
            ex_funct3 <= id_funct3; ex_alu_op <= id_alu_op; ex_alu_src_b <= id_alu_src_b;
            ex_mem_wen <= id_is_store; ex_reg_wen <= final_id_reg_wen; ex_is_load <= id_is_load;
            ex_is_jal <= id_is_jal; ex_is_jalr <= id_is_jalr; ex_is_branch <= id_is_branch;
            ex_is_lui <= id_is_lui; ex_is_auipc <= id_is_auipc; ex_rdata1 <= id_rdata1; ex_rdata2 <= id_rdata2;
            ex_is_csr <= id_is_csr;
            ex_is_system <= is_system;
            ex_csr_op <= id_csr_op;
            ex_csr_use_imm <= id_csr_use_imm;
            ex_csr_addr <= id_csr_addr;     
            ex_valid <= id_valid; // 🏆 傳遞有效位              
        end
    end
*/
// --- EX Stage (ID/EX Pipeline Register) ---
    always @(posedge clk or negedge rst_n) begin
        // 1. 最高優先級：重置或沖刷 (分支預測錯誤/例外) -> 殺無赦，清空！
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
        
        // 2. 第二優先級：ALU 請求暫停 (除法中) -> 保持原值 (Freeze)！
        // 🏆 關鍵修正：這裡不能清空！要讓 ALU 繼續看到當前的指令！
        end else if (alu_stall_req) begin
            // Do Nothing (Hold values)
            
        // 3. 第三優先級：Load Hazard -> 插入氣泡 (Bubble)
        // ID 階段因為 Load Use 卡住了，所以往 EX 塞一個 NOP
        end else if (load_hazard) begin
            ex_valid <= 1'b0;      // 設為無效
            ex_reg_wen <= 0;       // 禁止寫入暫存器
            ex_mem_wen <= 0;       // 禁止寫入記憶體
            ex_is_branch <= 0;
            ex_is_jal <= 0; ex_is_jalr <= 0;
            // 其他控制訊號最好也歸零，但最重要的是 valid 和 wen
            ex_rd_addr <= 0;
            
        // 4. 正常傳遞 (Normal Operation)
        end else begin
            ex_pc <= id_pc;
            ex_imm <= id_imm; ex_rd_addr <= id_rd_addr;
            ex_rs1_addr <= id_rs1_addr; ex_rs2_addr <= id_rs2_addr;
            ex_funct3 <= id_funct3; ex_alu_op <= id_alu_op;
            ex_alu_src_b <= id_alu_src_b;
            ex_mem_wen <= id_is_store; ex_reg_wen <= final_id_reg_wen; ex_is_load <= id_is_load;
            ex_is_jal <= id_is_jal; ex_is_jalr <= id_is_jalr;
            ex_is_branch <= id_is_branch;
            ex_is_lui <= id_is_lui; ex_is_auipc <= id_is_auipc; ex_rdata1 <= id_rdata1; ex_rdata2 <= id_rdata2;
            ex_is_csr <= id_is_csr;
            ex_is_system <= is_system;
            ex_csr_op <= id_csr_op;
            ex_csr_use_imm <= id_csr_use_imm;
            ex_csr_addr <= id_csr_addr;     
            ex_valid <= id_valid;
        end
    end

    // 計算 MEM 階段的寫回數據（用於前推）\\
    wire [31:0] mem_stage_data =   (mem_is_load) ? mem_final_rdata :
                                (mem_is_jal_jalr) ? mem_pc_plus_4 :
                                (mem_is_csr) ? csr_rdata_forwarded :  // CSR 讀取數據\\
                                mem_alu_result;             // ALU 結果\\    

    // Forwarding
    wire [31:0] fwd_rs1 = (mem_reg_wen && mem_rd_addr != 0 && mem_rd_addr == ex_rs1_addr) ? mem_stage_data  :
                         (wb_reg_wen  && wb_rd_addr  != 0 && wb_rd_addr  == ex_rs1_addr) ? wb_write_data : ex_rdata1;
    wire [31:0] fwd_rs2 = (mem_reg_wen && mem_rd_addr != 0 && mem_rd_addr == ex_rs2_addr) ? mem_stage_data  :
                         (wb_reg_wen  && wb_rd_addr  != 0 && wb_rd_addr  == ex_rs2_addr) ? wb_write_data : ex_rdata2;

    assign alu_in_a_final = (ex_is_auipc) ? ex_pc : fwd_rs1;
    assign ex_alu_in_b    = (ex_alu_src_b) ? ex_imm : fwd_rs2;
    assign rs2_data_final = fwd_rs2;


    alu u_alu ( 
                .clk(clk),
                .rst_n(rst_n),
                .funct3(ex_funct3[2:0]),
                .a(alu_in_a_final), 
                .b(ex_alu_in_b), 
                .alu_op(ex_alu_op), 
                .result(ex_alu_result), 
                .zero(ex_alu_zero), 
                .less(ex_alu_less),
                .stall_req(alu_stall_req));

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
            mem_valid <= 1'b0;       
        end
        else if (alu_stall_req) begin
            // 🏆 新增：當 ALU 暫停時，往 MEM 階段打入氣泡！
            // 這樣才不會誤寫入記憶體或暫存器
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
            mem_valid <= ex_valid; // 🏆 傳遞有效位         
        end
    end

    // 🏆 1. 統一 MMIO 位址解碼 (範圍判斷)
    wire mem_is_mmio = (mem_alu_result >= 32'h10000000 && mem_alu_result < 32'h10000010);

    wire is_ram_addr = (mem_alu_result >= 32'h00010000) && (mem_alu_result <= 32'h0001FFFF);

    wire mem_is_uart_data   = (mem_alu_result == 32'h10000000); 
    wire mem_is_uart_status = (mem_alu_result == 32'h10000004); 
    wire mem_is_cycle_cnt   = (mem_alu_result == 32'h10000008); 
    wire mem_is_inst_cnt    = (mem_alu_result == 32'h1000000C); 
    wire mem_is_uart_ie     = (mem_alu_result == 32'h10000018);
    
    // 🏆 2. 周邊裝置實例化
    wire [31:0] mem_ram_rdata;

    wire actual_ram_wen = mem_mem_wen && is_ram_addr;
    // 只有位址不在 MMIO 範圍時，才允許寫入 Data RAM [cite: 45]
    data_ram u_ram (
        .clk(clk), 
        .wen(actual_ram_wen), 
        .addr(mem_alu_result), 
        .wdata(mem_rs2_data), 
        .funct3(mem_funct3),  // 🏆 新增：傳遞操作類型
        .rdata(mem_ram_rdata)
    ); 

    // 1. 定義「純粹的寫入位址觸發」訊號 (不管寫入什麼內容)
    wire uart_reg_write = mem_mem_wen && mem_is_uart_data && mem_valid;

    // 2. 定義「真正的 8-bit 資料發送」訊號 (只有在測試位元為 0 時才發送)
    wire uart_real_tx_en = uart_reg_write && (mem_rs2_data[31:30] == 2'b00);

    // 🏆 修改 3：更新測試暫存器的時機 (改用 uart_reg_write)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_test_en <= 1'b0;
            rx_test_en <= 1'b0;
        end else if (uart_reg_write) begin // 🚀 這裡不能過濾 Bit 30/31，否則設定不進去！
            tx_test_en <= mem_rs2_data[31]; 
            rx_test_en <= mem_rs2_data[30]; 
        end
    end    
/*
    wire uart_tx_start = mem_mem_wen && mem_valid && is_mmio_access && 
                         (mem_alu_result[7:0] == 8'h00) && !reg_uart_ctrl[31];
*/
    uart_tx #(  .CLK_FREQ(100000000),
                .BAUD_RATE(1152000)  // 🏆 新增這行，與 tb_top.v 一致
    ) u_uart(
        .clk(clk), .rst_n(rst_n), 
        .data_i(mem_rs2_data[7:0]), .valid_i(uart_real_tx_en), //uart_real_tx_en
        .busy_o(uart_busy), .tx_o(uart_tx_o), .test_mode_i(tx_test_en)
    ); 

    // 🏆 3. 效能計數器累加邏輯 (只保留一組)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin 
            cycle_cnt <= 0; inst_cnt  <= 0; 
        end else begin 
            cycle_cnt <= cycle_cnt + 1;
            // 🏆 最終嚴謹判斷：只有成功到達 WB 階段且有效位為高的指令才計數
            if (wb_valid) begin

                inst_cnt <= inst_cnt + 1;
            end
        end
    end



    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtimecmp <= 64'hFFFFFFFF_FFFFFFFF; // 預設設為最大值，防止一啟動就中斷
        end else if (mem_mem_wen && mem_valid) begin // 🏆 只有在 Store 指令有效時寫入
            if (mem_is_mtimecmp_l)
                mtimecmp[31:0]  <= mem_rs2_data;
            else if (mem_is_mtimecmp_h)
                mtimecmp[63:32] <= mem_rs2_data;
        end
    end    

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            mtime <= 64'b0;
        else 
            mtime <= mtime + 1'b1; // 每個時鐘週期加 1
    end

    // 🏆 4. 讀取資料多工器 (決定 CPU 讀到什麼)
    reg [31:0] mem_final_rdata;
    assign is_rom_data_access = (mem_alu_result >= 32'h00000000 && mem_alu_result < 32'h00010000);

    always @(*) begin
        if (mem_is_uart_status) begin
            mem_final_rdata = {30'b0, uart_rx_ready, uart_busy};
        end else if (mem_alu_result == 32'h10000000) begin
            mem_final_rdata = {24'b0, uart_rx_data}; 
        end else if (mem_alu_result == 32'h10000008) begin
            mem_final_rdata = mtime[31:0];
        end
        // 🏆 讀取 mtime 高 32 位元 (0x1000000C)
        else if (mem_alu_result == 32'h1000000C) begin
            mem_final_rdata = mtime[63:32];
        end else if (mem_alu_result == 32'h10000010) begin // mtimecmp_l
            mem_final_rdata = mtimecmp[31:0];
        end else if (mem_alu_result == 32'h10000014) begin // mtimecmp_h
            mem_final_rdata = mtimecmp[63:32];
        end else if (mem_alu_result == 32'h10000018) begin
            mem_final_rdata = reg_uart_ie; // 🥇 讓軟體能讀回中斷開關狀態
        end else if (mem_is_csr) begin                   
            mem_final_rdata = csr_rdata; // 🏆 關鍵：把 CSR 值放進來            
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
            wb_valid  <= 1'b0;      
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
            wb_valid <= mem_valid; // 🏆 傳遞有效位         
        end
    end

    wire [31:0] csr_rdata_forwarded = (mem_is_csr && csr_we && mem_csr_addr == wb_csr_addr) ? csr_wdata : csr_rdata;

    assign wb_write_data = (wb_is_jal_jalr) ? wb_pc_plus_4 : 
                        (wb_is_load || wb_is_csr) ? wb_ram_rdata : 
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



endmodule