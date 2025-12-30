// =============================================================================
// BearCore-V IVerilog 編譯清單 (更新路徑版)
// =============================================================================

// 🏆 1. 核心硬體原始碼 (RTL)
./src/core.v
./src/alu.v
./src/decoder.v
./src/reg_file.v
./src/csr_registers.v
./src/rom.v
./src/data_ram.v
./src/uart_tx.v
./src/uart_rx.v
./src/div_unit.v

// 🏆 2. 驗證與測試環境 (Testbench)
./tests/bench/tb_top.v

// 🏆 3. 其他可能需要的包含路徑
// -I./src/include
