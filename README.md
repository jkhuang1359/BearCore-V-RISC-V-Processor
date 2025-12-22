# 🐻 BearCore-V: A High-Performance 5-Stage RISC-V Processor

**BearCore-V** 是一個基於 **RISC-V (RV32IM)** 指令集架構設計的 5 階段管線處理器。本專案實現了從硬體描述語言 (Verilog) 到韌體開發 (C/Assembly) 以及模擬驗證 (Python/iverilog) 的完整垂直整合。

---

## 🚀 技術特性 (Technical Highlights)

* **ISA 支援**: 完整支援 **RV32I** 基礎指令集與 **M-extension** (乘法與除法)。
* **管線架構**: 採用 5-Stage (IF/ID/EX/MEM/WB) 設計，具備資料流轉發 (Forwarding) 與衝突處理 (Stall) 機制。
* **記憶體子系統**: 
    * **ROM**: 16KB 指令空間 (載入 `firmware.hex`)。
    * **RAM**: 64KB 資料空間，支援位元組對齊存取 (LB/SB/LH/SH)。
* **外設**: 整合 115200 波特率 UART 控制器，支援 MMIO 映射 (0x10000000)。

---

## 📂 專案結構 (File Structure)

```text
.
├── src/                # 硬體源碼與韌體
│   ├── core.v          # CPU 頂層模組
│   ├── alu.v           # 算術邏輯單元 (含 RV32M)
│   ├── decoder.v       # 指令譯碼器
│   ├── reg_file.v      # 暫存器堆 (32-regs)
│   ├── data_ram.v      # 資料記憶體控制
│   ├── rom.v           # 指令記憶體 (載入 hex)
│   ├── uart_tx.v       # UART 發送模組
│   ├── tb_top.v        # Testbench (含虛擬終端機)
│   ├── main.c          # C 語言測試程式 (字串反轉演算法)
│   └── start.s         # 啟動代碼 (Stack pointer 初始化)
├── Makefile            # 編譯韌體工具
├── link.ld             # 連結器腳本
├── files.f             # iverilog 檔案清單
└── riscv_ils.py        # Python 指令級模擬器 (Golden Model)

🚦 如何啟動模擬 (How to Run)
1. 編譯韌體 (需 RISC-V Toolchain)
Bash

make clean && make all

2. 執行硬體模擬 (iverilog)
Bash

# 使用 files.f 編譯並執行
iverilog -g2012 -o wave.vvp -f files.f
vvp wave.vvp

3. 查看波形
Bash

gtkwave cpu.vcd

📈 未來展望 (Future Work)
[ ] 加入分支預測器 (Branch Predictor)。

[ ] 實作 Timer 與外部中斷機制。

[ ] 支援更多 CSR 暫存器以符合完整特權架構。

### 3. 如何存入 Git？
如果你還沒建立 Repo，可以執行以下指令：

```bash
git init
git add README.md files.f src/ link.ld Makefile riscv_ils.py
git commit -m "Initial commit: BearCore-V 5-stage pipeline with UART and String Reversal test"

