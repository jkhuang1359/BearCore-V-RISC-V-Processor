`timescale 1ns/1ps

`include "include/riscv_defines.vh"

// =============================================================================
// RISC-V 處理器核心模組
// 功能：
// 1. 5-stage pipeline (IF, ID, EX, MEM, WB)
// 2. 支援 RV32I 基礎指令集
// 3. 支援 CSR 暫存器操作
// 4. 支援中斷與例外處理
// 5. 內建 UART 通訊介面
// =============================================================================
module riscv_core (
    // 時脈與重置訊號
    input  wire core_clk_i,                     // 核心時脈
    input  wire core_reset_ni,                  // 低態有效重置訊號
    
    // UART 通訊介面
    output wire uart_tx_data_o,                 // UART 發送資料
    input  wire uart_rx_data_i                  // UART 接收資料
);
    
    // ============================
    // 1. 流水線階段控制訊號定義
    // ============================
    reg  instruction_decode_valid_r;            // ID 階段有效標誌
    reg  execute_valid_r;                       // EX 階段有效標誌
    reg  memory_access_valid_r;                 // MEM 階段有效標誌
    reg  write_back_valid_r;                    // WB 階段有效標誌
    
    // ============================
    // 2. 指令擷取階段 (IF) 訊號
    // ============================
    reg  [31:0] program_counter_r;              // 程式計數器
    wire [31:0] next_program_counter_w;         // 下一個程式計數器
    wire [31:0] instruction_fetch_data_w;       // 擷取的指令資料
    
    // ============================
    // 3. 指令解碼階段 (ID) 訊號
    // ============================
    reg  [31:0] instruction_decode_pc_r;        // ID 階段的 PC
    reg  [31:0] instruction_decode_inst_r;      // ID 階段的指令
    
    // 解碼器輸出的控制訊號
    wire [4:0]  rs1_address_w;                  // 來源暫存器 1 地址
    wire [4:0]  rs2_address_w;                  // 來源暫存器 2 地址
    wire [4:0]  rd_address_w;                   // 目的暫存器地址
    wire [31:0] immediate_value_w;              // 立即數值
    wire [2:0]  function_3_w;                   // funct3 欄位
    wire [3:0]  alu_operation_w;                // ALU 操作碼
    wire        alu_source_b_select_w;          // ALU B 輸入選擇
    wire        register_write_enable_w;        // 暫存器寫入使能
    wire        store_operation_w;              // 儲存操作標誌
    wire        load_operation_w;               // 載入操作標誌
    wire        jump_and_link_w;                // JAL 指令標誌
    wire        jump_and_link_register_w;       // JALR 指令標誌
    wire        branch_operation_w;             // 分支指令標誌
    wire        load_upper_immediate_w;         // LUI 指令標誌
    wire        add_upper_immediate_to_pc_w;    // AUIPC 指令標誌
    wire        multiplication_extension_w;     // M 擴展標誌

    wire [31:0] csr_read_data_from_module_w;  // CSR 模組的讀取資料

    
    // 暫存器讀取資料
    wire [31:0] instruction_decode_rs1_data_w;  // ID 階段的 RS1 資料
    wire [31:0] instruction_decode_rs2_data_w;  // ID 階段的 RS2 資料
    
    // ============================
    // 4. 執行階段 (EX) 訊號
    // ============================
    reg  [31:0] execute_pc_r;                   // EX 階段的 PC
    reg  [31:0] execute_rs1_data_r;             // EX 階段的 RS1 資料
    reg  [31:0] execute_rs2_data_r;             // EX 階段的 RS2 資料
    reg  [31:0] execute_immediate_r;            // EX 階段的立即數
    reg  [4:0]  execute_rs1_address_r;          // EX 階段的 RS1 地址
    reg  [4:0]  execute_rs2_address_r;          // EX 階段的 RS2 地址
    reg  [4:0]  execute_rd_address_r;           // EX 階段的 RD 地址
    reg  [2:0]  execute_function_3_r;           // EX 階段的 funct3
    reg  [3:0]  execute_alu_operation_r;        // EX 階段的 ALU 操作碼
    reg         execute_alu_source_b_select_r;  // EX 階段的 ALU B 選擇
    reg         execute_memory_write_enable_r;  // EX 階段的記憶體寫入使能
    reg         execute_register_write_enable_r; // EX 階段的暫存器寫入使能
    reg         execute_load_operation_r;       // EX 階段的載入操作
    reg         execute_load_upper_immediate_r; // EX 階段的 LUI 操作
    reg         execute_jump_and_link_r;        // EX 階段的 JAL 操作
    reg         execute_jump_and_link_register_r; // EX 階段的 JALR 操作
    reg         execute_branch_operation_r;     // EX 階段的 branch 操作
    reg         execute_add_upper_immediate_to_pc_r; // EX 階段的 AUIPC 操作
    reg         execute_csr_instruction_r;      // EX 階段的 CSR 指令標誌
    reg  [1:0]  execute_csr_operation_r;        // EX 階段的 CSR 操作類型
    reg         execute_csr_use_immediate_r;    // EX 階段的 CSR 使用立即數
    reg  [11:0] execute_csr_address_r;          // EX 階段的 CSR 地址
    
    // ============================
    // 5. ALU 相關訊號
    // ============================
    wire [31:0] alu_operand_a_final_w;          // ALU A 操作數 (forwarded)
    wire [31:0] alu_operand_b_final_w;          // ALU B 操作數 (forwarded)
    wire [31:0] alu_result_w;                   // ALU 計算結果
    wire        alu_zero_flag_w;                // ALU 零旗標
    wire        alu_less_flag_w;                // ALU 小於旗標
    wire        alu_stall_request_w;            // ALU 暫停請求
    
    // ============================
    // 6. 記憶體存取階段 (MEM) 訊號
    // ============================
    reg  [31:0] memory_access_alu_result_r;     // MEM 階段的 ALU 結果
    reg  [31:0] memory_access_rs2_data_r;       // MEM 階段的 RS2 資料
    reg  [31:0] memory_access_pc_plus_4_r;      // MEM 階段的 PC+4
    reg  [4:0]  memory_access_rd_address_r;     // MEM 階段的 RD 地址
    reg         memory_access_memory_write_enable_r;  // MEM 階段的記憶體寫入使能
    reg         memory_access_register_write_enable_r; // MEM 階段的暫存器寫入使能
    reg         memory_access_load_operation_r; // MEM 階段的載入操作
    reg         memory_access_jump_or_jalr_r;   // MEM 階段的 JAL/JALR 操作
    reg         memory_access_load_upper_immediate_r; // MEM 階段的 LUI 操作
    reg  [2:0]  memory_access_function_3_r;     // MEM 階段的 funct3
    reg         memory_access_csr_instruction_r; // MEM 階段的 CSR 指令標誌
    reg  [1:0]  memory_access_csr_operation_r;  // MEM 階段的 CSR 操作類型
    reg         memory_access_csr_use_immediate_r; // MEM 階段的 CSR 使用立即數
    reg  [11:0] memory_access_csr_address_r;    // MEM 階段的 CSR 地址
    reg  [31:0] memory_access_csr_write_data_r; // MEM 階段的 CSR 寫入資料
    
    // ============================
    // 7. 寫回階段 (WB) 訊號
    // ============================
    reg  [31:0] write_back_memory_read_data_r;  // WB 階段的記憶體讀取資料
    reg  [31:0] write_back_alu_result_r;        // WB 階段的 ALU 結果
    reg  [31:0] write_back_pc_plus_4_r;         // WB 階段的 PC+4
    reg  [4:0]  write_back_rd_address_r;        // WB 階段的 RD 地址
    reg         write_back_register_write_enable_r; // WB 階段的暫存器寫入使能
    reg         write_back_load_operation_r;    // WB 階段的載入操作
    reg         write_back_jump_or_jalr_r;      // WB 階段的 JAL/JALR 操作
    reg         write_back_csr_instruction_r;   // WB 階段的 CSR 指令標誌
    reg  [1:0]  write_back_csr_operation_r;     // WB 階段的 CSR 操作類型
    reg         write_back_csr_use_immediate_r; // WB 階段的 CSR 使用立即數
    reg  [11:0] write_back_csr_address_r;       // WB 階段的 CSR 地址
    wire [31:0] write_back_data_w;              // 寫回暫存器的資料
    
    // ============================
    // 8. 資料相依性與暫停控制
    // ============================
    reg         pipeline_stall_r;               // 流水線暫停訊號
    wire        load_hazard_w;                  // 載入相依性危險
    wire        pipeline_flush_w;               // 流水線清除訊號
    
    // ============================
    // 9. 分支與跳躍控制
    // ============================
    wire [31:0] execute_target_pc_w;            // EX 階段的目標 PC
    wire        execute_take_branch_w;          // EX 階段分支成立標誌
    
    // ============================
    // 10. CSR 相關訊號
    // ============================
    wire        csr_instruction_w;              // CSR 指令標誌
    wire        system_instruction_w;           // 系統指令標誌
    wire        csr_use_immediate_w;            // CSR 使用立即數標誌
    wire [1:0]  csr_operation_type_w;           // CSR 操作類型
    wire [11:0] csr_address_w;                  // CSR 地址
    wire [31:0] csr_read_data_w;                // CSR 讀取資料
    wire [31:0] csr_write_data_w;               // CSR 寫入資料
    wire        csr_write_enable_w;             // CSR 寫入使能
    wire [31:0] machine_trap_vector_w;          // mtvec 值
    wire [31:0] machine_exception_pc_w;         // mepc 值
    wire [31:0] machine_interrupt_enable_w;     // mie 暫存器值
    wire        machine_status_interrupt_enable_w; // mstatus.mie 位元
    
    // ============================
    // 11. 中斷與例外處理訊號
    // ============================
    reg         interrupt_pending_r;            // 中斷掛起標誌
    reg  [31:0] interrupt_program_counter_r;    // 中斷發生時的 PC
    wire        delayed_interrupt_w;            // 延遲中斷訊號
    wire        final_exception_taken_w;        // 最終例外觸發訊號
    wire        immediate_interrupt_w;          // 即時中斷訊號
    wire        uart_interrupt_raw_w;           // 原始 UART 中斷
    wire        timer_interrupt_raw_w;          // 原始計時器中斷
    wire        uart_interrupt_final_w;         // 最終 UART 中斷
    wire        timer_interrupt_final_w;        // 最終計時器中斷
    wire        software_exception_w;           // 軟體例外標誌
    wire        illegal_instruction_w;          // 非法指令標誌
    wire        machine_return_taken_w;         // MRET 指令執行標誌
    wire [31:0] trap_return_pc_w;               // 陷阱返回 PC
    
    // ============================
    // 12. 計數器與計時器
    // ============================
    reg  [31:0] cycle_counter_r;                // 時脈週期計數器
    reg  [31:0] instruction_counter_r;          // 指令計數器
    reg  [63:0] machine_time_r;                 // mtime 計時器
    reg  [63:0] machine_time_compare_r;         // mtimecmp 比較暫存器
    
    // ============================
    // 13. UART 相關訊號
    // ============================
    wire        uart_busy_w;                    // UART 忙碌標誌
    wire        uart_write_enable_w;            // UART 寫入使能
    wire [7:0]  uart_receive_data_w;            // UART 接收資料
    wire        uart_receive_ready_w;           // UART 接收準備就緒
    wire        uart_read_acknowledge_w;        // UART 讀取確認
    reg         transmitter_test_enable_r;      // 發送器測試模式使能
    reg         receiver_test_enable_r;         // 接收器測試模式使能
    wire        final_receive_data_w;           // 最終接收資料
    
    // ============================
    // 14. 資料記憶體相關訊號
    // ============================
    wire [31:0] block_ram_read_data_w;          // Block RAM 讀取資料
    reg         write_back_is_ram_address_r;    // WB 階段是否為 RAM 地址
    wire        is_ram_address_w;               // 是否為 RAM 地址
    wire        is_rom_data_access_w;           // 是否為 ROM 資料存取
    
    // ============================
    // 15. 例外原因與值
    // ============================
    reg  [31:0] exception_cause_r;              // 例外原因
    reg  [31:0] exception_tval_r;               // 例外附加資訊
    
    // ============================
    // 16. 記憶體存取階段資料處理
    // ============================
    reg [31:0] memory_access_final_read_data_w; // MEM 階段最終讀取資料
    wire        mem_is_uart_data_w;             // 是否為 UART 資料地址
    wire        mem_is_uart_status_w;           // 是否為 UART 狀態地址
    wire        mem_is_cycle_counter_w;         // 是否為週期計數器地址
    wire        mem_is_instruction_counter_w;   // 是否為指令計數器地址
    wire        mem_is_uart_interrupt_enable_w; // 是否為 UART 中斷使能地址
    wire        mem_is_mtimecmp_low_w;          // 是否為 mtimecmp 低地址
    wire        mem_is_mtimecmp_high_w;         // 是否為 mtimecmp 高地址
    wire        actual_memory_write_enable_w;   // 實際記憶體寫入使能
    reg  [31:0] memory_access_write_data_aligned_r; // 記憶體寫入資料對齊
    wire        uart_actual_transmit_enable_w;  // 實際 UART 發送使能
    wire        uart_register_write_w;          // UART 暫存器寫入
    wire        uart_int_raw_o_from_intc;  

    assign      uart_interrupt_raw_w = uart_int_raw_o_from_intc;
    
    // ============================
    // 17. 資料前遞與暫存器寫入
    // ============================
    wire [31:0] instruction_decode_rs1_data_forwarded_w; // ID 階段 RS1 前遞資料
    wire [31:0] instruction_decode_rs2_data_forwarded_w; // ID 階段 RS2 前遞資料
    wire [31:0] rs2_data_forwarded_w;           // EX 階段 RS2 前遞資料
    wire [31:0] memory_stage_data_w;            // MEM 階段資料 (用於前遞)
    wire [31:0] write_back_final_memory_data_w; // WB 階段最終記憶體資料
    
    // ============================
    // 18. 模組選擇與優先級訊號
    // ============================
    wire        select_execute_target_w;        // 選擇 EX 階段目標
    wire        select_exception_target_w;      // 選擇例外目標
    wire        select_machine_return_target_w; // 選擇 MRET 目標
    
    // ============================
    // 19. CSR 寫入控制訊號
    // ============================
    wire        csr_write_always_w;             // CSR 總是寫入
    wire        csr_write_set_w;                // CSR 設定寫入
    wire        csr_write_clear_w;              // CSR 清除寫入
    wire [31:0] csr_read_data_forwarded_w;      // CSR 讀取資料前遞
    
    // ============================
    // 20. 除法器相關訊號
    // ============================
    wire        division_start_w;               // 除法開始訊號
    wire        division_ready_w;               // 除法就緒訊號
    wire        division_busy_w;                // 除法忙碌訊號
    wire [31:0] division_quotient_w;            // 除法商數
    wire [31:0] division_remainder_w;           // 除法餘數
    
    // ============================
    // 21. UART 中斷控制暫存器
    // ============================
    reg  [31:0] uart_interrupt_enable_r;        // UART 中斷使能暫存器
    
    // ============================
    // 22. 分支條件判斷
    // ============================
    reg         branch_condition_met_r;         // 分支條件成立
    
    // ============================
    // 23. 模組實例化
    // ============================
    
    // ROM 記憶體實例
    rom u_rom_inst (
        // 指令讀取介面
        .instruction_addr_i(program_counter_r),
        .instruction_data_o(instruction_fetch_data_w),
        
        // 資料讀取介面
        .data_read_addr_i(memory_access_alu_result_r),
        .data_read_data_o()  // 在 always block 中處理
    );
    
    // 指令解碼器實例
    instruction_decoder u_decoder_inst (
        .instruction_i(instruction_decode_inst_r),
        
        // 暫存器地址輸出
        .rs1_address_o(rs1_address_w),
        .rs2_address_o(rs2_address_w),
        .rd_address_o(rd_address_w),
        
        // 立即數輸出
        .immediate_value_o(immediate_value_w),
        
        // 功能欄位輸出
        .function_3_o(function_3_w),
        .alu_operation_o(alu_operation_w),
        
        // 控制訊號輸出
        .alu_source_b_select_o(alu_source_b_select_w),
        .register_write_enable_o(register_write_enable_w),
        .store_operation_o(store_operation_w),
        .load_operation_o(load_operation_w),
        .jump_and_link_o(jump_and_link_w),
        .jump_and_link_register_o(jump_and_link_register_w),
        .branch_operation_o(branch_operation_w),
        .load_upper_immediate_o(load_upper_immediate_w),
        .add_upper_immediate_to_pc_o(add_upper_immediate_to_pc_w),
        .multiplication_extension_o(multiplication_extension_w),
        
        // CSR 相關輸出
        .csr_instruction_o(csr_instruction_w),
        .system_instruction_o(system_instruction_w),
        .csr_operation_type_o(csr_operation_type_w),
        .csr_use_immediate_o(csr_use_immediate_w),
        .csr_address_o(csr_address_w)
    );
    
    // CSR 暫存器實例
    csr_registers u_csr_registers_inst (
        // 時脈與重置
        .clk_i(core_clk_i),
        .reset_ni(core_reset_ni),
        
        // CSR 讀寫介面
        .csr_address_i(memory_access_csr_address_r),
        .csr_write_data_i(csr_write_data_w),
        .csr_write_enable_i(csr_write_enable_w),
        .csr_operation_i(memory_access_csr_operation_r),
        .csr_use_immediate_i(memory_access_csr_use_immediate_r),
        
        // 中斷與例外介面
        .trap_trigger_i(final_exception_taken_w),
        .trap_program_counter_i(trap_return_pc_w),
        .trap_cause_i(exception_cause_r),
        .timer_interrupt_raw_i(timer_interrupt_raw_w),
        .uart_interrupt_raw_i(uart_interrupt_raw_w),
        .machine_return_taken_i(machine_return_taken_w),
        
        // CSR 讀取資料輸出
        .csr_read_data_o(csr_read_data_from_module_w),
        
        // CSR 特殊暫存器輸出
        .machine_trap_vector_o(machine_trap_vector_w),
        .machine_exception_pc_o(machine_exception_pc_w),
        .machine_interrupt_enable_o(machine_interrupt_enable_w),
        .machine_status_interrupt_enable_o(machine_status_interrupt_enable_w)
    );
    
    // 暫存器檔案實例
    register_file u_register_file_inst (
        // 時脈與重置
        .clk_i(core_clk_i),
        .reset_ni(core_reset_ni),
        
        // 讀取端口 1
        .read_address_1_i(rs1_address_w),
        .read_data_1_o(instruction_decode_rs1_data_w),
        
        // 讀取端口 2
        .read_address_2_i(rs2_address_w),
        .read_data_2_o(instruction_decode_rs2_data_w),
        
        // 寫入端口
        .write_enable_i(write_back_register_write_enable_r),
        .write_address_i(write_back_rd_address_r),
        .write_data_i(write_back_data_w)
    );
    
    // ALU 實例
    arithmetic_logic_unit u_alu_inst (
        // 時脈與重置
        .clk_i(core_clk_i),
        .reset_ni(core_reset_ni),
        
        // 操作數輸入
        .operand_a_i(alu_operand_a_final_w),
        .operand_b_i(alu_operand_b_final_w),
        
        // 控制輸入
        .alu_operation_i(execute_alu_operation_r),
        .function_3_i(execute_function_3_r),
        
        // 結果輸出
        .result_o(alu_result_w),
        .zero_flag_o(alu_zero_flag_w),
        .less_flag_o(alu_less_flag_w),
        
        // 流水線控制
        .stall_request_o(alu_stall_request_w)
    );
    
    // 資料記憶體實例
    data_memory u_data_memory_inst (
        .clk_i(core_clk_i),
        .write_enable_i(actual_memory_write_enable_w),
        .address_i({16'd0, memory_access_alu_result_r[15:0]}),
        .write_data_i(memory_access_write_data_aligned_r),
        .function_3_i(memory_access_function_3_r),
        .read_data_o(block_ram_read_data_w)
    );
    
    // UART 發送器實例
    uart_transmitter #(
        .CLOCK_FREQUENCY(100000000),
        .BAUD_RATE(1152000)
    ) u_uart_transmitter_inst (
        .clk_i(core_clk_i),
        .reset_ni(core_reset_ni),
        .transmit_data_i(memory_access_rs2_data_r[7:0]),
        .transmit_valid_i(uart_actual_transmit_enable_w),
        .test_mode_i(transmitter_test_enable_r),
        .busy_o(uart_busy_w),
        .transmit_data_o(uart_tx_data_o)
    );
    
    // UART 接收器實例
    uart_receiver #(
        .CLOCK_FREQUENCY(100000000),
        .BAUD_RATE(1152000)
    ) u_uart_receiver_inst (
        .clk_i(core_clk_i),
        .reset_ni(core_reset_ni),
        .receive_data_i(final_receive_data_w),
        .read_enable_i(uart_read_acknowledge_w),
        .receive_data_o(uart_receive_data_w),
        .receive_ready_o(uart_receive_ready_w)
    );
    
    // 除法器單元實例
    division_unit u_division_unit_inst (
        .clk_i(core_clk_i),
        .reset_ni(core_reset_ni),
        .start_i(division_start_w),
        .dividend_i(alu_operand_a_final_w),
        .divisor_i(alu_operand_b_final_w),
        .signed_operation_i(~execute_function_3_r[0]),
        .quotient_o(division_quotient_w),
        .remainder_o(division_remainder_w),
        .ready_o(division_ready_w),
        .busy_o(division_busy_w)
    );

    
    // ============================
    // 組合邏輯部分開始
    // ============================
    
    // ============================
    // 1. 非法指令偵測邏輯
    // ============================
    assign illegal_instruction_w = !(register_write_enable_w || load_operation_w || 
                                     store_operation_w || branch_operation_w || 
                                     jump_and_link_w || jump_and_link_register_w || 
                                     load_upper_immediate_w || add_upper_immediate_to_pc_w || 
                                     system_instruction_w || (instruction_decode_inst_r == 32'h00000013));
    
    // ============================
    // 2. 軟體例外偵測邏輯
    // ============================
    assign software_exception_w = illegal_instruction_w ||
                                 (system_instruction_w && 
                                  (instruction_decode_inst_r == `SYSTEM_ECALL || 
                                   instruction_decode_inst_r == `SYSTEM_EBREAK));
    
    // ============================
    // 3. 原始中斷訊號生成
    // ============================
    // UART中斷源（從中斷控制器輸出）
    wire uart_tx_interrupt_pending_w;  // 聲明這些信號
    wire uart_rx_interrupt_pending_w;    

    // ============================
    // UART中斷控制器
    // ============================

    uart_interrupt_controller u_uart_intc_inst (
        .clk_i(core_clk_i),
        .reset_ni(core_reset_ni),
        
        // UART狀態輸入
        .uart_busy_i(uart_busy_w),
        .uart_receive_ready_i(uart_receive_ready_w),
        .uart_read_ack_i(uart_read_acknowledge_w),
        
        // 軟體控制
        .uart_ie_i(uart_interrupt_enable_r),
        .mem_is_uart_status_i(mem_is_uart_status_w),
        .mem_write_enable_i(memory_access_memory_write_enable_r),
        .mem_write_data_i(memory_access_rs2_data_r),
        .mem_load_operation_i(memory_access_load_operation_r),
        
        // 中斷輸出
        .uart_tx_int_pending_o(uart_tx_interrupt_pending_w),
        .uart_rx_int_pending_o(uart_rx_interrupt_pending_w),
        .uart_int_raw_o(uart_int_raw_o_from_intc)
    );   

    // 更新UART中斷使能暫存器
    always @(posedge core_clk_i or negedge core_reset_ni) begin
        if (!core_reset_ni) begin
            uart_interrupt_enable_r <= 32'h0;
        end else if (memory_access_memory_write_enable_r && memory_access_valid_r && 
                    mem_is_uart_interrupt_enable_w) begin
            uart_interrupt_enable_r <= memory_access_rs2_data_r;
        end
    end

    // 更新中斷掛起暫存器（用於調試）
    reg uart_tx_int_pending_r, uart_rx_int_pending_r;
    always @(posedge core_clk_i or negedge core_reset_ni) begin
        if (!core_reset_ni) begin
            uart_tx_int_pending_r <= 1'b0;
            uart_rx_int_pending_r <= 1'b0;
        end else begin
            uart_tx_int_pending_r <= uart_tx_interrupt_pending_w;
            uart_rx_int_pending_r <= uart_rx_interrupt_pending_w;
        end
    end     

    // 最終中斷輸出
//    assign uart_interrupt_raw_w = (uart_tx_interrupt_pending_r && uart_interrupt_enable_r[0]) ||
//                                (uart_rx_interrupt_pending_r && uart_interrupt_enable_r[1]);
    
    assign timer_interrupt_raw_w = (machine_time_r >= machine_time_compare_r);
    
    // ============================
    // 4. 最終中斷訊號生成 (考慮中斷遮罩與分支保護)
    // ============================
    assign uart_interrupt_final_w = (uart_interrupt_raw_w && machine_interrupt_enable_w[16] && 
                                     machine_status_interrupt_enable_w);
    
    assign timer_interrupt_final_w = (timer_interrupt_raw_w && machine_interrupt_enable_w[7] && 
                                      machine_status_interrupt_enable_w);
    
    assign immediate_interrupt_w = timer_interrupt_final_w || uart_interrupt_final_w;
    
    // ============================
    // 5. 同步例外觸發邏輯
    // ============================
    wire sync_exception_taken_w = (software_exception_w && !execute_take_branch_w);
    
    // ============================
    // 6. 中斷延遲邏輯控制訊號
    // ============================
    assign delayed_interrupt_w = interrupt_pending_r && 
                                !(memory_access_memory_write_enable_r || memory_access_load_operation_r);
    
    // ============================
    // 7. 最終例外觸發訊號
    // ============================
    assign final_exception_taken_w = sync_exception_taken_w || 
                                     (immediate_interrupt_w && 
                                      !(memory_access_memory_write_enable_r || memory_access_load_operation_r)) || 
                                     delayed_interrupt_w;
    
    // ============================
    // 8. MRET 指令偵測
    // ============================
    assign machine_return_taken_w = (system_instruction_w && 
                                     (instruction_decode_inst_r == `SYSTEM_MRET));
    
    // ============================
    // 9. 流水線清除訊號
    // ============================
    assign pipeline_flush_w = (execute_take_branch_w || final_exception_taken_w || 
                               machine_return_taken_w);
    
    // ============================
    // 10. 下一個 PC 選擇邏輯
    // ============================
    assign select_execute_target_w = execute_take_branch_w;
    assign select_exception_target_w = !execute_take_branch_w && final_exception_taken_w;
    assign select_machine_return_target_w = !execute_take_branch_w && !final_exception_taken_w && 
                                            machine_return_taken_w;
    
    assign next_program_counter_w = 
        (select_execute_target_w) ? execute_target_pc_w :           // 分支/跳躍目標
        (select_exception_target_w) ? machine_trap_vector_w :       // 例外處理入口
        (select_machine_return_target_w) ? machine_exception_pc_w : // MRET 返回地址
        (program_counter_r + 4);                                    // 順序執行
    
    // ============================
    // 11. 記憶體地址解碼邏輯
    // ============================
    assign is_ram_address_w = `IS_RAM_ADDRESS(memory_access_alu_result_r);
    assign is_rom_data_access_w = `IS_ROM_ADDRESS(memory_access_alu_result_r);    
    // UART 相關地址解碼
    assign mem_is_uart_data_w = (memory_access_alu_result_r == `UART_DATA_ADDR);
    assign mem_is_uart_status_w = (memory_access_alu_result_r == `UART_STATUS_ADDR);
    assign mem_is_cycle_counter_w = (memory_access_alu_result_r == `MTIME_L_ADDR);
    assign mem_is_instruction_counter_w = (memory_access_alu_result_r == `MTIME_H_ADDR);
    assign mem_is_uart_interrupt_enable_w = (memory_access_alu_result_r == `UART_IE_ADDR);
    assign mem_is_mtimecmp_low_w = (memory_access_alu_result_r == `MTIMECMP_L_ADDR);
    assign mem_is_mtimecmp_high_w = (memory_access_alu_result_r == `MTIMECMP_H_ADDR);
    
    // ============================
    // 12. 記憶體寫入控制邏輯
    // ============================
    assign actual_memory_write_enable_w = memory_access_memory_write_enable_r && is_ram_address_w;
    
    // ============================
    // 13. UART 相關控制邏輯
    // ============================
    assign uart_read_acknowledge_w = (memory_access_alu_result_r == `UART_DATA_ADDR) && 
                                     memory_access_load_operation_r && memory_access_valid_r;
    
    assign uart_register_write_w = memory_access_memory_write_enable_r && mem_is_uart_data_w && 
                                   memory_access_valid_r;
    
    assign uart_actual_transmit_enable_w = uart_register_write_w && 
                                          (memory_access_rs2_data_r[31] == 2'b0);
    
    // UART 接收資料多工器
    assign final_receive_data_w = (receiver_test_enable_r) ? uart_tx_data_o : uart_rx_data_i;
    
    // ============================
    // 14. 載入危險偵測邏輯
    // ============================
    wire mem_is_ram_load_w = memory_access_load_operation_r && is_ram_address_w;
    
    assign load_hazard_w = (execute_load_operation_r && (execute_rd_address_r != 0) && 
                           (execute_rd_address_r == rs1_address_w || execute_rd_address_r == rs2_address_w)) ||
                          (mem_is_ram_load_w && (memory_access_rd_address_r != 0) && 
                           (memory_access_rd_address_r == rs1_address_w || memory_access_rd_address_r == rs2_address_w));
    
    // ============================
    // 15. 流水線暫停控制邏輯
    // ============================
    always @(*) begin
        pipeline_stall_r = (load_hazard_w || alu_stall_request_w) && !final_exception_taken_w;
    end
    
    // ============================
    // 16. ID 階段暫存器寫入使能 (包含 CSR)
    // ============================
    wire instruction_decode_register_write_enable_w = register_write_enable_w || csr_instruction_w;
    
    // ============================
    // 17. ID 階段資料前遞邏輯 (來自 WB 階段)
    // ============================
    assign instruction_decode_rs1_data_forwarded_w = 
        (write_back_valid_r && write_back_register_write_enable_r && 
         write_back_rd_address_r != 0 && write_back_rd_address_r == rs1_address_w) ?
        write_back_data_w : instruction_decode_rs1_data_w;
    
    assign instruction_decode_rs2_data_forwarded_w = 
        (write_back_valid_r && write_back_register_write_enable_r && 
         write_back_rd_address_r != 0 && write_back_rd_address_r == rs2_address_w) ?
        write_back_data_w : instruction_decode_rs2_data_w;
    
    // ============================
    // 18. EX 階段資料前遞邏輯
    // ============================
    
    // MEM 階段資料選擇
    assign memory_stage_data_w = 
        (memory_access_csr_instruction_r) ? csr_read_data_w :
        (memory_access_load_operation_r) ? memory_access_final_read_data_w :
        (memory_access_jump_or_jalr_r) ? memory_access_pc_plus_4_r :
        memory_access_alu_result_r;
    
    // EX 階段 RS1 資料前遞
    wire [31:0] execute_rs1_forwarded_w = 
        (memory_access_register_write_enable_r && memory_access_rd_address_r != 0 && 
         memory_access_rd_address_r == execute_rs1_address_r) ?
        memory_stage_data_w :
        (write_back_register_write_enable_r && write_back_rd_address_r != 0 && 
         write_back_rd_address_r == execute_rs1_address_r) ?
        write_back_data_w : execute_rs1_data_r;
    
    // EX 階段 RS2 資料前遞
    assign rs2_data_forwarded_w = 
        (memory_access_register_write_enable_r && memory_access_rd_address_r != 0 && 
         memory_access_rd_address_r == execute_rs2_address_r) ?
        memory_stage_data_w :
        (write_back_register_write_enable_r && write_back_rd_address_r != 0 && 
         write_back_rd_address_r == execute_rs2_address_r) ?
        write_back_data_w : execute_rs2_data_r;
    
    // ============================
    // 19. ALU 操作數選擇邏輯
    // ============================
    assign alu_operand_a_final_w = (execute_add_upper_immediate_to_pc_r) ? 
                                   execute_pc_r : execute_rs1_forwarded_w;
    
    assign alu_operand_b_final_w = (execute_alu_source_b_select_r) ? 
                                   execute_immediate_r : rs2_data_forwarded_w;
    
    // ============================
    // 20. 分支條件判斷邏輯
    // ============================
    always @(*) begin
        case (execute_function_3_r)
            3'b000: branch_condition_met_r = alu_zero_flag_w;      // BEQ
            3'b001: branch_condition_met_r = !alu_zero_flag_w;     // BNE
            3'b100: branch_condition_met_r = alu_less_flag_w;      // BLT
            3'b101: branch_condition_met_r = !alu_less_flag_w;     // BGE
            3'b110: branch_condition_met_r = alu_less_flag_w;      // BLTU
            3'b111: branch_condition_met_r = !alu_less_flag_w;     // BGEU
            default: branch_condition_met_r = 1'b0;
        endcase
    end
    
    // ============================
    // 21. 分支與跳躍目標計算
    // ============================
    assign execute_take_branch_w = (execute_branch_operation_r && branch_condition_met_r) || 
                                   execute_jump_and_link_r || execute_jump_and_link_register_r;
    
    assign execute_target_pc_w = (execute_jump_and_link_register_r) ? 
                                 ((execute_rs1_forwarded_w + execute_immediate_r) & ~32'h1) : 
                                 (execute_pc_r + execute_immediate_r);
    
    // ============================
    // 22. 記憶體寫入資料對齊邏輯
    // ============================
    always @(*) begin
        case (memory_access_function_3_r)
            3'b000: memory_access_write_data_aligned_r = {4{memory_access_rs2_data_r[7:0]}};  // SB
            3'b001: memory_access_write_data_aligned_r = {2{memory_access_rs2_data_r[15:0]}}; // SH
            default: memory_access_write_data_aligned_r = memory_access_rs2_data_r;           // SW
        endcase
    end
    
    // ============================
    // 23. 記憶體讀取資料處理邏輯
    // ============================
    wire [31:0] rom_data_out_w;
    
    // ROM 資料讀取實例 (用於資料存取)
    rom u_rom_data_inst (
        .instruction_addr_i(32'h0),  // 不使用指令介面
        .instruction_data_o(),
        .data_read_addr_i(memory_access_alu_result_r),
        .data_read_data_o(rom_data_out_w)
    );
    
    // MEM 階段最終讀取資料選擇
    always @(*) begin
        if (mem_is_uart_status_w) begin
            memory_access_final_read_data_w = {30'b0, uart_receive_ready_w, uart_busy_w};
        end else if (mem_is_uart_data_w) begin
            memory_access_final_read_data_w = {24'b0, uart_receive_data_w};
        end else if (mem_is_cycle_counter_w) begin
            memory_access_final_read_data_w = machine_time_r[31:0];
        end else if (mem_is_instruction_counter_w) begin
            memory_access_final_read_data_w = machine_time_r[63:32];
        end else if (mem_is_mtimecmp_low_w) begin
            memory_access_final_read_data_w = machine_time_compare_r[31:0];
        end else if (mem_is_mtimecmp_high_w) begin
            memory_access_final_read_data_w = machine_time_compare_r[63:32];
        end else if (mem_is_uart_interrupt_enable_w) begin
            memory_access_final_read_data_w = uart_interrupt_enable_r;
        end else if (memory_access_csr_instruction_r) begin
            memory_access_final_read_data_w = csr_read_data_w;
        end else if (is_rom_data_access_w && !memory_access_memory_write_enable_r) begin
            // ROM 資料存取 (支援不同位元寬度)
            case (memory_access_function_3_r)
                3'b000: begin // LB (有符號位元組)
                    case (memory_access_alu_result_r[1:0])
                        2'b00: memory_access_final_read_data_w = {{24{rom_data_out_w[7]}}, rom_data_out_w[7:0]};
                        2'b01: memory_access_final_read_data_w = {{24{rom_data_out_w[15]}}, rom_data_out_w[15:8]};
                        2'b10: memory_access_final_read_data_w = {{24{rom_data_out_w[23]}}, rom_data_out_w[23:16]};
                        2'b11: memory_access_final_read_data_w = {{24{rom_data_out_w[31]}}, rom_data_out_w[31:24]};
                    endcase
                end
                3'b001: begin // LH (有符號半字)
                    case (memory_access_alu_result_r[1])
                        1'b0: memory_access_final_read_data_w = {{16{rom_data_out_w[15]}}, rom_data_out_w[15:0]};
                        1'b1: memory_access_final_read_data_w = {{16{rom_data_out_w[31]}}, rom_data_out_w[31:16]};
                    endcase
                end
                3'b010: begin // LW (字)
                    memory_access_final_read_data_w = rom_data_out_w;
                end
                3'b100: begin // LBU (無符號位元組)
                    case (memory_access_alu_result_r[1:0])
                        2'b00: memory_access_final_read_data_w = {24'b0, rom_data_out_w[7:0]};
                        2'b01: memory_access_final_read_data_w = {24'b0, rom_data_out_w[15:8]};
                        2'b10: memory_access_final_read_data_w = {24'b0, rom_data_out_w[23:16]};
                        2'b11: memory_access_final_read_data_w = {24'b0, rom_data_out_w[31:24]};
                    endcase
                end
                3'b101: begin // LHU (無符號半字)
                    case (memory_access_alu_result_r[1])
                        1'b0: memory_access_final_read_data_w = {16'b0, rom_data_out_w[15:0]};
                        1'b1: memory_access_final_read_data_w = {16'b0, rom_data_out_w[31:16]};
                    endcase
                end
                default: memory_access_final_read_data_w = rom_data_out_w;
            endcase
        end else begin
            memory_access_final_read_data_w = 32'h0;
        end
    end
    
    // ============================
    // 24. 寫回階段資料選擇邏輯
    // ============================
    assign write_back_final_memory_data_w = (write_back_is_ram_address_r) ? 
                                           block_ram_read_data_w : write_back_memory_read_data_r;
    
    assign write_back_data_w = 
        (write_back_jump_or_jalr_r) ? write_back_pc_plus_4_r :      // JAL/JALR 返回地址
        (write_back_load_operation_r || write_back_csr_instruction_r) ? 
        write_back_final_memory_data_w :                           // 載入資料或 CSR 資料
        write_back_alu_result_r;                                   // ALU 結果
    
    // ============================
    // 25. CSR 寫入控制邏輯
    // ============================
    assign csr_write_always_w = (memory_access_csr_operation_r == `CSR_OP_RW);  // CSRRW
    assign csr_write_set_w = (memory_access_csr_operation_r == `CSR_OP_RS) && (|csr_write_data_w);  // CSRRS
    assign csr_write_clear_w = (memory_access_csr_operation_r == `CSR_OP_RC) && (|csr_write_data_w); // CSRRC
    
    assign csr_write_enable_w = 
        memory_access_valid_r && memory_access_csr_instruction_r && 
        (csr_write_always_w || csr_write_set_w || csr_write_clear_w);
    
    // ============================
    // 26. CSR 寫入資料生成
    // ============================
    assign csr_write_data_w =  
        (memory_access_csr_operation_r == `CSR_OP_RW) ? memory_access_csr_write_data_r :  // CSRRW
        (memory_access_csr_operation_r == `CSR_OP_RS) ? (memory_access_csr_write_data_r | csr_read_data_w) :  // CSRRS
        (memory_access_csr_operation_r == `CSR_OP_RC) ? (~memory_access_csr_write_data_r & csr_read_data_w) : // CSRRC
        32'b0;
    
    // ============================
    // 27. CSR 讀取資料前遞邏輯
    // ============================
    assign csr_read_data_forwarded_w = 
        (memory_access_csr_instruction_r && csr_write_enable_w && 
         memory_access_csr_address_r == write_back_csr_address_r) ?
        csr_write_data_w : csr_read_data_w;
    
    // ============================
    // 28. 陷阱返回 PC 計算邏輯
    // ============================
    assign trap_return_pc_w = 
        (alu_stall_request_w) ? execute_pc_r :
        (software_exception_w) ? instruction_decode_pc_r :        // 軟體例外: 返回當前指令
        (delayed_interrupt_w) ? interrupt_program_counter_r :     // 延遲中斷: 返回保存的 PC
        (immediate_interrupt_w && execute_valid_r) ? execute_pc_r : // 即時中斷且 EX 有指令
        (immediate_interrupt_w && instruction_decode_valid_r) ? instruction_decode_pc_r : // 即時中斷且 ID 有指令
        program_counter_r;                                        // 預設
    
    // ============================
    // 29. 例外原因與值生成邏輯
    // ============================
    wire any_interrupt_w = immediate_interrupt_w || delayed_interrupt_w;
    
    always @(*) begin
        if (illegal_instruction_w) begin
            exception_cause_r = `EXC_CAUSE_ILLEGAL_INST;  // 非法指令
            exception_tval_r = instruction_decode_inst_r;
        end    
        else if (system_instruction_w) begin
            case (instruction_decode_inst_r)
                `SYSTEM_ECALL: begin  // ECALL
                    exception_cause_r = `EXC_CAUSE_ECALL_M_MODE;
                    exception_tval_r = 32'h0;
                end
                `SYSTEM_EBREAK: begin  // EBREAK
                    exception_cause_r = `EXC_CAUSE_BREAKPOINT;
                    exception_tval_r = 32'h0;
                end
                default: begin
                    exception_cause_r = `EXC_CAUSE_ILLEGAL_INST;
                    exception_tval_r = instruction_decode_inst_r;
                end
            endcase
        end
        else if (any_interrupt_w) begin 
            if (timer_interrupt_final_w) exception_cause_r = `INT_CAUSE_MTI;  // 計時器中斷
            else if (uart_interrupt_final_w) exception_cause_r = `INT_CAUSE_UART;  // UART 中斷
            else exception_cause_r = 32'h0;
            
            exception_tval_r = 32'h0;
        end 
        else begin
            exception_cause_r = 32'h0;
            exception_tval_r = 32'h0;
        end
    end
    
    // ============================
    // 30. 計時器中斷觸發邏輯
    // ============================
    wire timer_interrupt_trigger_w = machine_status_interrupt_enable_w && 
                                     machine_interrupt_enable_w[7] && timer_interrupt_raw_w;
    
    // ============================
    // 主要時序邏輯
    // ============================
    
    // IF 階段: 程式計數器更新
    always @(posedge core_clk_i or negedge core_reset_ni) begin
        if (!core_reset_ni) begin
            program_counter_r <= 32'h0;
        end else if (!pipeline_stall_r) begin
            program_counter_r <= next_program_counter_w;
        end
    end
    
    // ID 階段: 指令解碼暫存器
    always @(posedge core_clk_i or negedge core_reset_ni) begin
        if (!core_reset_ni || pipeline_flush_w) begin 
            instruction_decode_pc_r <= 32'h0;
            instruction_decode_inst_r <= 32'h00000013; // nop
            instruction_decode_valid_r <= 1'b0; 
        end else if (!pipeline_stall_r) begin 
            instruction_decode_pc_r <= program_counter_r;
            instruction_decode_inst_r <= instruction_fetch_data_w;
            instruction_decode_valid_r <= 1'b1; 
        end
    end
    
    // EX 階段: 執行暫存器
    always @(posedge core_clk_i or negedge core_reset_ni) begin
        if (!core_reset_ni || pipeline_flush_w) begin
            // 重置所有 EX 階段暫存器
            execute_pc_r <= 32'h0;
            execute_rd_address_r <= 5'h0;
            execute_register_write_enable_r <= 1'b0;
            execute_memory_write_enable_r <= 1'b0;
            execute_branch_operation_r <= 1'b0;
            execute_jump_and_link_r <= 1'b0;
            execute_jump_and_link_register_r <= 1'b0;
            execute_load_operation_r <= 1'b0;
            execute_load_upper_immediate_r <= 1'b0;
            execute_add_upper_immediate_to_pc_r <= 1'b0;
            execute_alu_operation_r <= 4'b0;
            execute_csr_instruction_r <= 1'b0;
            execute_valid_r <= 1'b0;
            execute_function_3_r <= 3'b0;
        end else if (alu_stall_request_w) begin
            // ALU 暫停時保持原值
        end else if (load_hazard_w) begin
            // 載入危險時插入氣泡
            execute_valid_r <= 1'b0;
            execute_register_write_enable_r <= 1'b0;
            execute_memory_write_enable_r <= 1'b0;
            execute_branch_operation_r <= 1'b0;
            execute_jump_and_link_r <= 1'b0;
            execute_jump_and_link_register_r <= 1'b0;
            execute_rd_address_r <= 5'h0;
            execute_csr_instruction_r <= 1'b0;
        end else begin
            // 正常傳遞
            execute_pc_r <= instruction_decode_pc_r;
            execute_immediate_r <= immediate_value_w;
            execute_rd_address_r <= rd_address_w;
            execute_rs1_address_r <= rs1_address_w;
            execute_rs2_address_r <= rs2_address_w;
            execute_function_3_r <= function_3_w;
            execute_alu_operation_r <= alu_operation_w;
            execute_alu_source_b_select_r <= alu_source_b_select_w;
            execute_memory_write_enable_r <= store_operation_w;
            execute_register_write_enable_r <= instruction_decode_register_write_enable_w;
            execute_load_operation_r <= load_operation_w;
            execute_jump_and_link_r <= jump_and_link_w;
            execute_jump_and_link_register_r <= jump_and_link_register_w;
            execute_branch_operation_r <= branch_operation_w;
            execute_load_upper_immediate_r <= load_upper_immediate_w;
            execute_add_upper_immediate_to_pc_r <= add_upper_immediate_to_pc_w;
            execute_rs1_data_r <= instruction_decode_rs1_data_forwarded_w;
            execute_rs2_data_r <= instruction_decode_rs2_data_forwarded_w;
            execute_csr_instruction_r <= csr_instruction_w;
            execute_csr_operation_r <= csr_operation_type_w;
            execute_csr_use_immediate_r <= csr_use_immediate_w;
            execute_csr_address_r <= csr_address_w;
            execute_valid_r <= instruction_decode_valid_r;
        end
    end
    
    // MEM 階段: 記憶體存取暫存器
    always @(posedge core_clk_i or negedge core_reset_ni) begin
        if (!core_reset_ni || machine_return_taken_w) begin
            // 重置所有 MEM 階段暫存器
            memory_access_alu_result_r <= 32'h0;
            memory_access_rs2_data_r <= 32'h0;
            memory_access_rd_address_r <= 5'h0;
            memory_access_pc_plus_4_r <= 32'h0;
            memory_access_memory_write_enable_r <= 1'b0;
            memory_access_register_write_enable_r <= 1'b0;
            memory_access_load_operation_r <= 1'b0;
            memory_access_jump_or_jalr_r <= 1'b0;
            memory_access_load_upper_immediate_r <= 1'b0;
            memory_access_function_3_r <= 3'b0;
            memory_access_csr_instruction_r <= 1'b0;
            memory_access_csr_operation_r <= 2'b0;
            memory_access_csr_use_immediate_r <= 1'b0;
            memory_access_csr_address_r <= 12'b0;
            memory_access_csr_write_data_r <= 32'b0;
            memory_access_valid_r <= 1'b0;
        end else if (alu_stall_request_w) begin
            memory_access_valid_r <= 1'b0;
            memory_access_register_write_enable_r <= 1'b0;
            memory_access_memory_write_enable_r <= 1'b0;
            memory_access_jump_or_jalr_r <= 1'b0;
        end else begin
            memory_access_alu_result_r <= alu_result_w;
            memory_access_rs2_data_r <= rs2_data_forwarded_w;
            memory_access_rd_address_r <= execute_rd_address_r;
            memory_access_pc_plus_4_r <= execute_pc_r + 4;
            memory_access_memory_write_enable_r <= execute_memory_write_enable_r;
            memory_access_register_write_enable_r <= execute_register_write_enable_r;
            memory_access_load_operation_r <= execute_load_operation_r;
            memory_access_jump_or_jalr_r <= (execute_jump_and_link_r || execute_jump_and_link_register_r);
            memory_access_load_upper_immediate_r <= execute_load_upper_immediate_r;
            memory_access_function_3_r <= execute_function_3_r;
            memory_access_csr_instruction_r <= execute_csr_instruction_r;
            memory_access_csr_operation_r <= execute_csr_operation_r;
            memory_access_csr_write_data_r <= (execute_csr_use_immediate_r) ? 
                                              execute_immediate_r : execute_rs1_forwarded_w;
            memory_access_csr_use_immediate_r <= execute_csr_use_immediate_r;
            memory_access_csr_address_r <= execute_csr_address_r;
            memory_access_valid_r <= execute_valid_r;
        end
    end
    
    // WB 階段: 寫回暫存器
    always @(posedge core_clk_i or negedge core_reset_ni) begin
        if (!core_reset_ni) begin
            // 重置所有 WB 階段暫存器
            write_back_memory_read_data_r <= 32'h0;
            write_back_alu_result_r <= 32'h0;
            write_back_rd_address_r <= 5'h0;
            write_back_pc_plus_4_r <= 32'h0;
            write_back_register_write_enable_r <= 1'b0;
            write_back_load_operation_r <= 1'b0;
            write_back_jump_or_jalr_r <= 1'b0;
            write_back_csr_instruction_r <= 1'b0;
            write_back_csr_operation_r <= 2'b0;
            write_back_csr_use_immediate_r <= 1'b0;
            write_back_csr_address_r <= 12'b0;
            write_back_valid_r <= 1'b0;
            write_back_is_ram_address_r <= 1'b0;
        end else begin
            write_back_memory_read_data_r <= memory_access_final_read_data_w;
            write_back_alu_result_r <= memory_access_alu_result_r;
            write_back_rd_address_r <= memory_access_rd_address_r;
            write_back_pc_plus_4_r <= memory_access_pc_plus_4_r;
            write_back_register_write_enable_r <= memory_access_register_write_enable_r;
            write_back_load_operation_r <= memory_access_load_operation_r;
            write_back_jump_or_jalr_r <= memory_access_jump_or_jalr_r;
            write_back_csr_instruction_r <= memory_access_csr_instruction_r;
            write_back_csr_operation_r <= memory_access_csr_operation_r;
            write_back_csr_use_immediate_r <= memory_access_csr_use_immediate_r;
            write_back_csr_address_r <= memory_access_csr_address_r;
            write_back_valid_r <= memory_access_valid_r;
            write_back_is_ram_address_r <= is_ram_address_w;
        end
    end
    
    // ============================
    // 輔助時序邏輯
    // ============================
    
    // 中斷延遲保護邏輯
    always @(posedge core_clk_i or negedge core_reset_ni) begin
        if (!core_reset_ni) begin
            interrupt_pending_r <= 1'b0;
            interrupt_program_counter_r <= 32'b0;
        end else begin
            // 如果中斷發生但 MEM 階段忙碌，延遲處理
            if (immediate_interrupt_w && (memory_access_memory_write_enable_r || memory_access_load_operation_r)) begin
                interrupt_pending_r <= 1'b1;
                // 記錄當前的 PC
                if (execute_valid_r) interrupt_program_counter_r <= execute_pc_r;
                else if (instruction_decode_valid_r) interrupt_program_counter_r <= instruction_decode_pc_r;
                else interrupt_program_counter_r <= program_counter_r;
            end 
            // MEM 階段完成，觸發延遲的中斷
            else if (interrupt_pending_r && !(memory_access_memory_write_enable_r || memory_access_load_operation_r)) begin
                interrupt_pending_r <= 1'b0;
            end
            // 如果已經處理了例外，清除掛起標誌
            else if (final_exception_taken_w) begin
                interrupt_pending_r <= 1'b0;
            end
        end
    end
    
    // 計數器更新邏輯
    always @(posedge core_clk_i or negedge core_reset_ni) begin
        if (!core_reset_ni) begin 
            cycle_counter_r <= 32'h0;
            instruction_counter_r <= 32'h0; 
        end else begin 
            cycle_counter_r <= cycle_counter_r + 1;
            if (write_back_valid_r) begin
                instruction_counter_r <= instruction_counter_r + 1;
            end
        end
    end
    
    // 計時器更新邏輯
    always @(posedge core_clk_i or negedge core_reset_ni) begin
        if (!core_reset_ni) begin
            machine_time_r <= 64'b0;
        end else begin
            machine_time_r <= machine_time_r + 1'b1;
        end
    end
    
    // mtimecmp 更新邏輯
    always @(posedge core_clk_i or negedge core_reset_ni) begin
        if (!core_reset_ni) begin
            machine_time_compare_r <= 64'hFFFFFFFF_FFFFFFFF;
        end else if (memory_access_memory_write_enable_r && memory_access_valid_r) begin 
            if (mem_is_mtimecmp_low_w) machine_time_compare_r[31:0] <= memory_access_rs2_data_r;
            else if (mem_is_mtimecmp_high_w) machine_time_compare_r[63:32] <= memory_access_rs2_data_r;
        end
    end
    
    // UART 中斷使能暫存器更新
    always @(posedge core_clk_i or negedge core_reset_ni) begin
        if (!core_reset_ni) begin
            uart_interrupt_enable_r <= 32'h0;
        end else if (memory_access_memory_write_enable_r && memory_access_valid_r && 
                     mem_is_uart_interrupt_enable_w) begin
            uart_interrupt_enable_r <= memory_access_rs2_data_r;
        end
    end
    
    // UART 測試模式控制
    always @(posedge core_clk_i or negedge core_reset_ni) begin
        if (!core_reset_ni) begin
            transmitter_test_enable_r <= 1'b0;
            receiver_test_enable_r <= 1'b0;
        end else if (uart_register_write_w) begin 
            transmitter_test_enable_r <= memory_access_rs2_data_r[31];
            receiver_test_enable_r <= memory_access_rs2_data_r[30]; 
        end
    end
    
    // ============================
    // 模擬調試區塊 (僅在模擬時生效)
    // ============================
`ifdef SIMULATION
    always @(posedge core_clk_i) begin
        // 监控UART中断相关信号
        static int last_uart_irq = 0;
        if (uart_int_raw_o_from_intc != last_uart_irq) begin
            $display("[UART IRQ DEBUG] Raw interrupt changed: %b -> %b at time %0t", 
                    last_uart_irq, uart_int_raw_o_from_intc, $time);
            $display("[UART IRQ DEBUG] TX pending: %b, RX pending: %b, IE: %h",
                    uart_tx_interrupt_pending_w, uart_rx_interrupt_pending_w,
                    uart_interrupt_enable_r);
            last_uart_irq = uart_int_raw_o_from_intc;
        end
        
        // 当中断触发时
        if (final_exception_taken_w && uart_interrupt_final_w) begin
            $display("[UART IRQ] UART interrupt taken at cycle %d", cycle_counter_r);
        end
    end
`endif

// ============================
// 24. 監控與除錯系統
// ============================

// 監控控制暫存器
reg [31:0] monitor_control_r;        // 監控控制暫存器
reg [31:0] pipeline_stats_r;         // 流水線統計暫存器
reg [31:0] memory_stats_r;           // 記憶體統計暫存器
reg [31:0] stack_stats_r;            // 堆疊統計暫存器
reg [31:0] perf_counters_r[0:7];     // 性能計數器陣列
reg [31:0] debug_trace_control_r;    // 除錯追蹤控制

// 統計計數器
reg [31:0] if_stall_counter_r;       // IF 階段停滯計數器
reg [31:0] id_stall_counter_r;       // ID 階段停滯計數器
reg [31:0] ex_stall_counter_r;       // EX 階段停滯計數器
reg [31:0] mem_stall_counter_r;      // MEM 階段停滯計數器
reg [31:0] wb_stall_counter_r;       // WB 階段停滯計數器
reg [31:0] total_stall_counter_r;    // 總停滯週期計數器

reg [31:0] ram_read_counter_r;       // RAM 讀取計數器
reg [31:0] ram_write_counter_r;      // RAM 寫入計數器
reg [31:0] rom_read_counter_r;       // ROM 讀取計數器
reg [31:0] uart_read_counter_r;      // UART 讀取計數器
reg [31:0] uart_write_counter_r;     // UART 寫入計數器

reg [31:0] branch_taken_counter_r;   // 分支成立計數器
reg [31:0] branch_mispred_counter_r; // 分支預測錯誤計數器
reg [31:0] jump_counter_r;           // 跳躍指令計數器
reg [31:0] exception_counter_r;      // 例外發生計數器
reg [31:0] interrupt_counter_r;      // 中斷發生計數器

// 堆疊監控
reg [31:0] stack_min_r;              // 堆疊最小地址（使用深度）
reg [31:0] stack_max_r;              // 堆疊最大地址（起始地址）
reg [31:0] stack_high_watermark_r;   // 堆疊高水位標記
reg [31:0] stack_current_usage_r;    // 當前堆疊使用量
reg        stack_overflow_detected_r;// 堆疊溢位偵測標誌

// 流水線氣泡計數器
reg [31:0] pipeline_bubble_counter_r;// 流水線氣泡計數器
reg [31:0] data_hazard_counter_r;    // 資料相依性危險計數器
reg [31:0] control_hazard_counter_r; // 控制相依性危險計數器

// ============================
// 流水線監控邏輯
// ============================

// 流水線停滯監控
always @(posedge core_clk_i) begin
    if (!core_reset_ni) begin
        if_stall_counter_r <= 32'h0;
        id_stall_counter_r <= 32'h0;
        ex_stall_counter_r <= 32'h0;
        mem_stall_counter_r <= 32'h0;
        wb_stall_counter_r <= 32'h0;
        total_stall_counter_r <= 32'h0;
    end else begin
        // IF 階段停滯（PC 沒有更新）
        if (pipeline_stall_r && next_program_counter_w == program_counter_r) begin
            if_stall_counter_r <= if_stall_counter_r + 1;
        end
        
        // ID 階段停滯
        if (pipeline_stall_r && instruction_decode_valid_r) begin
            id_stall_counter_r <= id_stall_counter_r + 1;
        end
        
        // EX 階段停滯
        if (alu_stall_request_w) begin
            ex_stall_counter_r <= ex_stall_counter_r + 1;
        end
        
        // MEM 階段停滯（等待記憶體）
        if (memory_access_load_operation_r && memory_access_valid_r) begin
            mem_stall_counter_r <= mem_stall_counter_r + 1;
        end
        
        // WB 階段停滯（暫存器寫入衝突）
        if (write_back_register_write_enable_r && 
            ((write_back_rd_address_r == rs1_address_w && rs1_address_w != 0) ||
             (write_back_rd_address_r == rs2_address_w && rs2_address_w != 0))) begin
            wb_stall_counter_r <= wb_stall_counter_r + 1;
        end
        
        // 總停滯計數
        if (pipeline_stall_r) begin
            total_stall_counter_r <= total_stall_counter_r + 1;
        end
    end
end

// 流水線氣泡監控
always @(posedge core_clk_i) begin
    if (!core_reset_ni) begin
        pipeline_bubble_counter_r <= 32'h0;
    end else if (load_hazard_w && !pipeline_stall_r) begin
        // 載入危險導致氣泡
        pipeline_bubble_counter_r <= pipeline_bubble_counter_r + 1;
    end
end

// 資料相依性危險監控
always @(posedge core_clk_i) begin
    if (!core_reset_ni) begin
        data_hazard_counter_r <= 32'h0;
    end else if (load_hazard_w) begin
        data_hazard_counter_r <= data_hazard_counter_r + 1;
    end
end

// 控制相依性危險監控
always @(posedge core_clk_i) begin
    if (!core_reset_ni) begin
        control_hazard_counter_r <= 32'h0;
    end else if (execute_take_branch_w) begin
        control_hazard_counter_r <= control_hazard_counter_r + 1;
    end
end

// ============================
// 分支與跳躍監控
// ============================

always @(posedge core_clk_i) begin
    if (!core_reset_ni) begin
        branch_taken_counter_r <= 32'h0;
        branch_mispred_counter_r <= 32'h0;
        jump_counter_r <= 32'h0;
    end else begin
        // 分支成立計數
        if (execute_branch_operation_r && branch_condition_met_r) begin
            branch_taken_counter_r <= branch_taken_counter_r + 1;
        end
        
        // 分支預測錯誤（需要刷新流水線）
        if (execute_take_branch_w && pipeline_flush_w) begin
            branch_mispred_counter_r <= branch_mispred_counter_r + 1;
        end
        
        // 跳躍指令計數
        if (execute_jump_and_link_r || execute_jump_and_link_register_r) begin
            jump_counter_r <= jump_counter_r + 1;
        end
    end
end

// ============================
// RAM 存取監控
// ============================

always @(posedge core_clk_i) begin
    if (!core_reset_ni) begin
        ram_read_counter_r <= 32'h0;
        ram_write_counter_r <= 32'h0;
    end else begin
        // RAM 讀取計數
        if (memory_access_load_operation_r && is_ram_address_w) begin
            ram_read_counter_r <= ram_read_counter_r + 1;
            
            // 監控 RAM 讀取地址範圍
            if (monitor_control_r[0]) begin // 啟用地址範圍檢查
                if (memory_access_alu_result_r < `RAM_BASE_ADDR || 
                    memory_access_alu_result_r >= (`RAM_BASE_ADDR + `RAM_SIZE)) begin
                    $display("[MEM MONITOR] RAM 讀取地址越界: %h", memory_access_alu_result_r);
                end
            end
        end
        
        // RAM 寫入計數
        if (actual_memory_write_enable_w) begin
            ram_write_counter_r <= ram_write_counter_r + 1;
            
            // 監控 RAM 寫入地址範圍
            if (monitor_control_r[0]) begin
                if (memory_access_alu_result_r < `RAM_BASE_ADDR || 
                    memory_access_alu_result_r >= (`RAM_BASE_ADDR + `RAM_SIZE)) begin
                    $display("[MEM MONITOR] RAM 寫入地址越界: %h", memory_access_alu_result_r);
                end
            end
            
            // 監控寫入資料模式（可選）
            if (monitor_control_r[8]) begin  // 新增一個控制位
                // 記憶體寫入監控
                if (monitor_control_r[1]) begin // 啟用資料模式檢查
                    if (memory_access_write_data_aligned_r == 32'h0) begin
                        $display("[MEM MONITOR] 寫入零值到地址: %h", memory_access_alu_result_r);
                    end
                end
            end
        end
    end
end

// ============================
// ROM 讀取監控
// ============================

always @(posedge core_clk_i) begin
    if (!core_reset_ni) begin
        rom_read_counter_r <= 32'h0;
    end else begin
        // 指令讀取（IF 階段）
        if (program_counter_r >= `ROM_BASE_ADDR && 
            program_counter_r < (`ROM_BASE_ADDR + `ROM_SIZE)) begin
            rom_read_counter_r <= rom_read_counter_r + 1;
        end
        
        // 資料讀取（MEM 階段）
        if (is_rom_data_access_w && !memory_access_memory_write_enable_r) begin
            rom_read_counter_r <= rom_read_counter_r + 1;
            
            // 監控 ROM 資料讀取地址
            if (monitor_control_r[2]) begin // 啟用 ROM 讀取監控
                if (memory_access_alu_result_r < `ROM_BASE_ADDR || 
                    memory_access_alu_result_r >= (`ROM_BASE_ADDR + `ROM_SIZE)) begin
                    $display("[ROM MONITOR] ROM 資料讀取地址越界: %h", memory_access_alu_result_r);
                end
            end
        end
    end
end

// ============================
// UART 存取監控
// ============================

always @(posedge core_clk_i) begin
    if (!core_reset_ni) begin
        uart_read_counter_r <= 32'h0;
        uart_write_counter_r <= 32'h0;
    end else begin
        // UART 讀取計數
        if (uart_read_acknowledge_w) begin
            uart_read_counter_r <= uart_read_counter_r + 1;
        end
        
        // UART 寫入計數
        if (uart_actual_transmit_enable_w) begin
            uart_write_counter_r <= uart_write_counter_r + 1;
            
            // 監控 UART 發送資料
            if (monitor_control_r[3]) begin // 啟用 UART 資料監控
                $display("[UART MONITOR] 發送字元: %c (0x%h)", 
                         memory_access_rs2_data_r[7:0], memory_access_rs2_data_r[7:0]);
            end
        end
    end
end

// ============================
// 堆疊監控系統
// ============================

// 堆疊監控初始化
task initialize_stack_monitor;
    input [31:0] stack_base;
    input [31:0] stack_size;
begin
    stack_max_r = stack_base;               // 堆疊底部（最高地址）
    stack_min_r = stack_base - stack_size;  // 堆疊頂部（最低地址）
    stack_high_watermark_r = stack_base;    // 初始高水位標記
    stack_current_usage_r = 0;              // 初始使用量為 0
    stack_overflow_detected_r = 0;          // 清除溢位標誌
end
endtask

// 監控堆疊指針變化
always @(posedge core_clk_i) begin
    if (!core_reset_ni) begin
        stack_current_usage_r <= 32'h0;
        stack_high_watermark_r <= 32'h0;
        stack_overflow_detected_r <= 1'b0;
    end else begin
        // 檢測 x2 寄存器（sp）的寫入
        if (write_back_valid_r && write_back_register_write_enable_r && 
            write_back_rd_address_r == 5'h2) begin
            
            // 計算堆疊使用量（假設堆疊向低地址增長）
            if (write_back_data_w <= stack_max_r && write_back_data_w >= stack_min_r) begin
                // 正常堆疊範圍內
                stack_current_usage_r <= stack_max_r - write_back_data_w;
                
                // 更新高水位標記
                if (write_back_data_w < stack_high_watermark_r) begin
                    stack_high_watermark_r <= write_back_data_w;
                end
                
                // 檢查堆疊溢位（接近堆疊頂部）
                if (write_back_data_w < (stack_min_r + 32)) begin
                    //$display("[STACK MONITOR] 警告：堆疊接近溢位！SP=%h, 剩餘空間=%h",
                    //         write_back_data_w, write_back_data_w - stack_min_r);
                end
            end else begin
                // 堆疊指針越界
                stack_overflow_detected_r <= 1'b1;
                //$display("[STACK MONITOR] 錯誤：堆疊指針越界！SP=%h, 有效範圍=[%h,%h]",
                //         write_back_data_w, stack_min_r, stack_max_r);
            end
        end
    end
end

// 堆疊使用率計算
function [31:0] calculate_stack_usage_percentage;
    input [31:0] stack_size;
begin
    if (stack_size == 0) begin
        calculate_stack_usage_percentage = 0;
    end else begin
        // 計算使用百分比（0-100）
        calculate_stack_usage_percentage = (stack_current_usage_r * 100) / stack_size;
    end
end
endfunction

// ============================
// 例外與中斷監控
// ============================

always @(posedge core_clk_i) begin
    if (!core_reset_ni) begin
        exception_counter_r <= 32'h0;
        interrupt_counter_r <= 32'h0;
    end else begin
        // 例外發生計數
        if (software_exception_w || illegal_instruction_w) begin
            exception_counter_r <= exception_counter_r + 1;
            
            // 例外詳細資訊記錄
            if (monitor_control_r[4]) begin // 啟用例外監控
                $display("[EXCEPTION MONITOR] 例外發生: PC=%h, 原因=%h, 指令=%h",
                         instruction_decode_pc_r, exception_cause_r, instruction_decode_inst_r);
            end
        end
        
        // 中斷發生計數
        if (final_exception_taken_w && (timer_interrupt_final_w || uart_interrupt_final_w)) begin
            interrupt_counter_r <= interrupt_counter_r + 1;
            
            // 中斷詳細資訊記錄
            if (monitor_control_r[5]) begin // 啟用中斷監控
                $display("[INTERRUPT MONITOR] 中斷發生: 類型=%s, PC=%h",
                         timer_interrupt_final_w ? "定時器" : "UART", trap_return_pc_w);
            end
        end
    end
end

always @(posedge core_clk_i) begin
    if (!core_reset_ni) begin
        for (int i = 0; i < 8; i = i + 1) begin
            perf_counters_r[i] <= 32'h0;
        end
    end else begin
        // 計數器 0: 總指令數
        if (write_back_valid_r) begin
            perf_counters_r[0] <= perf_counters_r[0] + 1;
        end
        
        // 計數器 1: 總週期數
        perf_counters_r[1] <= perf_counters_r[1] + 1;
        
        // 計數器 2: 停滯週期數
        if (pipeline_stall_r) begin
            perf_counters_r[2] <= perf_counters_r[2] + 1;
        end
        
        // 計數器 3: 記憶體存取次數
        if (ram_read_counter_r + ram_write_counter_r > perf_counters_r[3]) begin
            perf_counters_r[3] <= ram_read_counter_r + ram_write_counter_r;
        end
        
        // 計數器 4: 分支預測錯誤率（每 1000 條指令）
        if (perf_counters_r[0] % 1000 == 0 && perf_counters_r[0] > 0) begin
            if (branch_mispred_counter_r > 0) begin
                perf_counters_r[4] <= (branch_mispred_counter_r * 100) / 1000;
            end
        end
        
        // 計數器 5: CPI（Cycles Per Instruction）
        if (perf_counters_r[0] > 0) begin
            perf_counters_r[5] <= perf_counters_r[1] / perf_counters_r[0];
        end
    end
end

// ============================
// 監控 CSR 暫存器存取邏輯
// ============================

wire is_monitor_csr_w = (memory_access_csr_address_r >= 12'h7C0 && 
                         memory_access_csr_address_r <= 12'h7CF);

// ============================
// CSR 讀取資料多工器
// ============================

reg [31:0] monitor_csr_read_data_w;

// 監控 CSR 讀取邏輯
always @(*) begin
    if (memory_access_csr_instruction_r && is_monitor_csr_w) begin
        case (memory_access_csr_address_r)
            `CSR_MONITOR_CTRL:    monitor_csr_read_data_w = monitor_control_r;
            `CSR_PIPELINE_STATS:  monitor_csr_read_data_w = {total_stall_counter_r[15:0], 
                                                     pipeline_bubble_counter_r[15:0]};
            `CSR_MEMORY_STATS:    monitor_csr_read_data_w = {ram_read_counter_r[15:0], 
                                                     ram_write_counter_r[15:0]};
            `CSR_STACK_STATS:     monitor_csr_read_data_w = stack_current_usage_r;
            `CSR_PERF_COUNTERS:   begin
                // 根據地址低3位選擇性能計數器
                case (memory_access_csr_address_r[2:0])
                    3'b000: monitor_csr_read_data_w = perf_counters_r[0];
                    3'b001: monitor_csr_read_data_w = perf_counters_r[1];
                    3'b010: monitor_csr_read_data_w = perf_counters_r[2];
                    3'b011: monitor_csr_read_data_w = perf_counters_r[3];
                    3'b100: monitor_csr_read_data_w = perf_counters_r[4];
                    3'b101: monitor_csr_read_data_w = perf_counters_r[5];
                    3'b110: monitor_csr_read_data_w = perf_counters_r[6];
                    3'b111: monitor_csr_read_data_w = perf_counters_r[7];
                    default: monitor_csr_read_data_w = 32'h0;
                endcase
            end
            `CSR_DEBUG_TRACE:     monitor_csr_read_data_w = debug_trace_control_r;
            default:              monitor_csr_read_data_w = 32'h0;
        endcase
    end else begin
        monitor_csr_read_data_w = 32'h0;
    end
end

// 最終 CSR 讀取資料選擇
assign csr_read_data_w = (memory_access_csr_instruction_r && is_monitor_csr_w) ? 
                         monitor_csr_read_data_w : 
                         csr_read_data_from_module_w;

// 監控 CSR 寫入處理
always @(posedge core_clk_i or negedge core_reset_ni) begin
    if (!core_reset_ni) begin
        monitor_control_r <= 32'h0;
        debug_trace_control_r <= 32'h0;
    end else if (csr_write_enable_w && is_monitor_csr_w) begin
        case (memory_access_csr_address_r)
            `CSR_MONITOR_CTRL:    monitor_control_r <= csr_write_data_w;
            `CSR_DEBUG_TRACE:     debug_trace_control_r <= csr_write_data_w;
        endcase
    end
end

// ============================
// 指令執行追蹤系統
// ============================

reg [31:0] trace_buffer_r[0:63];    // 追蹤緩衝區
reg [5:0]  trace_index_r;           // 追蹤索引
reg        trace_enabled_r;         // 追蹤啟用標誌

always @(posedge core_clk_i) begin
    if (!core_reset_ni) begin
        trace_index_r <= 6'h0;
        trace_enabled_r <= 1'b0;
    end else begin
        // 更新追蹤啟用狀態
        trace_enabled_r <= debug_trace_control_r[0];
        
        // 記錄指令執行追蹤
        if (trace_enabled_r && write_back_valid_r && write_back_register_write_enable_r) begin
            // 格式: [31:26] 階段標記, [25:21] 目標寄存器, [20:0] 資料或PC
            trace_buffer_r[trace_index_r] = {
                6'h1,  // WB 階段標記
                write_back_rd_address_r,
                21'h0
            };
            
            // 如果是 JAL/JALR，記錄返回地址
            if (write_back_jump_or_jalr_r) begin
                trace_buffer_r[trace_index_r][20:0] = write_back_pc_plus_4_r[20:0];
            end
            
            trace_index_r <= trace_index_r + 1;
            
            // 緩衝區循環
            if (trace_index_r == 6'd63) begin
                trace_index_r <= 6'h0;
                
                // 輸出追蹤資訊（模擬時）
                `ifdef SIMULATION
                $display("[TRACE] 追蹤緩衝區已滿，輸出最近64條記錄");
                for (int i = 0; i < 64; i = i + 1) begin
                    $display("  [%2d] %h", i, trace_buffer_r[i]);
                end
                `endif
            end
        end
    end
end

    
endmodule