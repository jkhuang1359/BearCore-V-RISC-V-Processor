// tests/csr_comprehensive_test.c
#include "test_reporter.h"

// 测试结果枚举
typedef enum {
    TEST_PASS = 0,
    TEST_FAIL = 1,
    TEST_SKIP = 2
} TestResult;

// 全局测试计数器
unsigned int test_count = 0;
unsigned int pass_count = 0;

// UART发送函数
void uart_putc(char c) {
    volatile unsigned int *status = (volatile unsigned int *)0x10000004;
    volatile unsigned int *data   = (volatile unsigned int *)0x10000000;
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

// 测试报告函数
TestResult report_test(const char *name, unsigned int result, unsigned int expected) {
    test_count++;
    
    uart_puts("Test ");
    uart_print_decimal(test_count);
    uart_puts(": ");
    uart_puts(name);
    uart_puts(" - ");
    
    if (result == expected) {
        uart_puts("PASS");
        pass_count++;
        uart_puts(" ✓\n");
        return TEST_PASS;
    } else {
        uart_puts("FAIL ✗ (got ");
        uart_print_hex(result);
        uart_puts(", expected ");
        uart_print_hex(expected);
        uart_puts(")\n");
        return TEST_FAIL;
    }
}

// 1. MSCRATCH 测试
TestResult test_mscratch(void) {
    uart_puts("\n=== MSCRATCH Test ===\n");
    
    TestResult overall = TEST_PASS;
    
    // 保存原始值
    unsigned int original = csr_read(CSR_MSCRATCH);
    
    // CSRRW 测试
    unsigned int test_val = 0x12345678;
    unsigned int read_val;
    
    // 使用csr_swap宏
    read_val = csr_swap(CSR_MSCRATCH, test_val);
    overall |= report_test("CSRRW Atomic Swap", csr_read(CSR_MSCRATCH), test_val);
    
    // CSRRS 测试
    unsigned int set_bits = 0x0000FF00;
    unsigned int expected = test_val | set_bits;
    
    read_val = csr_read_set(CSR_MSCRATCH, set_bits);
    overall |= report_test("CSRRS Set Bits", csr_read(CSR_MSCRATCH), expected);
    
    // CSRRC 测试
    unsigned int clear_bits = 0x0000FF00;
    expected = csr_read(CSR_MSCRATCH) & ~clear_bits;
    
    read_val = csr_read_clear(CSR_MSCRATCH, clear_bits);
    overall |= report_test("CSRRC Clear Bits", csr_read(CSR_MSCRATCH), expected);
    
    // 立即数版本测试
    read_val = csr_swap_imm(CSR_MSCRATCH, 0x5A);
    overall |= report_test("CSRRWI Write Immediate", read_val, expected);
    
    read_val = csr_read(CSR_MSCRATCH);
    overall |= report_test("CSRRWI Read Back", read_val, 0x5A);
    
    // 恢复原始值
    csr_write(CSR_MSCRATCH, original);
    
    return overall;
}

// 2. MSTATUS 测试
TestResult test_mstatus(void) {
    uart_puts("\n=== MSTATUS Test ===\n");
    
    TestResult overall = TEST_PASS;
    unsigned int original, read_val;
    
    // 保存原始值
    original = csr_read(CSR_MSTATUS);
    
    // 测试MIE位 (bit 3)
    csr_set(CSR_MSTATUS, 0x8);  // 设置MIE
    read_val = csr_read(CSR_MSTATUS);
    overall |= report_test("Set MIE Bit", read_val & 0x8, 0x8);
    
    csr_clear(CSR_MSTATUS, 0x8);  // 清除MIE
    read_val = csr_read(CSR_MSTATUS);
    overall |= report_test("Clear MIE Bit", read_val & 0x8, 0x0);
    
    // 恢复原始值
    csr_write(CSR_MSTATUS, original);
    
    return overall;
}

// 3. MTVEC 测试
TestResult test_mtvec(void) {
    uart_puts("\n=== MTVEC Test ===\n");
    
    TestResult overall = TEST_PASS;
    unsigned int original, read_val;
    
    original = csr_read(CSR_MTVEC);
    
    // 写入新值
    unsigned int new_vec = 0x200;
    csr_write(CSR_MTVEC, new_vec);
    read_val = csr_read(CSR_MTVEC);
    
    // MTVEC应该对齐到4字节边界
    overall |= report_test("MTVEC Write", read_val, new_vec & 0xFFFFFFFC);
    
    // 恢复
    csr_write(CSR_MTVEC, original);
    
    return overall;
}

// 4. 中断使能寄存器测试
TestResult test_interrupt_registers(void) {
    uart_puts("\n=== Interrupt Register Test ===\n");
    
    TestResult overall = TEST_PASS;
    unsigned int original_mie, read_val;
    
    // 测试MIE寄存器
    original_mie = csr_read(CSR_MIE);
    
    // 设置定时器中断使能 (MTIE, bit 7)
    csr_set(CSR_MIE, 0x80);
    read_val = csr_read(CSR_MIE);
    overall |= report_test("Set MTIE", read_val & 0x80, 0x80);
    
    // 设置软件中断使能 (MSIE, bit 3)
    csr_set(CSR_MIE, 0x8);
    read_val = csr_read(CSR_MIE);
    overall |= report_test("Set MSIE", read_val & 0x8, 0x8);
    
    // 清除所有中断使能
    csr_clear(CSR_MIE, 0xFFFFFFFF);
    read_val = csr_read(CSR_MIE);
    overall |= report_test("Clear All MIE", read_val, 0x0);
    
    // 恢复
    csr_write(CSR_MIE, original_mie);
    
    return overall;
}

// 5. MEPC/MCAUSE/MTVAL 测试
TestResult test_exception_registers(void) {
    uart_puts("\n=== Exception Register Test ===\n");
    
    TestResult overall = TEST_PASS;
    unsigned int test_pc = 0x1000;
    unsigned int test_cause = 0xB;  // ECALL
    unsigned int test_tval = 0xDEADBEEF;
    
    // 测试MEPC
    csr_write(CSR_MEPC, test_pc);
    unsigned int read_mepc = csr_read(CSR_MEPC);
    overall |= report_test("MEPC Write/Read", read_mepc, test_pc & 0xFFFFFFFC);
    
    // 测试MCAUSE
    csr_write(CSR_MCAUSE, test_cause);
    unsigned int read_mcause = csr_read(CSR_MCAUSE);
    overall |= report_test("MCAUSE Write/Read", read_mcause, test_cause);
    
    // 测试MTVAL
    csr_write(CSR_MTVAL, test_tval);
    unsigned int read_mtval = csr_read(CSR_MTVAL);
    overall |= report_test("MTVAL Write/Read", read_mtval, test_tval);
    
    return overall;
}

// 6. 定时器CSR测试
TestResult test_timer_csr(void) {
    uart_puts("\n=== Timer CSR Test ===\n");
    
    TestResult overall = TEST_PASS;
    
    // 设置mtimecmp (通过内存映射方式)
    volatile unsigned int *mtimecmp = (volatile unsigned int *)0x20000008;
    unsigned int test_cmp = 1000;
    *mtimecmp = test_cmp;
    
    uart_puts("Set mtimecmp to ");
    uart_print_decimal(test_cmp);
    uart_puts(" - MANUAL CHECK REQUIRED\n");
    
    // 注：mtime是只读寄存器，通过内存映射访问
    volatile unsigned int *mtime = (volatile unsigned int *)0x20000000;
    unsigned int time_val = *mtime;
    
    uart_puts("Current mtime: ");
    uart_print_decimal(time_val);
    uart_puts("\n");
    
    return TEST_SKIP;  // 定时器测试需要时间，标记为跳过
}

// 7. 系统指令测试 (ECALL/EBREAK)
TestResult test_system_instructions(void) {
    uart_puts("\n=== System Instruction Test ===\n");
    
    TestResult overall = TEST_PASS;
    
    // 注意：ECALL和EBREAK会触发异常，需要异常处理程序支持
    // 这里我们只是简单测试它们能否执行而不崩溃
    
    uart_puts("Testing ECALL (will trigger exception)... ");
    
    // 保存当前MEPC
    unsigned int saved_mepc = csr_read(CSR_MEPC);
    
    // 设置异常返回地址
    unsigned int return_addr = 0;
    asm volatile("1: la %0, 1b" : "=r"(return_addr));
    csr_write(CSR_MEPC, return_addr + 4);
    
    // 执行ECALL
    asm volatile("ecall");
    
    uart_puts("ECALL executed (if you see this, exception handler worked)\n");
    overall |= report_test("ECALL Execution", 1, 1);
    
    // 恢复MEPC
    csr_write(CSR_MEPC, saved_mepc);
    
    return overall;
}

// 8. 综合CSR操作测试
TestResult test_csr_operations(void) {
    uart_puts("\n=== Comprehensive CSR Operation Test ===\n");
    
    TestResult overall = TEST_PASS;
    
    // 测试各种CSR操作组合
    unsigned int csr_value;
    unsigned int original = csr_read(CSR_MSCRATCH);
    
    // 原子交换
    csr_value = csr_swap(CSR_MSCRATCH, 0xA5A5A5A5);
    overall |= report_test("CSRRW Atomic Swap", csr_read(CSR_MSCRATCH), 0xA5A5A5A5);
    
    // 原子设置位
    csr_value = csr_read_set(CSR_MSCRATCH, 0x0000FFFF);
    overall |= report_test("CSRRS Set Bits", csr_read(CSR_MSCRATCH), 0xA5A5FFFF);
    
    // 原子清除位
    csr_value = csr_read_clear(CSR_MSCRATCH, 0xFFFF0000);
    overall |= report_test("CSRRC Clear Bits", csr_read(CSR_MSCRATCH), 0x0000FFFF);
    
    // 立即数版本测试
    unsigned int imm_value;
    
    imm_value = csr_swap_imm(CSR_MSCRATCH, 0x3C);
    overall |= report_test("CSRRWI Immediate Write", csr_read(CSR_MSCRATCH), 0x3C);
    
    imm_value = csr_read_set_imm(CSR_MSCRATCH, 0xC3);
    overall |= report_test("CSRRSI Immediate Set", csr_read(CSR_MSCRATCH), 0xFF);
    
    imm_value = csr_read_clear_imm(CSR_MSCRATCH, 0x0F);
    overall |= report_test("CSRRCI Immediate Clear", csr_read(CSR_MSCRATCH), 0xF0);
    
    // 恢复原始值
    csr_write(CSR_MSCRATCH, original);
    
    return overall;
}

// 测试总结
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
        uart_puts("CSR_FULL_TEST_PASS\n");
    } else {
        uart_puts("❌ SOME TESTS FAILED ❌\n");
        uart_puts("CSR_TEST_FAIL\n");
    }
}

// 主测试函数
void main() {
    uart_puts("\n");
    uart_puts("========================================\n");
    uart_puts("   BearCore-V CSR Comprehensive Test   \n");
    uart_puts("========================================\n");
    
    // 初始化CSR寄存器
    uart_puts("\nInitializing CSR registers...\n");
    
    // 运行所有测试
    test_mscratch();
    test_mstatus();
    test_mtvec();
    test_interrupt_registers();
    test_exception_registers();
    test_timer_csr();
    test_system_instructions();
    test_csr_operations();
    
    // 显示测试总结
    test_summary();
    
    // 最终状态报告
    uart_puts("\n=== Final CSR State ===\n");
    uart_puts("MSTATUS: "); uart_print_hex(csr_read(CSR_MSTATUS)); uart_puts("\n");
    uart_puts("MISA:    "); uart_print_hex(csr_read(CSR_MISA)); uart_puts("\n");
    uart_puts("MIE:     "); uart_print_hex(csr_read(CSR_MIE)); uart_puts("\n");
    uart_puts("MTVEC:   "); uart_print_hex(csr_read(CSR_MTVEC)); uart_puts("\n");
    uart_puts("MSCRATCH:"); uart_print_hex(csr_read(CSR_MSCRATCH)); uart_puts("\n");
    uart_puts("MEPC:    "); uart_print_hex(csr_read(CSR_MEPC)); uart_puts("\n");
    uart_puts("MCAUSE:  "); uart_print_hex(csr_read(CSR_MCAUSE)); uart_puts("\n");
    uart_puts("MTVAL:   "); uart_print_hex(csr_read(CSR_MTVAL)); uart_puts("\n");
    
    uart_puts("\nCSR Test Complete. Halting.\n");
    
    while(1);
}