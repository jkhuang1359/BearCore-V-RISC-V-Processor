# 单元测试 Makefile
PROJ_ROOT := ../../..
TEST_DIR := $(PROJ_ROOT)/tests/unit_tests
SRC_DIR := $(PROJ_ROOT)/src
BUILD_DIR := $(PROJ_ROOT)/build/unit_tests

# 测试目标
TESTS := alu_test decoder_test regfile_test csr_test

# 工具
IVERILOG := iverilog
VVP := vvp
CC := gcc

all: $(addprefix run_, $(TESTS))

# ALU单元测试
alu_test: $(BUILD_DIR)/alu_test.vvp
	@echo "Running ALU test..."
	$(VVP) $<

$(BUILD_DIR)/alu_test.vvp: $(TEST_DIR)/alu_test.v $(SRC_DIR)/alu.v
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -o $@ -I$(SRC_DIR) $^

# 解码器单元测试
decoder_test: $(BUILD_DIR)/decoder_test.vvp
	@echo "Running Decoder test..."
	$(VVP) $<

$(BUILD_DIR)/decoder_test.vvp: $(TEST_DIR)/decoder_test.v $(SRC_DIR)/decoder.v
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -o $@ -I$(SRC_DIR) $^

# 寄存器文件单元测试
regfile_test: $(BUILD_DIR)/regfile_test.vvp
	@echo "Running Register File test..."
	$(VVP) $<

$(BUILD_DIR)/regfile_test.vvp: $(TEST_DIR)/regfile_test.v $(SRC_DIR)/reg_file.v
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -o $@ -I$(SRC_DIR) $^

# CSR寄存器单元测试
csr_test: $(BUILD_DIR)/csr_test.vvp
	@echo "Running CSR test..."
	$(VVP) $<

$(BUILD_DIR)/csr_test.vvp: $(TEST_DIR)/csr_test.v $(SRC_DIR)/csr_registers.v
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -o $@ -I$(SRC_DIR) $^

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean $(TESTS)