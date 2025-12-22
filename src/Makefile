# 工具鏈前綴
CROSS_COMPILE = riscv64-unknown-elf-
CC = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy

# 編譯選項
# -march=rv32i: 使用 RV32I 指令集
# -mabi=ilp32: 使用 32-bit 整數介面
# -nostdlib: 不使用標準函式庫 (我們自己寫了 start.s)
# -T link.ld: 使用我們的連結腳本
CFLAGS = -march=rv32i -mabi=ilp32 -O0 -g -nostdlib -T link.ld

all: firmware.hex

# 1. 編譯 + 連結 (將 start.s 和 main.c 變成 firmware.elf)
firmware.elf: start.s main.c link.ld
	$(CC) $(CFLAGS) start.s main.c -o firmware.elf

# 2. 轉成純二進位檔 (去掉 ELF 檔頭)
firmware.bin: firmware.elf
	$(OBJCOPY) -O binary firmware.elf firmware.bin

# 3. 轉成 Verilog 讀得懂的 Hex 格式 (每行 8 個 hex 字元)
# 這裡用一個小技巧：od (octal dump) 指令
firmware.hex: firmware.bin
	od -An -t x4 -w4 -v firmware.bin > firmware.hex

clean:
	rm -f *.elf *.bin *.hex