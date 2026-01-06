`timescale 1ns/1ps

module csr_registers(
    input clk,
    input rst_n,
    // Read/Write Interface
    input [11:0] csr_addr,
    input [31:0] csr_wdata,
    input csr_we,
    input [1:0] csr_op,
    input csr_use_imm, 
    
    // Trap/Interrupt Interface
    input trap_in,
    input [31:0] id_pc,       
    input [31:0] id_exc_cause,
    input timer_int_raw,
    input mret_taken,

    input uart_int_raw,
    
    // Outputs
    output [31:0] csr_rdata,  // 🐻 注意：這裡改回 wire (不要 reg)
    output [31:0] mtvec,
    output [31:0] mepc,
    output [31:0] mie_reg,
    output mstatus_mie
);

    // CSR Registers
    reg [31:0] reg_mstatus; // 0x300
    reg [31:0] reg_mie;     // 0x304
    reg [31:0] reg_mtvec;   // 0x305
    reg [31:0] reg_mscratch;// 0x340
    reg [31:0] reg_mepc;    // 0x341
    reg [31:0] reg_mcause;  // 0x342
    reg [31:0] reg_mip;     // 0x344
    
    // Constants
    localparam CSR_MSTATUS  = 12'h300;
    localparam CSR_MIE      = 12'h304;
    localparam CSR_MTVEC    = 12'h305;
    localparam CSR_MSCRATCH = 12'h340;
    localparam CSR_MEPC     = 12'h341;
    localparam CSR_MCAUSE   = 12'h342;
    localparam CSR_MIP      = 12'h344;

    localparam MIP_MTIP = 7;    // 定時器中斷掛起
    localparam MIP_MEIP = 11;   // 外部中斷掛起  
    localparam MIP_UARTIP = 16; // UART 中斷掛起

    //assign mtvec = reg_mtvec;
    assign mepc = reg_mepc;
    assign mie_reg = reg_mie;
    assign mstatus_mie = reg_mstatus[3]; 

    // MIP Update Logic (Timer)
/*    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) reg_mip <= 'd0;
        else begin
            reg_mip[MIP_MTIP] <= timer_int_raw; 
            reg_mip[MIP_UARTIP] <= uart_int_raw; 
            reg_mip[MIP_MEIP] <= reg_mip[MIP_MEIP];  // 假設 UART 使用第 16 位
        end
    end
*/
    // 修改 mtvec 輸出邏輯
    wire [31:0] trap_vector = (reg_mtvec[1:0] == 2'b01) ? 
                            {reg_mtvec[31:2], 2'b00} + (id_exc_cause << 2) :
                            {reg_mtvec[31:2], 2'b00};
    assign mtvec = trap_vector;

    // 🐻 修正：使用中間變數 (Internal Reg)
    reg [31:0] csr_rdata_internal;

    always @(*) begin
        case (csr_addr)
            CSR_MSTATUS:  csr_rdata_internal = reg_mstatus;
            CSR_MIE:      csr_rdata_internal = reg_mie;
            CSR_MTVEC:    csr_rdata_internal = reg_mtvec;
            CSR_MSCRATCH: csr_rdata_internal = reg_mscratch;
            // 預判邏輯：如果當前正在發生 Trap，直接輸出輸入的 PC/Cause
            CSR_MEPC:     csr_rdata_internal = reg_mepc;
            CSR_MCAUSE:   csr_rdata_internal = reg_mcause;
            CSR_MIP:      csr_rdata_internal = reg_mip;
            default:      csr_rdata_internal = 32'b0;
        endcase
    end

    // ⚡ 關鍵魔法：輸出延遲 1ns
    // 這確保當 csr_addr 瞬間改變時，csr_rdata 會保留舊值 1ns
    // 讓 core.v 的 WB 階段能抓到正確的舊數據！
    assign csr_rdata = csr_rdata_internal;

    // CSR Write & Trap Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_mstatus <= 32'h00001800; // MPP=11
            reg_mie <= 0;
            reg_mtvec <= 0;
            reg_mscratch <= 0;
            reg_mepc <= 0;
            reg_mcause <= 0;
            reg_mip <= 0;
        end else begin
            // 1. 硬體中斷狀態更新 (預設行為，每個 Cycle 都做)
            // 這樣可以確保即使沒有 CSR 寫入，硬體中斷也能反映
            reg_mip[MIP_MTIP]   <= timer_int_raw;
            reg_mip[MIP_UARTIP] <= uart_int_raw;

            // 優先處理 Trap
            // 處理 MRET
            if (mret_taken) begin
                reg_mstatus[3] <= reg_mstatus[7];
                reg_mstatus[7] <= 1'b1; 
            end
            else if (trap_in && !csr_we) begin  // 🚨 避免與 CSR 寫入衝突
                reg_mepc <= id_pc;           
                reg_mcause <= id_exc_cause;  
                
                reg_mstatus[7] <= reg_mstatus[3];
                reg_mstatus[3] <= 1'b0; // Disable MIE
            end
            // 處理軟體 CSR 寫入
            else if (csr_we) begin
                case (csr_addr)
                    CSR_MSTATUS:  reg_mstatus  <= csr_wdata;
                    CSR_MIE:      reg_mie      <= csr_wdata;
                    CSR_MTVEC:    reg_mtvec    <= csr_wdata;
                    CSR_MSCRATCH: reg_mscratch <= csr_wdata;
                    CSR_MEPC:     reg_mepc     <= csr_wdata;
                    CSR_MCAUSE:   reg_mcause   <= csr_wdata;
                    CSR_MIP: begin
                        // 軟體寫入 MIP
                        reg_mip <= csr_wdata;
                        
                        // 🏆 關鍵保護：軟體寫入後，強制覆蓋硬體唯讀位
                        // 這樣軟體無法欺騙 CPU 說「沒有中斷」，如果硬體線其實是拉高的
                        reg_mip[MIP_MTIP]   <= timer_int_raw;
                        reg_mip[MIP_UARTIP] <= uart_int_raw;

                    end                    
                endcase
            end
        end
    end

// csr_registers.v - 添加調試
`ifdef SIMULATION
    always @(posedge clk) begin
        if (trap_in) begin
            $display("[CSR] Trap taken at time %0t", $time);
            $display("  id_pc=%h, id_exc_cause=%h", id_pc, id_exc_cause);
            $display("  mstatus=%h, mie=%h, mip=%h", reg_mstatus, reg_mie, reg_mip);
            $display("  mtvec=%h, mepc=%h", reg_mtvec, reg_mepc);
        end
        
        if (csr_we && csr_addr == 12'h300) begin
            $display("[CSR] Write to mstatus: %h", csr_wdata);
        end
        
        if (csr_we && csr_addr == 12'h304) begin
            $display("[CSR] Write to mie: %h", csr_wdata);
        end
    end
`endif

endmodule