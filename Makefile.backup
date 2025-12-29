# BearCore-V RISC-V Processor Makefile
# ======================================

# 工具链配置
CROSS_COMPILE = riscv64-unknown-elf-
CC = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump
SIZE = $(CROSS_COMPILE)size

# 编译选项
CFLAGS = -march=rv32im -mabi=ilp32 -O0 -g -nostdlib -nostartfiles -ffreestanding
INCLUDES = -I./src/include
LDFLAGS = -T link.ld -Wl,--gc-sections

# 仿真工具
IVERILOG = iverilog
VVP = vvp
WAVEVIEWER = gtkwave

# 文件列表
SOURCE_FILES = src/core.v src/alu.v src/decoder.v src/reg_file.v \
               src/rom.v src/data_ram.v src/uart_tx.v src/csr_registers.v
TESTBENCH = src/tb_top.v

# 默认目标
all: firmware.hex

# ======================================
# 主程序编译
# ======================================

# 标准测试程序
firmware.elf: src/start.s src/main.c
	$(CC) $(CFLAGS) $(INCLUDES) $(LDFLAGS) $^ -o $@
	@echo "编译完成: firmware.elf"
	$(SIZE) $@

firmware.bin: firmware.elf
	$(OBJCOPY) -O binary $< $@
	@echo "生成二进制文件: firmware.bin"

firmware.hex: firmware.bin
	od -An -t x4 -w4 -v $< | tr -d ' ' > $@
	@echo "生成Hex文件: firmware.hex"

# ======================================
# CSR测试程序
# ======================================

# CSR简单测试
csr_simple_test: src/start_csr_test.s tests/csr_simple_test.c
	$(CC) $(CFLAGS) $(INCLUDES) $(LDFLAGS) $^ -o firmware.elf
	$(OBJCOPY) -O binary firmware.elf firmware.bin
	od -An -t x4 -w4 -v firmware.bin | tr -d ' ' > firmware.hex
	@echo "CSR测试程序生成完成"

# ======================================
# 仿真运行
# ======================================

# 标准仿真
sim: firmware.hex
	@echo "开始仿真..."
	$(IVERILOG) -g2012 -o wave.vvp -f files.f
	$(VVP) wave.vvp
	@echo "仿真完成"

# CSR测试仿真
test_csr_simple: csr_simple_test
	@echo "开始CSR测试仿真..."
	$(IVERILOG) -g2012 -o wave.vvp -f files.f
	$(VVP) wave.vvp
	@echo "CSR测试仿真完成"

# 生成波形
wave: firmware.hex
	@echo "开始仿真并生成波形..."
	$(IVERILOG) -g2012 -o wave.vvp -f files.f
	$(VVP) wave.vvp -fst
	@echo "波形文件已生成: cpu.vcd"
	@echo "使用命令: gtkwave cpu.vcd 查看波形"

# ======================================
# 分析和调试
# ======================================

# 反汇编
disasm: firmware.elf
	$(OBJDUMP) -d firmware.elf > firmware.disasm
	@echo "反汇编文件: firmware.disasm"

# 内存映射
memmap: firmware.elf
	$(OBJDUMP) -h firmware.elf > firmware.memmap
	@echo "内存映射文件: firmware.memmap"

# 符号表
symbols: firmware.elf
	$(OBJDUMP) -t firmware.elf > firmware.symbols
	@echo "符号表文件: firmware.symbols"

# ======================================
# 清理
# ======================================

clean:
	rm -f *.elf *.bin *.hex *.vvp *.vcd *.fst
	rm -f firmware.disasm firmware.memmap firmware.symbols
	rm -f *.log *.out
	@echo "清理完成"

distclean: clean
	rm -f *.backup *~ .*.swp
	@echo "深度清理完成"

# ======================================
# 辅助目标
# ======================================

# 显示帮助信息
help:
	@echo "BearCore-V Makefile 使用说明:"
	@echo ""
	@echo "编译目标:"
	@echo "  make all           - 编译主测试程序 (默认)"
	@echo "  make csr_simple_test - 编译CSR测试程序"
	@echo ""
	@echo "仿真目标:"
	@echo "  make sim           - 运行主测试仿真"
	@echo "  make test_csr_simple - 运行CSR测试仿真"
	@echo "  make wave          - 仿真并生成波形文件"
	@echo ""
	@echo "分析目标:"
	@echo "  make disasm        - 生成反汇编文件"
	@echo "  make memmap        - 生成内存映射文件"
	@echo "  make symbols       - 生成符号表文件"
	@echo ""
	@echo "清理目标:"
	@echo "  make clean         - 清理编译产物"
	@echo "  make distclean     - 深度清理"
	@echo ""
	@echo "其他目标:"
	@echo "  make help          - 显示此帮助信息"

# 伪目标声明
.PHONY: all sim test_csr_simple wave disasm memmap symbols clean distclean help