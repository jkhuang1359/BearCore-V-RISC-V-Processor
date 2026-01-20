// include/riscv_defines.vh
// 版本: 1.0 - 為 BearCore-V 專案設計

// =============================================================================
// 核心配置參數
// =============================================================================
`ifndef BEARCORE_CONFIG
`define BEARCORE_CONFIG

// 資料位元寬度
`define DATA_WIDTH       32
`define ADDR_WIDTH       32
`define INST_WIDTH       32

// 架構特性啟用（根據您的實現逐步開啟）
`define ENABLE_M_EXTENSION   1  // 乘除法擴展
`define ENABLE_F_EXTENSION   1  // 浮點擴展（正在開發中）
`define ENABLE_ZICSR         1  // CSR指令
`define ENABLE_ZIFENCEI      0  // 快取同步（暫不支援）

// 記憶體配置（根據您的 link.ld 調整）
`define ROM_BASE_ADDR    32'h0000_0000
`define ROM_SIZE         32'h0002_0000  // 128KB
`define RAM_BASE_ADDR    32'h0002_0000
`define RAM_SIZE         32'h0002_0000  // 128KB

`endif // BEARCORE_CONFIG

// =============================================================================
// 指令操作碼（RISC-V Standard）
// =============================================================================
`ifndef RV_OPCODES
`define RV_OPCODES

// 基礎整數指令集
`define OPCODE_LUI       7'b0110111 // 載入高位立即數
`define OPCODE_AUIPC     7'b0010111 // PC + 高位立即數
`define OPCODE_JAL       7'b1101111 // 跳躍並連結
`define OPCODE_JALR      7'b1100111 // 暫存器跳躍並連結
`define OPCODE_BRANCH    7'b1100011 // 分支指令
`define OPCODE_LOAD      7'b0000011 // 整數載入指令
`define OPCODE_STORE     7'b0100011 // 整數儲存指令
`define OPCODE_IMM       7'b0010011 // 立即數運算
`define OPCODE_REG       7'b0110011 // 暫存器運算
`define OPCODE_SYSTEM    7'b1110011 // 系統指令 (包含 CSR)

// 浮點擴展（根據您的FPU實作進度逐步加入）
`define OPCODE_LOAD_FP   7'b0000111 // 浮點載入
`define OPCODE_STORE_FP  7'b0100111 // 浮點儲存
`define OPCODE_OP_FP     7'b1010011 // 浮點運算
// 融合乘加指令（可以稍後實作）
`define OPCODE_FMADD     7'b1000011 // 融合乘加
`define OPCODE_FMSUB     7'b1000111 // 融合乘減
`define OPCODE_FNMSUB    7'b1001011 // 負融合乘減
`define OPCODE_FNMADD    7'b1001111 // 負融合乘加

`endif // RV_OPCODES

// =============================================================================
// ALU 操作定義
// =============================================================================
`ifndef RV_ALU_OPS
`define RV_ALU_OPS

// 基本ALU操作
`define ALU_OP_ADD       4'b0000    // 加法
`define ALU_OP_SUB       4'b1000    // 減法
`define ALU_OP_SLL       4'b0001    // 邏輯左移
`define ALU_OP_SLT       4'b0010    // 有符號小於比較
`define ALU_OP_SLTU      4'b0011    // 無符號小於比較
`define ALU_OP_XOR       4'b0100    // 邏輯互斥或
`define ALU_OP_SRL       4'b0101    // 邏輯右移
`define ALU_OP_SRA       4'b1101    // 算術右移
`define ALU_OP_OR        4'b0110    // 邏輯或
`define ALU_OP_AND       4'b0111    // 邏輯與

// 乘除法擴展（M擴展）
`ifdef ENABLE_M_EXTENSION
`define ALU_OP_MUL       4'b1001    // 乘法 (低32位)
`define ALU_OP_MULH      4'b1010    // 乘法 (高32位，有符號×有符號)
`define ALU_OP_MULHSU    4'b1011    // 乘法 (高32位，有符號×無符號)
`define ALU_OP_MULHU     4'b1100    // 乘法 (高32位，無符號×無符號)
`define ALU_OP_DIV       4'b1110    // 除法
`define ALU_OP_DIVU      4'b1101
`define ALU_OP_REM       4'b1111    // 餘數
`define ALU_OP_REMU      4'b1111
`endif

`endif // RV_ALU_OPS

// =============================================================================
// FPU 操作定義（正在整合中）
// =============================================================================
`ifdef ENABLE_F_EXTENSION
`ifndef RV_FPU_OPS
`define RV_FPU_OPS

// 浮點操作碼
`define OPCODE_LOAD_FP   7'b0000111 // 浮點載入
`define OPCODE_STORE_FP  7'b0100111 // 浮點儲存
`define OPCODE_FMADD     7'b1000011 // 融合乘加
`define OPCODE_FMSUB     7'b1000111 // 融合乘減
`define OPCODE_FNMSUB    7'b1001011 // 負融合乘減
`define OPCODE_FNMADD    7'b1001111 // 負融合乘加
`define OPCODE_OP_FP     7'b1010011 // 浮點運算

// 浮點操作（R-type funct5欄位）
`define FP_OP_FADD       3'b000  // 浮點加法
`define FP_OP_FSUB       3'b001  // 浮點減法
`define FP_OP_FMUL       3'b010  // 浮點乘法
`define FP_OP_FDIV       3'b011  // 浮點除法
`define FP_OP_FSQRT      3'b100  // 浮點平方根
`define FP_OP_FCMP       3'b101  // 浮點比較
`define FP_OP_FCVT       3'b110  // 浮點轉換
`define FP_OP_FSGNJ      3'b111  // 浮點符號注入

// 捨入模式
`define RM_RNE           3'b000
`define RM_RTZ           3'b001
`define RM_RDN           3'b010
`define RM_RUP           3'b011
`define RM_RMM           3'b100

`endif // RV_FPU_OPS
`endif // ENABLE_F_EXTENSION

// =============================================================================
// CSR 相關定義
// =============================================================================
`ifdef ENABLE_ZICSR
`ifndef RV_CSR_DEFS
`define RV_CSR_DEFS

// CSR 操作類型
`define CSR_OP_NONE      2'b00
`define CSR_OP_RW        2'b01
`define CSR_OP_RS        2'b10
`define CSR_OP_RC        2'b11

// CSR 功能碼
`define FUNCT3_CSRRW     3'b001
`define FUNCT3_CSRRS     3'b010
`define FUNCT3_CSRRC     3'b011
`define FUNCT3_CSRRWI    3'b101
`define FUNCT3_CSRRSI    3'b110
`define FUNCT3_CSRRCI    3'b111

// CSR 地址（機器模式）
`define CSR_ADDR_MSTATUS      12'h300   //機器模式狀態暫存器
`define CSR_ADDR_MISA         12'h301   //
`define CSR_ADDR_MIE          12'h304   //機器模式中斷使能
`define CSR_ADDR_MTVEC        12'h305   //機器模式陷阱向量
`define CSR_ADDR_MSCRATCH     12'h340   //機器模式暫存暫存器
`define CSR_ADDR_MEPC         12'h341   //機器模式例外程式計數器
`define CSR_ADDR_MCAUSE       12'h342   //機器模式例外原因
`define CSR_ADDR_MTVAL        12'h343   //
`define CSR_ADDR_MIP          12'h344   //機器模式中斷掛起

// 監控系統 CSR 地址
`define CSR_MONITOR_CTRL    12'h7C0  // 監控控制暫存器
`define CSR_PIPELINE_STATS  12'h7C1  // 流水線統計
`define CSR_MEMORY_STATS    12'h7C2  // 記憶體統計
`define CSR_STACK_STATS     12'h7C3  // 堆疊統計
`define CSR_PERF_COUNTERS   12'h7C4  // 性能計數器
`define CSR_DEBUG_TRACE     12'h7C5  // 除錯追蹤控制

// 用於除錯的CSR
`define CSR_DCSR         12'h7b0
`define CSR_DPC          12'h7b1
`define CSR_DSCRATCH0    12'h7b2

`endif // RV_CSR_DEFS
`endif // ENABLE_ZICSR

// =============================================================================
// 例外與中斷編碼
// =============================================================================
`ifndef RV_EXCEPTIONS
`define RV_EXCEPTIONS

// 中斷
`define INT_SOFTWARE     1
`define INT_TIMER        2
`define INT_EXTERNAL     3

// 例外原因編碼（MCAUSE寄存器）
`define EXC_CAUSE_INST_ADDR_MISALIGN   32'h00000000
`define EXC_CAUSE_INST_ACCESS_FAULT    32'h00000001
`define EXC_CAUSE_ILLEGAL_INST         32'h00000002
`define EXC_CAUSE_BREAKPOINT           32'h00000003
`define EXC_CAUSE_LOAD_ADDR_MISALIGN   32'h00000004
`define EXC_CAUSE_LOAD_ACCESS_FAULT    32'h00000005
`define EXC_CAUSE_STORE_ADDR_MISALIGN  32'h00000006
`define EXC_CAUSE_STORE_ACCESS_FAULT   32'h00000007
`define EXC_CAUSE_ECALL_U_MODE         32'h00000008
`define EXC_CAUSE_ECALL_S_MODE         32'h00000009
`define EXC_CAUSE_ECALL_M_MODE         32'h0000000B

`define INT_CAUSE_MSI                  32'h80000003
`define INT_CAUSE_MTI                  32'h80000007
`define INT_CAUSE_MEI                  32'h8000000B
`define INT_CAUSE_UART                 32'h80000010

`define SYSTEM_ECALL                   32'h00000073
`define SYSTEM_EBREAK                  32'h00100073
`define SYSTEM_MRET                    32'h30200073
`define SYSTEM_WFI                     32'h10500073

`endif // RV_EXCEPTIONS

`ifndef RV_MMIO_DEFS
`define RV_MMIO_DEFS

`define UART_DATA_ADDR       32'h10000000
`define UART_STATUS_ADDR     32'h10000004
`define MTIME_L_ADDR         32'h10000008
`define MTIME_H_ADDR         32'h1000000c
`define MTIMECMP_L_ADDR      32'h10000010
`define MTIMECMP_H_ADDR      32'h10000014
`define UART_IE_ADDR         32'h10000018

`define IS_RAM_ADDRESS(addr) ((addr) >= `RAM_BASE_ADDR && (addr) < (`RAM_BASE_ADDR + `RAM_SIZE))
`define IS_ROM_ADDRESS(addr) ((addr) >= `ROM_BASE_ADDR && (addr) < (`ROM_BASE_ADDR + `ROM_SIZE))

`endif