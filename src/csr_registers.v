`timescale 1ns/1ps

// =============================================================================
// 控制與狀態暫存器模組 (CSR Registers)
// 功能：
// 1. 實現 RISC-V 標準 CSR 暫存器
// 2. 支援中斷與例外處理
// 3. 實現特權模式切換
// 4. 支援計時器中斷與 UART 中斷
// =============================================================================
module csr_registers (
    // 時脈與重置訊號
    input  wire        clk_i,                     // 時脈輸入
    input  wire        reset_ni,                  // 低態有效重置
    
    // CSR 讀寫介面
    input  wire [11:0] csr_address_i,             // CSR 地址
    input  wire [31:0] csr_write_data_i,          // CSR 寫入資料
    input  wire        csr_write_enable_i,        // CSR 寫入使能
    input  wire [1:0]  csr_operation_i,           // CSR 操作類型
    input  wire        csr_use_immediate_i,       // CSR 使用立即數
    
    // 中斷與例外處理介面
    input  wire        trap_trigger_i,            // 陷阱觸發訊號
    input  wire [31:0] trap_program_counter_i,    // 陷阱發生時的 PC
    input  wire [31:0] trap_cause_i,              // 陷阱原因
    input  wire        timer_interrupt_raw_i,     // 原始計時器中斷
    input  wire        uart_interrupt_raw_i,      // 原始 UART 中斷
    input  wire        machine_return_taken_i,    // MRET 指令執行標誌
    
    // CSR 讀取輸出
    output wire [31:0] csr_read_data_o,           // CSR 讀取資料
    
    // 特殊 CSR 暫存器輸出
    output wire [31:0] machine_trap_vector_o,     // mtvec (陷阱向量地址)
    output wire [31:0] machine_exception_pc_o,    // mepc (例外返回地址)
    output wire [31:0] machine_interrupt_enable_o, // mie (中斷使能暫存器)
    output wire        machine_status_interrupt_enable_o // mstatus.mie 位元
);
    
    // ============================
    // 1. CSR 地址常數定義
    // ============================
    localparam CSR_ADDR_MSTATUS  = 12'h300;  // 機器模式狀態暫存器
    localparam CSR_ADDR_MIE      = 12'h304;  // 機器模式中斷使能
    localparam CSR_ADDR_MTVEC    = 12'h305;  // 機器模式陷阱向量
    localparam CSR_ADDR_MSCRATCH = 12'h340;  // 機器模式暫存暫存器
    localparam CSR_ADDR_MEPC     = 12'h341;  // 機器模式例外程式計數器
    localparam CSR_ADDR_MCAUSE   = 12'h342;  // 機器模式例外原因
    localparam CSR_ADDR_MIP      = 12'h344;  // 機器模式中斷掛起
    
    // ============================
    // 2. 中斷位元位置定義
    // ============================
    localparam MIP_BIT_MTIMER = 7;     // 機器模式計時器中斷位
    localparam MIP_BIT_MEI    = 11;    // 機器模式外部中斷位
    localparam MIP_BIT_UART   = 16;    // UART 中斷位 (自定義)
    
    // ============================
    // 3. CSR 暫存器宣告
    // ============================
    reg [31:0] reg_mstatus;     // 0x300: 機器模式狀態
    reg [31:0] reg_mie;         // 0x304: 機器模式中斷使能
    reg [31:0] reg_mtvec;       // 0x305: 機器模式陷阱向量
    reg [31:0] reg_mscratch;    // 0x340: 機器模式暫存暫存器
    reg [31:0] reg_mepc;        // 0x341: 機器模式例外程式計數器
    reg [31:0] reg_mcause;      // 0x342: 機器模式例外原因
    reg [31:0] reg_mip;         // 0x344: 機器模式中斷掛起
    
    // ============================
    // 4. 內部訊號宣告
    // ============================
    reg [31:0] csr_read_data_internal_r;  // 內部 CSR 讀取資料暫存器
    
    // ============================
    // 5. 陷阱向量計算
    // ============================
    // 根據 mtvec 的模式位元選擇陷阱向量地址
    wire [31:0] trap_vector_w = 
        (reg_mtvec[1:0] == 2'b01) ?  // 向量模式
        {reg_mtvec[31:2], 2'b00} + (trap_cause_i << 2) :  // 向量偏移
        {reg_mtvec[31:2], 2'b00};                         // 直接模式
    
    assign machine_trap_vector_o = trap_vector_w;
    assign machine_exception_pc_o = reg_mepc;
    assign machine_interrupt_enable_o = reg_mie;
    assign machine_status_interrupt_enable_o = reg_mstatus[3]; // mstatus.mie
    
    // ============================
    // 6. CSR 讀取邏輯 (組合邏輯)
    // ============================
    always @(*) begin
        case (csr_address_i)
            CSR_ADDR_MSTATUS:  csr_read_data_internal_r = reg_mstatus;
            CSR_ADDR_MIE:      csr_read_data_internal_r = reg_mie;
            CSR_ADDR_MTVEC:    csr_read_data_internal_r = reg_mtvec;
            CSR_ADDR_MSCRATCH: csr_read_data_internal_r = reg_mscratch;
            CSR_ADDR_MEPC:     csr_read_data_internal_r = reg_mepc;
            CSR_ADDR_MCAUSE:   csr_read_data_internal_r = reg_mcause;
            CSR_ADDR_MIP:      csr_read_data_internal_r = reg_mip;
            default:           csr_read_data_internal_r = 32'b0;  // 未定義 CSR
        endcase
    end
    
    // 輸出 CSR 讀取資料 (添加延遲以匹配時序)
    assign csr_read_data_o = csr_read_data_internal_r;
    
    // ============================
    // 7. CSR 寫入與陷阱處理邏輯 (時序邏輯)
    // ============================
    always @(posedge clk_i or negedge reset_ni) begin
        if (!reset_ni) begin
            // --------------------------------------------------
            // 重置初始化
            // --------------------------------------------------
            reg_mstatus <= 32'h00001800;  // MPP=11 (機器模式)
            reg_mie <= 32'h0;             // 禁用所有中斷
            reg_mtvec <= 32'h0;           // 陷阱向量地址為 0
            reg_mscratch <= 32'h0;        // 暫存暫存器清零
            reg_mepc <= 32'h0;            // 例外返回地址清零
            reg_mcause <= 32'h0;          // 例外原因清零
            reg_mip <= 32'h0;             // 中斷掛起暫存器清零
        end else begin    
            // --------------------------------------------------
            // 優先級 1: 處理 MRET 指令 (從例外返回)
            // --------------------------------------------------
            if (machine_return_taken_i) begin
                // 恢復中斷使能狀態
                reg_mstatus[3] <= reg_mstatus[7];  // mstatus.mie = mstatus.mpie
                reg_mstatus[7] <= 1'b1;            // mstatus.mpie = 1
            end
            // --------------------------------------------------
            // 優先級 2: 處理陷阱觸發 (避免與 CSR 寫入衝突)
            // --------------------------------------------------
            else if (trap_trigger_i && !csr_write_enable_i) begin
                // 保存例外返回地址
                reg_mepc <= trap_program_counter_i;
                
                // 保存例外原因
                reg_mcause <= trap_cause_i;
                
                // 保存並禁用中斷
                reg_mstatus[7] <= reg_mstatus[3];  // mstatus.mpie = mstatus.mie
                reg_mstatus[3] <= 1'b0;            // mstatus.mie = 0 (禁用中斷)
            end
            // --------------------------------------------------
            // 優先級 3: 處理軟體 CSR 寫入
            // --------------------------------------------------
            else if (csr_write_enable_i) begin
                case (csr_address_i)
                    CSR_ADDR_MSTATUS:  reg_mstatus <= csr_write_data_i;
                    CSR_ADDR_MIE:      reg_mie <= csr_write_data_i;
                    CSR_ADDR_MTVEC:    reg_mtvec <= csr_write_data_i;
                    CSR_ADDR_MSCRATCH: reg_mscratch <= csr_write_data_i;
                    CSR_ADDR_MEPC:     reg_mepc <= csr_write_data_i;
                    CSR_ADDR_MCAUSE:   reg_mcause <= csr_write_data_i;
                    CSR_ADDR_MIP: begin
                        // 軟體寫入 MIP
                        reg_mip <= csr_write_data_i;
                    end
                endcase
            end

            // --------------------------------------------------
            // 硬體中斷狀態更新 (每個時脈週期更新)
            // --------------------------------------------------
            reg_mip[MIP_BIT_MTIMER] <= timer_interrupt_raw_i;   // 計時器中斷
            reg_mip[MIP_BIT_UART] <= uart_interrupt_raw_i;      // UART 中斷            
        end
    end
    
    // ============================
    // 8. 模擬調試區塊 (僅在模擬時生效)
    // ============================
`ifdef SIMULATION
    always @(posedge clk_i) begin
        // 監控 CSR 寫入
        if (csr_write_enable_i) begin
            case (csr_address_i)
                CSR_ADDR_MSTATUS: 
                    $display("[CSR WRITE] mstatus <= 0x%08h", csr_write_data_i);
                CSR_ADDR_MIE:
                    $display("[CSR WRITE] mie <= 0x%08h (MTIE=%b)", csr_write_data_i, csr_write_data_i[7]);
                CSR_ADDR_MTVEC:
                    $display("[CSR WRITE] mtvec <= 0x%08h", csr_write_data_i);
                CSR_ADDR_MEPC:
                    $display("[CSR WRITE] mepc <= 0x%08h", csr_write_data_i);
                CSR_ADDR_MCAUSE:
                    $display("[CSR WRITE] mcause <= 0x%08h", csr_write_data_i);
            endcase
        end
        
        // 監控陷阱處理
        if (trap_trigger_i) begin
            $display("[TRAP] Time=%0t, PC=0x%08h, Cause=0x%08h", 
                    $time, trap_program_counter_i, trap_cause_i);
            $display("[TRAP] mtvec=0x%08h, mepc=0x%08h", reg_mtvec, reg_mepc);
        end
        
        if (machine_return_taken_i) begin
            $display("[MRET] Return to PC=0x%08h", reg_mepc);
        end
    end
`endif
    
endmodule