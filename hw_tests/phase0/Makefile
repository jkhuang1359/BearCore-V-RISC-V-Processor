# BearCore-V Stage 0 硬件测试 Makefile

CROSS_COMPILE = riscv64-unknown-elf-
CC = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump
CFLAGS = -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -O0 -g
LDFLAGS = -T link.ld

# 测试目标
TESTS = minimal_test test jump_test csr_test alu_comprehensive control_flow memory_test

.PHONY: all clean compile simulate check

all: compile simulate check

# 编译所有测试
compile: $(addsuffix .hex, $(TESTS))

# 编译单个测试
%.hex: %.s
$(CC) $(CFLAGS) $(LDFLAGS) -o $*.elf $<
$(OBJCOPY) -O binary $*.elf $*.bin
od -An -tx4 -w4 -v $*.bin > $*.hex
$(OBJDUMP) -d $*.elf > $*.disasm
@echo "✅ 编译: $*"

# 运行仿真
simulate: $(addsuffix .vcd, $(TESTS))

%.vcd: %.hex
@echo "🚀 仿真: $*"
cp $*.hex ../../firmware.hex
cd ../.. && iverilog -o wave.vvp -f files.f -I src
cd ../.. && vvp wave.vvp +testname=$* > logs/$*.log 2>&1
@echo "✅ 仿真完成: $*"

# 检查结果
check:
@echo "📊 检查测试结果..."
@for test in $(TESTS); do \
 "TEST_PASS\|PASS\|SUCCESS" ../../logs/$$test.log 2>/dev/null; then \
 "TEST_FAIL\|FAIL\|ERROR" ../../logs/$$test.log 2>/dev/null; then \
e

# 清理
clean:
rm -f *.elf *.bin *.hex *.disasm
rm -f ../../firmware.hex ../../wave.vvp
@echo "🧹 清理完成"

# 详细仿真
debug_%: %.hex
cp $*.hex ../../firmware.hex
cd ../.. && iverilog -o wave.vvp -f files.f -I src
cd ../.. && vvp wave.vvp +verbose=1 +testname=$*

