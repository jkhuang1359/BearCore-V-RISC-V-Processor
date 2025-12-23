#include <stdint.h>

#define UART_DATA    0x10000000
#define UART_STATUS  0x10000004

void uart_putc(char c) {
    // UART 數據寄存器地址：0x10000000
    volatile unsigned int *status = (volatile unsigned int *)UART_STATUS;
    volatile unsigned int *data   = (volatile unsigned int *)UART_DATA;
    while (*status & 1); 
    *data = c;
}

void uart_puts(const char *str) {
    while (*str) uart_putc(*str++);
}

void main(void) {
    uart_puts("\nCSR Simplest Test\n");
    
    // 測試 1: 直接讀取 MISA
    uint32_t misa;
    asm volatile ("csrr %0, 0x301" : "=r"(misa));
    
    uart_puts("MISA: 0x");
    for (int i = 28; i >= 0; i -= 4) {
        uint8_t nibble = (misa >> i) & 0xF;
        uart_putc(nibble < 10 ? '0' + nibble : 'A' + nibble - 10);
    }
    uart_puts("\n");
    
    // 測試 2: 寫入 MSCRATCH
    asm volatile ("csrw 0x340, %0" :: "r"(0xDEADBEEF));
    
    // 讀回
    uint32_t scratch;
    asm volatile ("csrr %0, 0x340" : "=r"(scratch));
    
    uart_puts("MSCRATCH: 0x");
    for (int i = 28; i >= 0; i -= 4) {
        uint8_t nibble = (scratch >> i) & 0xF;
        uart_putc(nibble < 10 ? '0' + nibble : 'A' + nibble - 10);
    }
    
    if (scratch == 0xDEADBEEF) {
        uart_puts(" ✓\n");
    } else {
        uart_puts(" ✗\n");
    }
    
    // 測試 3: CSRRS 設置位元
    asm volatile ("csrw 0x340, %0" :: "r"(0x0));  // 清零
    asm volatile ("csrs 0x340, %0" :: "r"(0x3));  // 設置位元 0 和 1
    asm volatile ("csrr %0, 0x340" : "=r"(scratch));
    uart_puts("CSRRS (set bits 0,1): ");
    if (scratch == 0x3) uart_puts("PASS ✓\n");
    else uart_puts("FAIL ✗\n");
    
    // 測試 4: CSRRC 清除位元
    asm volatile ("csrc 0x340, %0" :: "r"(0x1));  // 清除位元 0
    asm volatile ("csrr %0, 0x340" : "=r"(scratch));
    uart_puts("CSRRC (clear bit 0): ");
    if (scratch == 0x2) uart_puts("PASS ✓\n");
    else uart_puts("FAIL ✗\n");
    
    uart_puts("\n✅ CSR Test Complete!\n");
    
    while(1);
}
