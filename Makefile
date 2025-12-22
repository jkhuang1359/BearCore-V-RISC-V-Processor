# Makefile 更新版本
CROSS_COMPILE = riscv64-unknown-elf-
CC = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy

# 編譯選項
CFLAGS = -march=rv32im -mabi=ilp32 -O0 -g -nostdlib -nostartfiles -ffreestanding -I./src/include
LDFLAGS = -T link.ld

# 源文件列表
SRCS = src/start.s src/main.c

all: firmware.hex

firmware.elf: $(SRCS) link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) $(SRCS) -o firmware.elf

firmware.bin: firmware.elf
	$(OBJCOPY) -O binary firmware.elf firmware.bin

firmware.hex: firmware.bin
	od -An -t x4 -w4 -v firmware.bin | tr -d ' ' > firmware.hex

clean:
	rm -f *.elf *.bin *.hex *.vvp

sim: firmware.hex
	iverilog -g2012 -o wave.vvp -f files.f && vvp wave.vvp

.PHONY: all clean sim