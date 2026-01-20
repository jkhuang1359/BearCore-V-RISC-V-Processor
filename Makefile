# --- 1. 路徑與工具定義 ---
PROJ_ROOT := $(shell pwd)
SRC_DIR   := $(PROJ_ROOT)/sw
# 🏆 修正：明確指向 src/ 下的原始碼 
SW_SOURCES := $(SRC_DIR)/start.s $(SRC_DIR)/main.c $(SRC_DIR)/string.c

INCLUDE_DIR = $(PROJ_ROOT)/include

CROSS_COMPILE = riscv64-unknown-elf-
CC      = $(CROSS_COMPILE)gcc
NM      = $(CROSS_COMPILE)nm
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump
SIZE    = $(CROSS_COMPILE)size

# 仿真工具
IVERILOG = iverilog
VVP = vvp
WAVEVIEWER = gtkwave

# --- 2. 編譯選項 ---
BASE_CFLAGS = -march=rv32im -mabi=ilp32 -O0 -g -nostdlib -nostartfiles -ffreestanding \
             -fno-builtin -fno-builtin-function -Wall -Wno-builtin-declaration-mismatch \
             -Wno-unused-but-set-variable -Wno-implicit-function-declaration

INCLUDES = -I$(INCLUDE_DIR)

# 🏆 確保連結 link.ld 
LDFLAGS  = -T sw/link.ld -Wl,--gc-sections -nostdlib -nostartfiles

# 測試配置選項
TEST_CONFIG ?= standard  # 預設使用standard配置
CFLAGS = $(BASE_CFLAGS)

# 在Makefile中添加編譯選項
ifeq ($(TEST_CONFIG), minimal)
    CFLAGS += -DTEST_LEVEL_MINIMAL
else ifeq ($(TEST_CONFIG), standard)
    CFLAGS += -DTEST_LEVEL_STANDARD
else ifeq ($(TEST_CONFIG), comprehensive)
    CFLAGS += -DTEST_LEVEL_COMPREHENSIVE
endif

# 可以通過命令行覆蓋特定配置
ifdef DISABLE_FILESYSTEM_TESTS
    CFLAGS += -DENABLE_FILESYSTEM_TESTS=0
endif

ifdef DISABLE_NETWORK_TESTS
    CFLAGS += -DENABLE_NETWORK_TESTS=0
endif

ifdef ENABLE_DEBUG_TESTS
    CFLAGS += -DRUN_KNOWN_ISSUE_TESTS=1
endif

ifdef TEST_VERBOSITY
    CFLAGS += -DTEST_VERBOSITY=$(TEST_VERBOSITY)
endif

# 浮點測試選項
ENABLE_FLOAT_TESTS ?= 0

# 如果啟用浮點測試，添加相關的源文件和編譯選項
ifeq ($(ENABLE_FLOAT_TESTS),1)
    # 添加浮點測試源文件
    SW_SOURCES += $(SRC_DIR)/float_tests.c
    # 添加編譯標誌
    CFLAGS += -DENABLE_FLOAT_TESTS
    # 注意：我們使用標準的整數架構，讓編譯器使用軟體浮點庫
    # 不需要 -march=rv32imf，因為硬體不支援
    # 編譯器會將浮點運算轉換為軟體函數調用（如 __addsf3）
    
    # 如果出現未定義的軟體浮點函數，可能需要鏈接 libgcc
    # 但我們的 -nostdlib 可能會阻止這一點，所以我們需要小心
    # 我們將在 float_tests.c 中避免實際浮點運算來解決這個問題
endif

# --- 3. 預設目標流程 ---
# 順序：編譯 -> 反彙編 -> 佈局檢查 -> 動態內容檢查 -> 生成 HEX

MAX_ROM_SIZE = 131072  # 🏆 64KB (16384 * 4)

# 🏆 新增：波形控制旗標
# 預設為空 (不錄波形)
USER_DEFINES = 

# 如果輸入 "make sim WAVE=1" 則加入 -DWAVEFORM 參數
ifeq ($(WAVE), 1)
    USER_DEFINES += -DWAVEFORM
endif

ifeq ($(SIMU), 1)
    USER_DEFINES += -DSIMULATION
endif

# --- 測試配置目標 ---
.PHONY: test-minimal test-standard test-full test-debug test-smallrom

test-minimal:
	$(MAKE) clean
	$(MAKE) TEST_CONFIG=minimal all

test-standard:
	$(MAKE) clean
	$(MAKE) TEST_CONFIG=standard all

test-full:
	$(MAKE) clean
	$(MAKE) TEST_CONFIG=comprehensive all

# 調試模式（運行有問題的測試）
test-debug:
	$(MAKE) clean
	$(MAKE) TEST_CONFIG=comprehensive ENABLE_DEBUG_TESTS=1 all

# 小ROM版本（跳過大測試）
test-smallrom:
	$(MAKE) clean
	$(MAKE) TEST_CONFIG=standard DISABLE_FILESYSTEM_TESTS=1 DISABLE_NETWORK_TESTS=1 all

# 🏆 添加檢查 include 目錄是否存在
check_include:
	@if [ ! -d "$(INCLUDE_DIR)" ]; then \
		echo "❌ 錯誤：include 目錄不存在: $(INCLUDE_DIR)"; \
		echo "👉 請創建 include 目錄並添加必要的頭文件"; \
		exit 1; \
	fi
	@if [ ! -f "$(INCLUDE_DIR)/string.h" ]; then \
		echo "❌ 錯誤：string.h 不存在於 $(INCLUDE_DIR)"; \
		exit 1; \
	fi

check_size: firmware.elf
	@riscv64-unknown-elf-size firmware.elf
	@echo "--- 正在進行硬體尺寸驗證 ---"
	@# 提取 .text 和 .rodata 的總大小 (十進位)
	@USAGE=$$(riscv64-unknown-elf-size -A firmware.elf | grep -E "\.text|\.rodata" | awk '{sum += $$2} END {print sum}'); \
	if [ $$USAGE -gt $(MAX_ROM_SIZE) ]; then \
		echo "------------------------------------------------------------"; \
		echo "🚨 ERROR: 程式容量 ($$USAGE Bytes) 已超出 ROM 限制 ($(MAX_ROM_SIZE) Bytes)!"; \
		echo "👉 溢出空間: $$(($$USAGE - $(MAX_ROM_SIZE))) Bytes"; \
		echo "👉 解決方法: 1. 修改 link.ld 加大 ROM | 2. 修改 core.v 解碼位址 | 3. 優化 C 代碼"; \
		echo "------------------------------------------------------------"; \
		exit 1; \
	else \
		echo "✅ 尺寸驗證通過！"; \
		echo "📊 目前佔用: $$USAGE Bytes / $(MAX_ROM_SIZE) Bytes"; \
		echo "🔋 剩餘空間: $$(($(MAX_ROM_SIZE) - $$USAGE)) Bytes"; \
	fi

all: firmware.hex disasm check_layout check_hex_dynamic check_size
# --- 4. 韌體編譯規則 ---

firmware.elf: $(SW_SOURCES) sw/link.ld | check_include
	$(CC) $(CFLAGS) $(INCLUDES) $(SW_SOURCES) $(LDFLAGS) -o $@
	@echo "✅ 編譯完成: firmware.elf"
	$(SIZE) $@

firmware.bin: firmware.elf
	$(OBJCOPY) -O binary $< $@

firmware.hex: firmware.bin
	od -An -t x4 -w4 -v $< | tr -d ' ' > $@
	@echo "✅ 生成 Verilog HEX: firmware.hex"

disasm: firmware.elf
	$(OBJDUMP) -d -l firmware.elf > firmware.disasm
	@echo "✅ 生成反彙編: firmware.disasm"

# --- 5. 自動化檢查腳本 ---

# 🏆 腳本 A：驗證符號位址是否符合 link.ld 規劃
check_layout: firmware.elf
	@sync
	@echo "--- 正在驗證記憶體佈局 ---"
	$(eval ACTUAL_START=$(shell $(NM) firmware.elf | grep " _start" | awk '{print $$1}'))
	$(eval ACTUAL_VEC=$(shell $(NM) firmware.elf | grep " exception_entry" | awk '{print $$1}'))
	@if [ "$(ACTUAL_START)" != "00000000" ]; then \
		echo "❌ 錯誤：_start 位址為 $(ACTUAL_START)，應為 00000000"; exit 1; \
	fi
	@if [ "$(ACTUAL_VEC)" != "00000100" ]; then \
		echo "❌ 錯誤：exception_entry 位址為 $(ACTUAL_VEC)，應為 00000100"; exit 1; \
	fi
	@echo "✅ 佈局驗證通過 (_start: 0x0, exception_entry: 0x100)"

# 🏆 腳本 B：動態比對 Hex 內容與反彙編指令是否一致
check_hex_dynamic: firmware.hex firmware.disasm
	@echo "--- 正在進行動態 Hex 內容驗證 ---"
	@# 🏆 修正版：擴大範圍至 20 行，並精準過濾掉原始碼雜訊
	$(eval EXPECTED_CODE=$(shell grep -A 20 "<exception_entry>:" firmware.disasm | grep -E "^[[:space:]]*[0-9a-f]+:[[:space:]]+[0-9a-f]+" | head -n 1 | awk '{print $$2}'))
	
	@# 從 hex 檔案提取第 65 行 (位址 0x100)
	$(eval ACTUAL_CODE=$(shell sed -n '65p' firmware.hex))
	
	@if [ -z "$(EXPECTED_CODE)" ]; then \
		echo "❌ 錯誤：找不到 exception_entry 的實體指令 (受 -S 模式影響)"; \
		echo "👉 建議：檢查 firmware.disasm 中 exception_entry 下方是否插入過多原始碼"; \
		exit 1; \
	fi
	@if [ "$(ACTUAL_CODE)" != "$(EXPECTED_CODE)" ]; then \
		echo "❌ 錯誤：0x100 內容不匹配！"; \
		echo "👉 預期 (來自 Disasm): $(EXPECTED_CODE)"; \
		echo "👉 實際 (來自 Hex):    $(ACTUAL_CODE)"; \
		exit 1; \
	else \
		echo "✅ 動態內容驗證通過！機器碼: $(ACTUAL_CODE)"; \
	fi

# --- 模擬與自動化驗證 ---	

# 🏆 執行 IVerilog 模擬並儲存日誌
sim: all
	@echo "--- 開始 BearCore-V 硬體模擬 ---"
	$(IVERILOG) -g2012 $(USER_DEFINES) -s tb_top -o wave.vvp -f files.f
	$(VVP) wave.vvp | tee simulation.log
	@echo "--- 模擬結束，日誌已儲存至 simulation.log ---"
	@$(MAKE) verify_sim

# 不同測試配置的模擬目標
sim-minimal:
	$(MAKE) clean
	$(MAKE) TEST_CONFIG=minimal sim

sim-standard:
	$(MAKE) clean
	$(MAKE) TEST_CONFIG=standard sim

sim-full:
	$(MAKE) clean
	$(MAKE) TEST_CONFIG=comprehensive sim

sim-debug:
	$(MAKE) clean
	$(MAKE) TEST_CONFIG=comprehensive ENABLE_DEBUG_TESTS=1 sim

sim-smallrom:
	$(MAKE) clean
	$(MAKE) TEST_CONFIG=standard DISABLE_FILESYSTEM_TESTS=1 DISABLE_NETWORK_TESTS=1 sim

# 🏆 自動搜尋模擬日誌中的關鍵字
verify_sim:
	@echo "--- 正在驗證模擬結果 ---"
	@if grep -q "Result: PASS=30" simulation.log; then \
		echo "✅ [硬體驗證通過] "; \
		# grep "EXCEPTION DETECTED" simulation.log; \
	else \
		echo "❌ [硬體驗證失敗] "; \
		exit 1; \
	fi	

# --- 6. 清理 ---
clean:
	rm -f *.elf *.bin *.hex *.vvp *.vcd *.fst *.disasm *.symbols *.map simulation.log
	@echo "清理完成"

.PHONY: all clean sim verify_sim check_include
.PHONY: sim-minimal sim-standard sim-full sim-debug sim-smallrom
.PHONY: test-minimal test-standard test-full test-debug test-smallrom

.PHONY: help
help:
	@echo "BearCore-V 測試套件編譯選項"
	@echo ""
	@echo "可用目標:"
	@echo "  編譯目標:"
	@echo "    make all                  - 編譯完整韌體（預設standard配置）"
	@echo "    make test-minimal         - 最小測試集（節省ROM空間）"
	@echo "    make test-standard        - 標準測試集（推薦）"
	@echo "    make test-full            - 全面測試集"
	@echo "    make test-debug           - 調試模式（包含已知問題測試）"
	@echo "    make test-smallrom        - 小ROM版本（跳過大測試）"
	@echo ""
	@echo "  模擬目標:"
	@echo "    make sim WAVE=1           - 執行模擬並生成波形"
	@echo "    make sim-minimal          - 最小測試集模擬"
	@echo "    make sim-standard         - 標準測試集模擬"
	@echo "    make sim-full             - 全面測試集模擬"
	@echo "    make sim-debug            - 調試模式模擬"
	@echo "    make sim-smallrom         - 小ROM版本模擬"
	@echo ""
	@echo "  環境變量:"
	@echo "    TEST_CONFIG=minimal|standard|comprehensive"
	@echo "    DISABLE_FILESYSTEM_TESTS=1  跳過文件系統測試"
	@echo "    DISABLE_NETWORK_TESTS=1     跳過網絡測試"
	@echo "    ENABLE_DEBUG_TESTS=1        啟用已知問題測試"
	@echo "    TEST_VERBOSITY=0|1|2|3      測試輸出詳細程度"
	@echo "    WAVE=1                      生成波形檔"
	@echo "    ENABLE_FLOAT_TESTS=1        啟用浮點概念測試"
	@echo ""
	@echo "  示例:"
	@echo "    make test-standard"
	@echo "    make TEST_CONFIG=minimal"
	@echo "    make DISABLE_FILESYSTEM_TESTS=1"
	@echo "    make sim WAVE=1 TEST_CONFIG=standard"
	@echo "    make ENABLE_FLOAT_TESTS=1 test-standard"
	@echo ""
	@echo "  目前配置:"
	@echo "    TEST_CONFIG=$(TEST_CONFIG)"
	@if [ -n "$(DISABLE_FILESYSTEM_TESTS)" ]; then echo "    文件系統測試: 禁用"; fi
	@if [ -n "$(DISABLE_NETWORK_TESTS)" ]; then echo "    網絡測試: 禁用"; fi
	@if [ -n "$(ENABLE_DEBUG_TESTS)" ]; then echo "    調試模式: 啟用"; fi
	@if [ -n "$(ENABLE_FLOAT_TESTS)" ]; then echo "    浮點測試: 啟用"; fi