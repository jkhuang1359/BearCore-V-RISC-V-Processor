// tests/csr_simple_test.c
#include <stdint.h>

// UART地址
#define UART_DATA   0x10000000
#define UART_STATUS 0x10000004

// 测试计数
unsigned int test_count = 0;
unsigned int pass_count = 0;

// UART函数
void uart_putc(char c) {
    volatile unsigned int *status = (volatile unsigned int *)UART_STATUS;
    volatile unsigned int *data   = (volatile unsigned int *)UART_DATA;
    while (*status & 1); 
    *data = c;
}

void uart_puts(const char *str) {
    while (*str) {
        uart_putc(*str);
        str++;
    }
}

void uart_print_hex(unsigned int n) {
    uart_puts("0x");
    for (int i = 28; i >= 0; i -= 4) {
        unsigned int digit = (n >> i) & 0xF;
        if (digit < 10) uart_putc('0' + digit);
        else uart_putc('A' + digit - 10);
    }
}

void uart_print_decimal(unsigned int n) {
    if (n == 0) {
        uart_putc('0');
        return;
    }

    char buf[10];
    int i = 0;
    while (n > 0) {
        buf[i++] = (n % 10) + '0';
        n = n / 10;
    }
    while (--i >= 0) uart_putc(buf[i]);
}

// CSR读取函数 - 使用直接的asm
static inline unsigned int csr_read_mscratch(void) {
    unsigned int value;
    asm volatile ("csrr %0, mscratch" : "=r"(value));
    return value;
}

static inline unsigned int csr_read_mstatus(void) {
    unsigned int value;
    asm volatile ("csrr %0, mstatus" : "=r"(value));
    return value;
}

static inline unsigned int csr_read_misa(void) {
    unsigned int value;
    asm volatile ("csrr %0, misa" : "=r"(value));
    return value;
}

static inline unsigned int csr_read_mie(void) {
    unsigned int value;
    asm volatile ("csrr %0, mie" : "=r"(value));
    return value;
}

static inline unsigned int csr_read_mtvec(void) {
    unsigned int value;
    asm volatile ("csrr %0, mtvec" : "=r"(value));
    return value;
}

static inline unsigned int csr_read_mepc(void) {
    unsigned int value;
    asm volatile ("csrr %0, mepc" : "=r"(value));
    return value;
}

static inline unsigned int csr_read_mcause(void) {
    unsigned int value;
    asm volatile ("csrr %0, mcause" : "=r"(value));
    return value;
}

static inline unsigned int csr_read_mtval(void) {
    unsigned int value;
    asm volatile ("csrr %0, mtval" : "=r"(value));
    return value;
}

// CSR写入函数
static inline void csr_write_mscratch(unsigned int value) {
    asm volatile ("csrw mscratch, %0" :: "r"(value));
}

static inline void csr_write_mstatus(unsigned int value) {
    asm volatile ("csrw mstatus, %0" :: "r"(value));
}

static inline void csr_write_mie(unsigned int value) {
    asm volatile ("csrw mie, %0" :: "r"(value));
}

static inline void csr_write_mtvec(unsigned int value) {
    asm volatile ("csrw mtvec, %0" :: "r"(value));
}

static inline void csr_write_mepc(unsigned int value) {
    asm volatile ("csrw mepc, %0" :: "r"(value));
}

static inline void csr_write_mcause(unsigned int value) {
    asm volatile ("csrw mcause, %0" :: "r"(value));
}

static inline void csr_write_mtval(unsigned int value) {
    asm volatile ("csrw mtval, %0" :: "r"(value));
}

// CSR设置位函数
static inline void csr_set_mstatus(unsigned int value) {
    asm volatile ("csrs mstatus, %0" :: "r"(value));
}

static inline void csr_set_mie(unsigned int value) {
    asm volatile ("csrs mie, %0" :: "r"(value));
}

// CSR清除位函数
static inline void csr_clear_mstatus(unsigned int value) {
    asm volatile ("csrc mstatus, %0" :: "r"(value));
}

static inline void csr_clear_mie(unsigned int value) {
    asm volatile ("csrc mie, %0" :: "r"(value));
}

void report_test(const char *name, unsigned int result, unsigned int expected) {
    test_count++;
    
    uart_puts("Test ");
    uart_print_decimal(test_count);
    uart_puts(": ");
    uart_puts(name);
    uart_puts(" - ");
    
    if (result == expected) {
        uart_puts("PASS ✓ (");
        uart_print_hex(result);
        uart_puts(")\n");
        pass_count++;
    } else {
        uart_puts("FAIL ✗ (got ");
        uart_print_hex(result);
        uart_puts(", expected ");
        uart_print_hex(expected);
        uart_puts(")\n");
    }
}

// 1. MSCRATCH基础测试
void test_mscratch_basic(void) {
    uart_puts("\n=== MSCRATCH Basic Test ===\n");
    
    // 保存原始值
    unsigned int original = csr_read_mscratch();
    
    // 测试写入和读取
    unsigned int test_val = 0x12345678;
    csr_write_mscratch(test_val);
    unsigned int read_val = csr_read_mscratch();
    report_test("CSRW Write/Read", read_val, test_val);
    
    // 恢复原始值
    csr_write_mscratch(original);
}

// 2. MSTATUS MIE位测试
void test_mstatus_mie(void) {
    uart_puts("\n=== MSTATUS MIE Bit Test ===\n");
    
    // 保存原始值
    unsigned int original = csr_read_mstatus();
    
    // 设置MIE位 (bit 3)
    csr_set_mstatus(0x8);
    unsigned int read_val = csr_read_mstatus();
    report_test("Set MIE Bit", read_val & 0x8, 0x8);
    
    // 清除MIE位
    csr_clear_mstatus(0x8);
    read_val = csr_read_mstatus();
    report_test("Clear MIE Bit", read_val & 0x8, 0x0);
    
    // 恢复原始值
    csr_write_mstatus(original);
}

// 3. MTVEC对齐测试
void test_mtvec_alignment(void) {
    uart_puts("\n=== MTVEC Alignment Test ===\n");
    
    // 保存原始值
    unsigned int original = csr_read_mtvec();
    
    // 测试对齐地址
    unsigned int test_vec = 0x123;
    csr_write_mtvec(test_vec);
    unsigned int read_val = csr_read_mtvec();
    report_test("MTVEC Write (auto-align)", read_val, test_vec & 0xFFFFFFFC);
    
    // 恢复原始值
    csr_write_mtvec(original);
}

// 4. MIE寄存器测试
void test_mie_register(void) {
    uart_puts("\n=== MIE Register Test ===\n");
    
    // 保存原始值
    unsigned int original = csr_read_mie();
    
    // 测试设置位
    csr_set_mie(0x88);  // MTIE (bit 7) + MSIE (bit 3)
    unsigned int read_val = csr_read_mie();
    report_test("Set MIE bits", read_val & 0x88, 0x88);
    
    // 测试清除位
    csr_clear_mie(0xFFFFFFFF);
    read_val = csr_read_mie();
    report_test("Clear all MIE bits", read_val, 0x0);
    
    // 恢复原始值
    csr_write_mie(original);
}

// 5. 异常寄存器测试
void test_exception_registers(void) {
    uart_puts("\n=== Exception Register Test ===\n");
    
    // 测试MEPC
    unsigned int test_pc = 0x1000;
    csr_write_mepc(test_pc);
    unsigned int read_mepc = csr_read_mepc();
    report_test("MEPC Write/Read", read_mepc, test_pc & 0xFFFFFFFC);
    
    // 测试MCAUSE
    unsigned int test_cause = 0xB;  // ECALL
    csr_write_mcause(test_cause);
    unsigned int read_mcause = csr_read_mcause();
    report_test("MCAUSE Write/Read", read_mcause, test_cause);
    
    // 测试MTVAL
    unsigned int test_tval = 0xDEADBEEF;
    csr_write_mtval(test_tval);
    unsigned int read_mtval = csr_read_mtval();
    report_test("MTVAL Write/Read", read_mtval, test_tval);
}

// 6. CSR原子操作测试
void test_csr_atomic_ops(void) {
    uart_puts("\n=== CSR Atomic Operation Test ===\n");
    
    // 保存原始值
    unsigned int original = csr_read_mscratch();
    
    // CSRRW测试 (原子交换)
    unsigned int swap_result;
    asm volatile ("csrrw %0, mscratch, %1" : "=r"(swap_result) : "r"(0xA5A5A5A5));
    unsigned int current_val = csr_read_mscratch();
    report_test("CSRRW Atomic Swap", current_val, 0xA5A5A5A5);
    
    // CSRRS测试 (原子设置位)
    unsigned int set_result;
    asm volatile ("csrrs %0, mscratch, %1" : "=r"(set_result) : "r"(0x0000FFFF));
    current_val = csr_read_mscratch();
    report_test("CSRRS Set Bits", current_val, 0xA5A5FFFF);
    
    // CSRRC测试 (原子清除位)
    unsigned int clear_result;
    asm volatile ("csrrc %0, mscratch, %1" : "=r"(clear_result) : "r"(0xFFFF0000));
    current_val = csr_read_mscratch();
    report_test("CSRRC Clear Bits", current_val, 0x0000FFFF);
    
    // 恢复原始值
    csr_write_mscratch(original);
}

// 7. 系统指令测试
void test_system_instructions(void) {
    uart_puts("\n=== System Instruction Test ===\n");
    
    // 保存当前MEPC
    unsigned int saved_mepc = csr_read_mepc();
    
    // 设置异常返回地址
    unsigned int return_addr;
    asm volatile("1: la %0, 1b" : "=r"(return_addr));
    csr_write_mepc(return_addr + 4);
    
    uart_puts("Testing ECALL... ");
    // 执行ECALL - 这会触发异常，异常处理程序会跳过它
    asm volatile("ecall");
    uart_puts("ECALL executed ✓\n");
    test_count++; pass_count++;
    
    uart_puts("Testing EBREAK... ");
    // 设置异常返回地址
    asm volatile("2: la %0, 2b" : "=r"(return_addr));
    csr_write_mepc(return_addr + 4);
    // 执行EBREAK
    asm volatile("ebreak");
    uart_puts("EBREAK executed ✓\n");
    test_count++; pass_count++;
    
    // 恢复寄存器
    csr_write_mepc(saved_mepc);
}

// 8. CSR立即数指令测试 - 修正：使用5位立即数（0-31）
void test_csr_immediate(void) {
    uart_puts("\n=== CSR Immediate Instruction Test ===\n");
    
    // 保存原始值
    unsigned int original = csr_read_mscratch();
    
    // 首先设置一个已知值
    csr_write_mscratch(0x0);
    
    // CSRRWI测试 (原子交换立即数) - 立即数必须在0-31范围内
    unsigned int swap_imm_result;
    asm volatile ("csrrwi %0, mscratch, 5" : "=r"(swap_imm_result));  // 使用5（二进制101）
    unsigned int current_val = csr_read_mscratch();
    report_test("CSRRWI Write Immediate 5", current_val, 0x5);
    
    // CSRRSI测试 (原子设置位立即数)
    unsigned int set_imm_result;
    asm volatile ("csrrsi %0, mscratch, 3" : "=r"(set_imm_result));  // 设置位0和位1
    current_val = csr_read_mscratch();
    report_test("CSRRSI Set Immediate 3", current_val, 0x7);  // 5 | 3 = 7 (111)
    
    // CSRRCI测试 (原子清除位立即数)
    unsigned int clear_imm_result;
    asm volatile ("csrrci %0, mscratch, 2" : "=r"(clear_imm_result));  // 清除位1
    current_val = csr_read_mscratch();
    report_test("CSRRCI Clear Immediate 2", current_val, 0x5);  // 7 & ~2 = 5 (101)
    
    // 恢复原始值
    csr_write_mscratch(original);
}

// 9. CSR混合测试 - 测试所有类型的CSR操作
void test_csr_mixed_operations(void) {
    uart_puts("\n=== CSR Mixed Operations Test ===\n");
    
    unsigned int original = csr_read_mscratch();
    unsigned int temp;
    
    // 测试序列: CSRRW -> CSRRS -> CSRRC -> CSRRWI -> CSRRSI -> CSRRCI
    csr_write_mscratch(0x0);
    
    // CSRRW: 写入新值
    asm volatile ("csrrw %0, mscratch, %1" : "=r"(temp) : "r"(0x0000AAAA));
    report_test("CSRRW write 0xAAAA", csr_read_mscratch(), 0x0000AAAA);
    
    // CSRRS: 设置某些位
    asm volatile ("csrrs %0, mscratch, %1" : "=r"(temp) : "r"(0x00005555));
    report_test("CSRRS set bits 0x5555", csr_read_mscratch(), 0x0000FFFF);
    
    // CSRRC: 清除某些位
    asm volatile ("csrrc %0, mscratch, %1" : "=r"(temp) : "r"(0x0000F0F0));
    report_test("CSRRC clear bits 0xF0F0", csr_read_mscratch(), 0x00000F0F);
    
    // CSRRWI: 立即数写入
    asm volatile ("csrrwi %0, mscratch, 10" : "=r"(temp));  // 10 = 0b1010
    report_test("CSRRWI write imm 10", csr_read_mscratch(), 0xA);
    
    // CSRRSI: 立即数设置位
    asm volatile ("csrrsi %0, mscratch, 5" : "=r"(temp));  // 5 = 0b0101
    report_test("CSRRSI set imm 5", csr_read_mscratch(), 0xF);  // 0xA | 0x5 = 0xF
    
    // CSRRCI: 立即数清除位
    asm volatile ("csrrci %0, mscratch, 9" : "=r"(temp));  // 9 = 0b1001
    report_test("CSRRCI clear imm 9", csr_read_mscratch(), 0x6);  // 0xF & ~0x9 = 0x6
    
    // 恢复原始值
    csr_write_mscratch(original);
}

void test_summary(void) {
    uart_puts("\n=== CSR Test Summary ===\n");
    uart_puts("Total Tests: ");
    uart_print_decimal(test_count);
    uart_puts("\nPassed Tests: ");
    uart_print_decimal(pass_count);
    uart_puts("\nFailed Tests: ");
    uart_print_decimal(test_count - pass_count);
    uart_puts("\n\n");
    
    if (pass_count == test_count) {
        uart_puts("🎉 ALL CSR TESTS PASSED! 🎉\n");
        uart_puts("CSR_TEST_PASS\n");
    } else {
        uart_puts("❌ SOME TESTS FAILED ❌\n");
        uart_puts("CSR_TEST_FAIL\n");
    }
}

// 最终CSR状态显示
void show_final_csr_state(void) {
    uart_puts("\n=== Final CSR State ===\n");
    uart_puts("MSTATUS: "); uart_print_hex(csr_read_mstatus()); uart_puts("\n");
    uart_puts("MISA:    "); uart_print_hex(csr_read_misa()); uart_puts("\n");
    uart_puts("MIE:     "); uart_print_hex(csr_read_mie()); uart_puts("\n");
    uart_puts("MTVEC:   "); uart_print_hex(csr_read_mtvec()); uart_puts("\n");
    uart_puts("MSCRATCH:"); uart_print_hex(csr_read_mscratch()); uart_puts("\n");
    uart_puts("MEPC:    "); uart_print_hex(csr_read_mepc()); uart_puts("\n");
    uart_puts("MCAUSE:  "); uart_print_hex(csr_read_mcause()); uart_puts("\n");
    uart_puts("MTVAL:   "); uart_print_hex(csr_read_mtval()); uart_puts("\n");
}

// 主测试函数
void main() {
    uart_puts("\n");
    uart_puts("=================================\n");
    uart_puts("   BearCore-V CSR Simple Test   \n");
    uart_puts("=================================\n");
    
    // 初始化UART（发送回车换行）
    uart_puts("\nStarting CSR tests...\n\n");
    
    // 运行所有测试
    test_mscratch_basic();
    test_mstatus_mie();
    test_mtvec_alignment();
    test_mie_register();
    test_exception_registers();
    test_csr_atomic_ops();
    test_csr_immediate();
    test_csr_mixed_operations();
    test_system_instructions();
    
    // 显示测试总结
    test_summary();
    
    // 显示最终状态
    show_final_csr_state();
    
    uart_puts("\nCSR Test Complete. Halting.\n");
    
    // 死循环
    while(1) {
        asm volatile("nop");
    }
}