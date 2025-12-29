module csr_registers(
    input clk,
    input rst_n,
    
    // 軟體存取接口
    input [11:0] csr_addr,
    input [31:0] csr_wdata,
    input csr_we,
    input [1:0] csr_op,
    input csr_use_imm,
    
    // 🏆 硬體自動存檔接口 (由 core.v 傳入)
    input trap_in,
    input [31:0] id_pc,
    input [31:0] id_exc_cause,
    input mret_taken,
    input timer_int_raw,   // 🏆 新增：由 core.v 傳入的 (mtime >= mtimecmp) 訊號
    
    // 輸出
    output reg [31:0] csr_rdata,
    output [31:0] mtvec,
    output [31:0] mepc,
    output [31:0] mie_reg, // 🏆 輸出整個 mie 暫存器給 core.v 做判斷
    output mstatus_mie     // 🏆 全球中斷總開關 (mstatus[3])
);
    // CSR 暫存器定義
    reg [31:0] reg_mepc;
    reg [31:0] reg_mcause;
    reg [31:0] reg_mtvec;
    reg [31:0] reg_mstatus;
    reg [31:0] reg_mscratch;
    reg [31:0] reg_mie;    // 🏆 新增：Machine Interrupt Enable
    reg [31:0] reg_mip;    // 🏆 新增：Machine Interrupt Pending

    assign mepc  = reg_mepc;
    assign mtvec = reg_mtvec;
    assign mie_reg = reg_mie;      // 把整個開關表送出去
    assign mstatus_mie = reg_mstatus[3]; // 總開關在第 3 位元 

    // 🏆 調試：監視寫入操作

    // 🏆 核心邏輯：處理硬體 Trap 與 軟體寫入
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_mepc    <= 32'h0;
            reg_mcause  <= 32'h0;
            reg_mstatus <= 32'h0;
            reg_mtvec   <= 32'h00000100; // 預設為向量表位址
            reg_mscratch <= 32'h0;
            reg_mie     <= 32'h0;
            reg_mip     <= 32'h0;
        end 
        // A. 優先處理硬體例外 (Trap)
        else begin 
            reg_mip[7] <= timer_int_raw;

            if (trap_in) begin
                reg_mepc   <= id_pc;         // 🏆 存入發生例外的 PC
                reg_mcause <= id_exc_cause;  // 🏆 存入例外原因
                // 更新 mstatus (例如關閉中斷)
                reg_mstatus[7] <= reg_mstatus[3]; // MPIE = MIE
                reg_mstatus[3] <= 1'b0;           // MIE = 0
            end 
            // B. 處理 MRET 返回
            else if (mret_taken) begin
                reg_mstatus[3] <= reg_mstatus[7]; // MIE = MPIE
                reg_mstatus[7] <= 1'b1;           // MPIE = 1
            end
            // C. 處理軟體 CSRW 指令
            else if (csr_we) begin
                case (csr_addr)
                    12'h300: begin 
                        reg_mstatus <= csr_wdata;
                    end
                    12'h304: reg_mie     <= csr_wdata; // 🏆 地址 0x304 是 mie                    
                    12'h305: reg_mtvec    <= csr_wdata;
                    12'h340: reg_mscratch <= csr_wdata;
                    12'h341: reg_mepc     <= csr_wdata;
                    // 🏆 禁止軟體寫入 mcause，只允許硬體例外寫入
                    // 12'h342: reg_mcause   <= csr_wdata;
                    12'h344: reg_mip[7]  <= csr_wdata[7];                    
                    default: begin end
                endcase
            end
        end
    end

    // 讀取邏輯
    always @(*) begin
        case (csr_addr)
            12'h300: csr_rdata = reg_mstatus;
            12'h304: csr_rdata = reg_mie;     // 🏆            
            12'h305: csr_rdata = reg_mtvec;
            12'h340: csr_rdata = reg_mscratch;
            12'h341: csr_rdata = reg_mepc;
            12'h342: csr_rdata = reg_mcause;
            12'h344: csr_rdata = reg_mip;     // 🏆 地址 0x344 是 mip            
            default: csr_rdata = 32'h0;
        endcase


        // 🏆 調試：監視CSR讀取    
    end


endmodule