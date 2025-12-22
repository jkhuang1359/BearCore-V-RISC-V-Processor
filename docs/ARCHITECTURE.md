# BearCore-V 架構文檔

## 處理器特性
- 5級流水線：IF, ID, EX, MEM, WB
- 完整 RV32IM 指令集支援
- 記憶體映射 I/O
- 性能計數器

## 模組說明
- core.v: 頂層模組
- alu.v: 算術邏輯單元
- decoder.v: 指令解碼器
- reg_file.v: 寄存器堆
- data_ram.v: 數據記憶體
- rom.v: 指令記憶體
- uart_tx.v: UART發送器
