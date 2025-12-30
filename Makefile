# --- 1. 路徑與工具定義 ---
PROJ_ROOT := $(shell pwd)
SRC_DIR   := $(PROJ_ROOT)/sw
# 🏆 修正：明確指向 src/ 下的原始碼 
SW_SOURCES := $(SRC_DIR)/start.s $(SRC_DIR)/main.c

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
CFLAGS   = -march=rv32im -mabi=ilp32 -O0 -g -nostdlib -nostartfiles -ffreestanding
INCLUDES = -I./src/include
# 🏆 確保連結 link.ld 
LDFLAGS  = -T sw/link.ld -Wl,--gc-sections

# --- 3. 預設目標流程 ---
# 順序：編譯 -> 反彙編 -> 佈局檢查 -> 動態內容檢查 -> 生成 HEX

MAX_ROM_SIZE = 65536  # 🏆 64KB (16384 * 4)

# 🏆 新增：波形控制旗標
# 預設為空 (不錄波形)
USER_DEFINES = 

# 如果輸入 "make sim WAVE=1" 則加入 -DWAVEFORM 參數
ifeq ($(WAVE), 1)
    USER_DEFINES += -DWAVEFORM
endif

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

firmware.elf: $(SW_SOURCES) sw/link.ld
	$(CC) $(CFLAGS) $(INCLUDES) -DSIMULATION $(SW_SOURCES) $(LDFLAGS) -o $@
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

# 🏆 自動搜尋模擬日誌中的關鍵字
verify_sim:
	@echo "--- 正在驗證模擬結果 ---"
	@if grep -q "Result: PASS=31" simulation.log; then \
		echo "✅ [硬體驗證通過] "; \
		# grep "EXCEPTION DETECTED" simulation.log; \
	else \
		echo "❌ [硬體驗證失敗] "; \
		exit 1; \
	fi	

# --- 6. 清理 ---
clean:
	rm -f *.elf *.bin *.hex *.vvp *.vcd *.fst *.disasm *.symbols *.map
	@echo "清理完成"

.PHONY: all clean sim verify_sim