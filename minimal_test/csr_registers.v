// src/csr_registers.v
module csr_registers(
    input clk,
    input rst_n,
    
    // CSR 存取接口
    input [11:0] csr_addr,
    input [31:0] csr_wdata,
    input csr_we,
    input [1:0] csr_op,      // 操作類型：00=CSRRW, 01=CSRRS, 10=CSRRC
    input csr_use_imm,       // 是否使用立即數
    
    // 例外和中斷處理
    input [31:0] pc,         // 當前 PC（用於例外）
    input exc_taken,         // 例外發生
    input [3:0] exc_cause,   // 例外原因
    input [31:0] exc_tval,   // 例外附加信息
    input mret_taken,        // MRET 指令執行
    
    // 輸出
    output reg [31:0] csr_rdata,
    output reg [31:0] mtvec,   // 例外向量基地址
    output reg [31:0] mepc,    // 例外程序計數器
    output reg mie,            // 全局中斷使能
    output timer_int,          // 定時器中斷
    output ext_int             // 外部中斷
);

    // 🏆 主要 CSR 定義
    reg [31:0] mstatus;   // 0x300 - 機器模式狀態寄存器
    reg [31:0] misa;      // 0x301 - 指令集架構信息
    reg [31:0] mie_r;     // 0x304 - 機器模式中斷使能
    reg [31:0] mtvec_r;   // 0x305 - 機器模式例外向量基地址
    reg [31:0] mscratch;  // 0x340 - 機器模式暫存寄存器
    reg [31:0] mepc_r;    // 0x341 - 機器模式例外PC
    reg [31:0] mcause;    // 0x342 - 機器模式例外原因
    reg [31:0] mtval;     // 0x343 - 機器模式例外值
    reg [31:0] mip;       // 0x344 - 機器模式中斷等待
    
    // 🏆 定時器 CSR（自定義）
    reg [63:0] mtime;     // 0x700 - 機器時間計數器
    reg [63:0] mtimecmp;  // 0x704 - 機器時間比較寄存器
    
    // 🏆 中斷信號
    assign timer_int = (mtime >= mtimecmp) && (mie_r[7]);  // MTIE 位元
    assign ext_int = mip[11] && mie_r[11];                 // MEIE 位元

    // 🏆 CSR 讀取邏輯
    always @(*) begin
        case (csr_addr)
            // 標準 CSR
            12'h300: csr_rdata = mstatus;
            12'h301: csr_rdata = misa;
            12'h304: csr_rdata = mie_r;
            12'h305: csr_rdata = mtvec_r;
            12'h340: csr_rdata = mscratch;
            12'h341: csr_rdata = mepc_r;
            12'h342: csr_rdata = mcause;
            12'h343: csr_rdata = mtval;
            12'h344: csr_rdata = mip;
            
            // 自定義 CSR（定時器）
            12'h700: csr_rdata = mtime[31:0];      // mtime 低32位
            12'h701: csr_rdata = mtime[63:32];     // mtime 高32位
            12'h704: csr_rdata = mtimecmp[31:0];   // mtimecmp 低32位
            12'h705: csr_rdata = mtimecmp[63:32];  // mtimecmp 高32位
            
            default: csr_rdata = 32'h0;
        endcase
/*
        if (csr_addr == 12'h301 || csr_addr == 12'h340) begin
            $display("[CSR-DEBUG] Read: addr=0x%h, data=0x%h", csr_addr, csr_rdata);
        end
*/                
    end

    reg [31:0] write_val;


    // 🏆 CSR 寫入邏輯
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 初始化 CSR 寄存器
            mstatus <= 32'h0;
            misa <= 32'h40000100;  // RV32I + M 擴展
            mie_r <= 32'h0;
            mtvec_r <= 32'h100;    // 例外向量地址 0x100
            mscratch <= 32'h0;
            mepc_r <= 32'h0;
            mcause <= 32'h0;
            mtval <= 32'h0;
            mip <= 32'h0;
            
            // 初始化定時器
            mtime <= 64'h0;
            mtimecmp <= 64'hFFFFFFFFFFFFFFFF;

//            $display("[CSR-DEBUG] Initialized: MISA=0x%h, MSCRATCH=0x%h", misa, mscratch);

        end else begin
            // 🏆 更新定時器
            mtime <= mtime + 64'h1;
            
            // 🏆 處理例外
            if (exc_taken) begin
                // 保存例外信息
                mepc_r <= pc;
                mcause <= {28'h0, exc_cause};
                mtval <= exc_tval;
                
                // 更新 mstatus
                mstatus[3] <= mstatus[7];  // MPP = MIE
                mstatus[7] <= 1'b0;        // 清除 MIE
                mstatus[12] <= mstatus[12]; // MPIE 保持不變
            end
            
            // 🏆 處理 MRET
            if (mret_taken) begin
                // 恢復中斷使能
                mstatus[7] <= mstatus[12];  // MIE = MPIE
                mstatus[12] <= 1'b1;        // MPIE = 1
            end
            
            // 🏆 CSR 寫入操作
            if (csr_we) begin
//                $display("[CSR-DEBUG] Write: addr=0x%h, data=0x%h, op=%b", csr_addr, csr_wdata, csr_op);                
                
                // 計算寫入值
                case (csr_op)
                    2'b00: write_val = csr_wdata;                    // CSRRW
                    2'b01: write_val = csr_rdata | csr_wdata;       // CSRRS
                    2'b10: write_val = csr_rdata & ~csr_wdata;      // CSRRC
                    default: write_val = csr_wdata;
                endcase
                
                // 寫入特定 CSR
                case (csr_addr)
                    12'h300: mstatus <= write_val;
                    12'h304: mie_r <= write_val;
                    12'h305: mtvec_r <= write_val & 32'hFFFFFFFC;  // 對齊到4字節
                    12'h340: mscratch <= write_val;
                    12'h341: mepc_r <= write_val & 32'hFFFFFFFC;   // 對齊到4字節
                    12'h342: mcause <= write_val;
                    12'h343: mtval <= write_val;
                    12'h344: mip <= write_val;
                    
                    // 定時器 CSR
                    12'h700: mtime[31:0] <= write_val;
                    12'h701: mtime[63:32] <= write_val;
                    12'h704: mtimecmp[31:0] <= write_val;
                    12'h705: mtimecmp[63:32] <= write_val;
                endcase
            end
        end
    end

    always @(posedge clk) begin
        if (csr_we && csr_addr == 12'h340) begin
            $display("[CSR-WRITE-DEBUG] Writing to MSCRATCH: data=0x%h", csr_wdata);
        end
    end   

    // 🏆 持續輸出
    always @(*) begin
        mtvec = mtvec_r;
        mepc = mepc_r;
        mie = mstatus[3];  // MIE 位元
    end

endmodule