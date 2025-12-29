# RISC-V Compliance Tests

This directory contains RISC-V architecture compliance tests.

## Test Categories

1. **RV32I Base Instruction Set**
   - I-ADD-01: ADD instruction
   - I-ADDI-01: ADDI instruction
   - I-AND-01: AND instruction
   - I-AUIPC-01: AUIPC instruction
   - I-BEQ-01: BEQ instruction
   - etc.

2. **Zicsr Extension**
   - CSR access instructions
   - CSR read/write operations
   - Privilege mode tests

3. **Machine Mode Tests**
   - Exception handling
   - Interrupt handling
   - Trap vector tests

## Running Tests

### Prerequisites
```bash
# Install RISC-V compliance test suite
git clone https://github.com/riscv/riscv-compliance
cd riscv-compliance
make RISCV_TARGET=your_target RISCV_DEVICE=rv32i
Running Tests
bash
cd ~/projects/my_riscv_core
./tests/riscv_compliance/run_compliance.sh
Test Structure
Each test consists of:

Test program (.S assembly)

Reference signature file

Test harness

Expected results

Adding New Tests
Write test program in assembly

Generate reference signature

Add to test list in run_compliance.sh

Verify with simulator
