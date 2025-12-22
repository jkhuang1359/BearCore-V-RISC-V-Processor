# 1. 工具鏈定義
CROSS_COMPILE = riscv64-unknown-elf-
CC      = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy

# 2. 編譯選項 (支援 M 擴展)
CFLAGS = -march=rv32im -mabi=ilp32 -O0 -g -nostdlib -nostartfiles -ffreestanding

# 3. 路徑定義
SRC_DIR = src
LINKER_SCRIPT = link.ld

all: firmware.hex

# 4. 連結與編譯 (直接產出 elf)
# 🏆 這裡我們不再建立 build 資料夾，直接原地編譯
firmware.elf: $(SRC_DIR)/start.s $(SRC_DIR)/main.c $(LINKER_SCRIPT)
	$(CC) $(CFLAGS) -T $(LINKER_SCRIPT) $(SRC_DIR)/start.s $(SRC_DIR)/main.c -o firmware.elf

# 5. 轉成二進位檔
firmware.bin: firmware.elf
	$(OBJCOPY) -O binary firmware.elf firmware.bin

# 6. 轉成 Verilog Hex 格式
firmware.hex: firmware.bin
	od -An -t x4 -w4 -v firmware.bin | tr -d ' ' > firmware.hex

clean:
	rm -f *.elf *.bin *.hex
	rm -rf build