# 🐻 BearCore-V: High-Performance 1-T RISC-V Processor

![BearCore-V Demo](assets/bearcore_demo.gif)

BearCore-V 是一個高效能、具備單週期吞吐量 (1-T) 特性的 32-bit RISC-V 處理器核心。本專案從底層 RTL 電路開發、例外處理機制建立，到綜合測試套件驗證，實現了一個工業級 MCU 核心的完整開發流程。

## 🌟 核心亮點 (Project Highlights)
- **1-T 吞吐量設計**：優化的五級流水線架構，目標運行頻率達 **100MHz**。
- **完善的例外機制**：支援 Synchronous Exceptions (ECALL/Illegal Inst) 與 Asynchronous Interrupts (Timer)。
- **硬體自檢能力 (BIST)**：內建 UART 硬體環回測試與字串自動校準比對演算法。
- **跨平台開發**：開發與驗證環境完全基於 WSL (Ubuntu) 下的 RISC-V Toolchain。

## 🚀 系統規格 (Specifications)
| 類別 | 詳細內容 |
| :--- | :--- |
| **指令集 (ISA)** | RISC-V RV32IM (Integer + Multiplication/Division) |
| **流水線 (Pipeline)** | 5-Stage (IF/ID/EX/MEM/WB) 與預取沖刷 (Flush) 機制 |
| **記憶體 (Memory)** | 64KB ROM (0x0) / 64KB RAM (0x10000) 分離位址空間 |
| **時鐘與計時器** | 64-bit MTIME/MTIMECMP 高精度定時器 |
| **通訊週邊** | 高速 UART (支援 1152000 Baudrate) |



## 🧪 驗證成果 (Validation Results)
BearCore-V 通過了一套包含 30 個測項的綜合測試套件 (30-in-1 Test Suite)，確保了運算正確性與系統穩定性：

| 測試分類 | 狀態 | 驗證內容 |
| :--- | :---: | :--- |
| **ALU 運算** | ✅ PASS | 加減、邏輯位移、大小比較 |
| **控制流** | ✅ PASS | 分支跳轉 (Branch)、遞迴堆疊 (Recursion) |
| **乘除法 (M-Ext)** | ✅ PASS | 32/64-bit 乘法、除法、餘數運算 |
| **記憶體存取** | ✅ PASS | Word/Byte 存取與對齊驗證 |
| **例外與中斷** | ✅ PASS | ECALL Trap 與 Timer Interrupt 回應處理 |
| **硬體 BIST** | ✅ PASS | UART 硬體字串環回自動比對 (15/15 Match) |

## 🛠️ 技術挑戰與解決方案 (Engineering Challenges)

### 1. 解決流水線沖刷造成的 Reset 靈異現象
- **挑戰**：當中斷發生在跳轉指令後的 Flush 週期時，`id_pc` 會被清零，導致中斷存入錯誤的返回位址 (`mepc=0`)，造成系統不斷重啟。
- **方案**：實作 **Smart Trap-PC Selector**。判斷當前流水線有效性，若處於 Flush 狀態則抓取目前抓取的 PC 作為返回點，確保 `mret` 平安返回。

### 2. 中斷重入與 UART 資源競爭
- **挑戰**：在計時器中斷處理器 (ISR) 中使用 UART 列印，會與主程式產生資源衝突並導致系統死鎖。
- **方案**：採用 **Flag-based ISR 設計**。ISR 僅負責狀態旗標與硬體清理，由主程式邏輯負責資訊輸出，徹底消除非同步衝突。

### 3. UART BIST 硬體/軟體同步比對
- **挑戰**：啟動硬體測試模式的寫入脈衝會干擾資料流，導致字串位移或遺失。
- **方案**：在硬體端分離控制與發送訊號，並在軟體端實作「滑動視窗對齊演算法 (Sliding Window Match)」，實現 100% 正確的自動化驗證。



## 📂 專案結構 (Directory Structure)
- `core.v`: 處理器核心主體 (RTL)
- `uart_tx.v` & `uart_rx.v`: 高階 UART 通訊模組
- `start.s`: 系統啟動與例外入口 (Assembly)
- `main.c`: 整合驗證韌體 (C)
- `link.ld`: 記憶體連結配置

## 🔧 如何運行 (Getting Started)
1. 安裝 RISC-V Toolchain 與 Icarus Verilog。
2. 執行 `make clean && make all` 編譯硬體與韌體。
3. 執行 `make sim` 啟動動態模擬驗證。

---
感謝小熊寶 AI 思路夥伴在開發過程中的協同除錯與架構建議。