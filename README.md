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


## 快速開始

### 1. 環境設置
```bash
# 安裝 RISC-V 工具鏈
sudo apt-get install gcc-riscv64-unknown-elf

# 安裝模擬工具
sudo apt-get install iverilog gtkwave
2. 編譯與運行
bash
# 編譯韌體
make clean && make all

# 運行硬體模擬
make sim

# 查看波形
gtkwave cpu.vcd

3. Python 指令級模擬
bash
python riscv_ils.py --rom firmware.hex --max-cycles 10000

專案結構## 📂 專案結構 (File Structure)
├── Makefile
├── README.md
├── cpu.vcd
├── docs
│   └── ARCHITECTURE.md
├── files.f
├── firmware.bin
├── firmware.elf
├── firmware.hex
├── link.ld
├── project_config.mk
├── riscv_ils.py
├── scripts
│   └── run_simulation.sh
├── src
│   ├── alu.v
│   ├── core.v
│   ├── data_ram.v
│   ├── decoder.v
│   ├── include
│   │   └── test_reporter.h
│   ├── main.c
│   ├── reg_file.v
│   ├── rom.v
│   ├── start.s
│   ├── tb_top.v
│   └── uart_tx.v
├── tests
│   ├── direct_test.s
│   ├── jump_test.S
│   ├── minimal.c
│   ├── simplest.s
│   ├── test.c
│   ├── test.s
│   ├── test_main.c
│   ├── test_only_jump.s
│   ├── test_reporter.c
│   ├── timer_test.c
│   └── trap_handler.c
└── wave.vvp

5 directories, 35 files

性能指標
CPI: 1.0 (理想流水線)

最大頻率: 100MHz (估計)

支援指令: RV32IM

記憶體: 16KB ROM + 64KB RAM

測試結果
✓ 整數運算 ✓ 除法指令 ✓ 字串操作 ✓ UART輸出

text

### 5. **創建一個自動化腳本**
```bash
#!/bin/bash
# scripts/run_all.sh

echo "=== BearCore-V 完整測試流程 ==="
echo "1. 編譯韌體..."
make clean
make all

echo -e "\n2. 運行 Python 指令級模擬..."
python riscv_ils.py --rom firmware.hex --max-cycles 50000

echo -e "\n3. 運行 Verilog 模擬..."
iverilog -g2012 -o wave.vvp -f files.f
vvp wave.vvp

echo -e "\n4. 分析結果..."
echo "如果看到 'Test OK' 和正確的反轉字串，測試通過！"