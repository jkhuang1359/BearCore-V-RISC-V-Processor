// tests/csr_minimal_test.c
#include <stdint.h>

// 簡單的 UART 輸出
void uart_putc(char c) {
    *(volatile uint32_t*)0x10000000 = c;
}

void uart_puts(const char *str) {
    while (*str) uart_putc(*str++);
}

// 使用數字地址的 CSR 操作函數
static inline uint32_t csr_read(uint32_t csr) {
    uint32_t value;
    asm volatile ("csrr %0, %1" : "=r"(value) : "r"(csr));
    return value;
}

static inline void csr_write(uint32_t csr, uint32_t value) {
    asm volatile ("csrw %0, %1" : : "r"(csr), "r"(value));
}

void main(void) {
    uart_puts("\nCSR Minimal Test\n");
    uart_puts("================\n");
    
    // 測試 1: 讀取 MISA (0x301)
    uint32_t misa = csr_read(0x301);
    uart_puts("MISA: ");
    
    // 簡單十六進位輸出
    for (int i = 28; i >= 0; i -= 4) {
        uint8_t nibble = (misa >> i) & 0xF;
        uart_putc(nibble < 10 ? '0' + nibble : 'A' + nibble - 10);
    }
    uart_puts("\n");
    
    // 測試 2: 寫入和讀回 MSCRATCH (0x340)
    csr_write(0x340, 0x12345678);
    uint32_t scratch = csr_read(0x340);
    uart_puts("MSCRATCH test: ");
    if (scratch == 0x12345678) {
        uart_puts("PASS ✓\n");
    } else {
        uart_puts("FAIL ✗\n");
        uart_puts("Expected: 0x12345678, Got: ");
        for (int i = 28; i >= 0; i -= 4) {
            uint8_t nibble = (scratch >> i) & 0xF;
            uart_putc(nibble < 10 ? '0' + nibble : 'A' + nibble - 10);
        }
        uart_puts("\n");
    }
    
    // 測試 3: CSRRS/CSRRC 指令
    uart_puts("CSRRS/CSRRC test: ");
    csr_write(0x340, 0x0);  // 清零
    
    // 使用 CSRRS 設置位元
    asm volatile ("csrrs x0, %0, %1" : : "r"(0x340), "r"(0x5));
    scratch = csr_read(0x340);
    if (scratch == 0x5) {
        uart_puts("CSRRS ✓ ");
    } else {
        uart_puts("CSRRS ✗ ");
    }
    
    // 使用 CSRRC 清除位元
    asm volatile ("csrrc x0, %0, %1" : : "r"(0x340), "r"(0x1));
    scratch = csr_read(0x340);
    if (scratch == 0x4) {
        uart_puts("CSRRC ✓\n");
    } else {
        uart_puts("CSRRC ✗\n");
    }
    
    uart_puts("\nCSR Minimal Test Complete!\n");
    
    // 成功指示
    for (int i = 0; i < 3; i++) {
        uart_putc(0x07);  // BEL 字符，終端可能會響鈴
    }
    
    while(1);
}